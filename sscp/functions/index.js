const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const { logger } = require('firebase-functions');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const MAX_MULTICAST_TOKENS = 500;

const ROLE_COLLECTIONS = {
  student: 'students',
  faculty: 'faculty',
  admin: 'admin',
  fee_payment: 'feePayments',
};

function normalizeRole(role) {
  const value = String(role || '').trim().toLowerCase();
  if (value === 'feepayment' || value === 'fee payment') return 'fee_payment';
  return value;
}

function normalizeId(value) {
  return String(value || '').trim().toUpperCase();
}

function normalizeSemester(value) {
  const raw = String(value || '').trim().toUpperCase();
  if (!raw) return '';
  if (raw === 'I' || raw === '1' || raw === 'SEM I' || raw === 'SEMESTER I') return '1';
  if (raw === 'II' || raw === '2' || raw === 'SEM II' || raw === 'SEMESTER II') return '2';
  const parsed = parseInt(raw, 10);
  if (!Number.isNaN(parsed) && parsed > 0) {
    return parsed % 2 === 1 ? '1' : '2';
  }
  return raw;
}

function normalizeBranchToken(value) {
  return String(value || '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
}

function parseYearValue(value) {
  const raw = String(value || '').trim().toUpperCase();
  if (!raw) return '';
  const romanMap = { I: '1', II: '2', III: '3', IV: '4' };
  if (romanMap[raw]) return romanMap[raw];
  const numberMatch = raw.match(/[1-9]/);
  if (numberMatch) return numberMatch[0];
  return '';
}

function branchMatches(studentBranch, expectedBranch) {
  const expected = normalizeBranchToken(expectedBranch);
  if (!expected || expected === 'ALL') return true;
  const actual = normalizeBranchToken(studentBranch);
  if (!actual) return false;
  return actual === expected || actual.includes(expected) || expected.includes(actual);
}

function toTokens(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((item) => typeof item === 'string' && item.trim().length > 0))];
}

function chunkArray(arr, chunkSize) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += chunkSize) {
    chunks.push(arr.slice(i, i + chunkSize));
  }
  return chunks;
}

function isInvalidTokenError(code) {
  const value = String(code || '');
  return (
    value.includes('registration-token-not-registered') ||
    value.includes('invalid-registration-token') ||
    value.includes('invalid-argument')
  );
}

function hasAnyValueChanged(before, after, keys) {
  return keys.some((key) => JSON.stringify(before?.[key] ?? null) !== JSON.stringify(after?.[key] ?? null));
}

function getStudentIdFromData(data, fallbackDocId) {
  const fromFields =
    data?.hallTicketNumber || data?.hallticketNumber || data?.rollNumber || data?.rollNo || data?.studentId;
  return normalizeId(fromFields || fallbackDocId);
}

function matchesStudentScope(studentData, scope = {}) {
  const scopeYear = parseYearValue(scope.year);
  const scopeSemester = normalizeSemester(scope.semester);
  const scopeBranch = normalizeId(scope.branch);

  if (scopeYear) {
    const studentYear = parseYearValue(studentData?.year);
    if (!studentYear || studentYear !== scopeYear) return false;
  }

  if (scopeSemester) {
    const studentSemester = normalizeSemester(studentData?.semester);
    if (!studentSemester || studentSemester !== scopeSemester) return false;
  }

  if (scopeBranch && scopeBranch !== 'ALL') {
    const studentBranch =
      studentData?.branch || studentData?.department || studentData?.dept || studentData?.course || '';
    if (!branchMatches(studentBranch, scopeBranch)) return false;
  }

  return true;
}

function buildTarget(role, recipientId, docRef, data = {}) {
  return {
    role,
    recipientId: normalizeId(recipientId),
    docRef: docRef || null,
    tokens: toTokens(data.fcmTokens),
  };
}

async function getRoleTargets(role, recipientId = '') {
  const normalizedRole = normalizeRole(role);
  const collection = ROLE_COLLECTIONS[normalizedRole];
  if (!collection) return [];

  if (normalizedRole === 'admin' && !recipientId) {
    const snap = await db.collection(collection).get();
    return snap.docs
      .map((doc) => buildTarget('admin', doc.id, doc.ref, doc.data() || {}))
      .filter((target) => target.recipientId);
  }

  const normalizedRecipientId = normalizeId(recipientId);
  if (!normalizedRecipientId) return [];

  const ref = db.collection(collection).doc(normalizedRecipientId);
  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  return [buildTarget(normalizedRole, normalizedRecipientId, snap.exists ? ref : null, data)];
}

async function getStudentTargetsByScope(scope = {}) {
  const snap = await db.collection('students').get();
  const targets = [];

  snap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const studentId = getStudentIdFromData(data, doc.id);
    if (!studentId) return;
    if (!matchesStudentScope(data, scope)) return;
    targets.push(buildTarget('student', studentId, doc.ref, data));
  });

  return targets;
}

async function writeNotificationDoc({
  recipientRole,
  recipientId,
  type,
  title,
  body,
  relatedDocId = '',
  metadata = {},
}) {
  const ref = db.collection('notifications').doc();
  await ref.set({
    recipientRole,
    recipientId,
    type,
    title,
    body,
    isRead: false,
    relatedDocId,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

async function sendPushToTarget({
  target,
  title,
  body,
  type,
  notificationId,
}) {
  const tokens = toTokens(target.tokens);
  if (tokens.length === 0) return;

  const tokenChunks = chunkArray(tokens, MAX_MULTICAST_TOKENS);
  const invalidTokens = [];

  for (const tokenChunk of tokenChunks) {
    const message = {
      tokens: tokenChunk,
      notification: { title, body },
      data: {
        type,
        notificationId,
        recipientRole: target.role,
        recipientId: target.recipientId,
      },
      android: { priority: 'high' },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { sound: 'default' } },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    response.responses.forEach((res, index) => {
      if (res.success) return;
      const code = res.error?.code || '';
      if (isInvalidTokenError(code)) {
        invalidTokens.push(tokenChunk[index]);
      }
      logger.warn('Push token send failure', {
        role: target.role,
        recipientId: target.recipientId,
        errorCode: code,
      });
    });
  }

  if (invalidTokens.length > 0 && target.docRef) {
    await target.docRef.set(
      {
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
        fcmTokenUpdatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}

async function dispatchNotifications({
  targets,
  type,
  title,
  body,
  relatedDocId = '',
  metadata = {},
}) {
  for (const target of targets) {
    if (!target.recipientId) continue;

    const notificationId = await writeNotificationDoc({
      recipientRole: target.role,
      recipientId: target.recipientId,
      type,
      title,
      body,
      relatedDocId,
      metadata,
    });

    await sendPushToTarget({
      target,
      title,
      body,
      type,
      notificationId,
    });
  }
}

async function resolveFacultyName(afterData) {
  let facultyName = String(afterData?.facultyName || '').trim();
  const facultyId = normalizeId(afterData?.facultyId);

  if (!facultyName && facultyId) {
    const facultySnap = await db.collection('faculty').doc(facultyId).get();
    if (facultySnap.exists) {
      const facultyData = facultySnap.data() || {};
      facultyName = String(facultyData.name || facultyData.facultyName || facultyId).trim();
    }
  }

  if (!facultyName) facultyName = 'Faculty';
  return facultyName;
}

exports.notifyStudentOnMarksUpload = functions
  .region('us-central1')
  .firestore.document('studentMarks/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const marksChanged =
      !before ||
      Number(before.totalMarks ?? -1) !== Number(after.totalMarks ?? -1) ||
      JSON.stringify(before.componentMarks ?? {}) !== JSON.stringify(after.componentMarks ?? {});

    if (!marksChanged) return;

    const studentId = normalizeId(after.studentId);
    if (!studentId) {
      logger.warn('Skipping marks notification: studentId missing', {
        docId: context.params.docId,
      });
      return;
    }

    const facultyName = await resolveFacultyName(after);
    const subjectCode = String(after.subjectCode || '').trim();
    const subjectName = String(after.subjectName || 'Subject').trim();
    const totalMarks = Number(after.totalMarks ?? 0);
    const maxMarks = Number(after.maxMarks ?? 0);

    const title = 'Marks Uploaded';
    const body = `${subjectCode ? `${subjectCode} - ` : ''}${subjectName}: ${totalMarks}/${maxMarks} by ${facultyName}`;

    const targets = await getRoleTargets('student', studentId);
    await dispatchNotifications({
      targets,
      type: 'marks_uploaded',
      title,
      body,
      relatedDocId: context.params.docId,
      metadata: {
        subjectCode,
        subjectName,
        totalMarks,
        maxMarks,
        facultyId: normalizeId(after.facultyId),
      },
    });
  });

exports.notifyStudentsOnAttendanceUpload = functions
  .region('us-central1')
  .firestore.document('attendance/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const students = Array.isArray(data.students) ? data.students : [];
    const studentIds = [...new Set(
      students
        .map((s) => normalizeId(s?.rollNo || s?.hallTicketNumber || s?.studentId))
        .filter(Boolean)
    )];

    if (studentIds.length === 0) return;

    const targets = [];
    for (const studentId of studentIds) {
      const recipientTargets = await getRoleTargets('student', studentId);
      targets.push(...recipientTargets);
    }

    const subjectCode = String(data.subjectCode || '').trim();
    const subjectName = String(data.subjectName || 'Subject').trim();
    const dateStr = String(data.dateStr || '').trim();
    const title = 'Attendance Updated';
    const body = `${subjectCode ? `${subjectCode} - ` : ''}${subjectName} attendance uploaded${dateStr ? ` for ${dateStr}` : ''}.`;

    await dispatchNotifications({
      targets,
      type: 'attendance_uploaded',
      title,
      body,
      relatedDocId: context.params.docId,
      metadata: {
        subjectCode,
        subjectName,
        dateStr,
      },
    });
  });

exports.notifyAdminsOnEditAccessRequest = functions
  .region('us-central1')
  .firestore.document('editAccessRequests/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const rollNo = normalizeId(data.hallTicketNumber);
    const studentName = String(data.studentName || rollNo || 'Student').trim();

    const targets = await getRoleTargets('admin');
    if (targets.length === 0) return;

    await dispatchNotifications({
      targets,
      type: 'edit_access_request_submitted',
      title: 'Student Edit Access Request',
      body: `${studentName} (${rollNo || 'N/A'}) requested profile edit access.`,
      relatedDocId: context.params.docId,
      metadata: {
        hallTicketNumber: rollNo,
        studentName,
      },
    });
  });

exports.notifyAdminsOnGrievanceSubmitted = functions
  .region('us-central1')
  .firestore.document('grievances/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const rollNo = normalizeId(data.rollNumber);
    const studentName = String(data.studentName || rollNo || 'Student').trim();
    const grievanceType = String(data.grievanceType || 'General').trim();

    const targets = await getRoleTargets('admin');
    if (targets.length === 0) return;

    await dispatchNotifications({
      targets,
      type: 'grievance_submitted',
      title: 'New Student Grievance',
      body: `${studentName} (${rollNo || 'N/A'}) submitted a ${grievanceType} grievance.`,
      relatedDocId: context.params.docId,
      metadata: {
        rollNumber: rollNo,
        grievanceType,
      },
    });
  });

exports.notifyAdminsOnAttendanceEditRequest = functions
  .region('us-central1')
  .firestore.document('attendanceEditRequests/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const facultyId = normalizeId(data.facultyId);
    const subjectCode = String(data.subjectCode || '').trim();

    const targets = await getRoleTargets('admin');
    if (targets.length === 0) return;

    await dispatchNotifications({
      targets,
      type: 'attendance_edit_request_submitted',
      title: 'Attendance Edit Request',
      body: `Faculty ${facultyId || 'N/A'} requested attendance edit access${subjectCode ? ` for ${subjectCode}` : ''}.`,
      relatedDocId: context.params.docId,
      metadata: {
        facultyId,
        subjectCode,
      },
    });
  });

exports.notifyStudentOnGrievanceReply = functions
  .region('us-central1')
  .firestore.document('grievances/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!before || !after) return;

    const statusChanged = String(before.status || '') !== String(after.status || '');
    const responseChanged = String(before.adminResponse || '') !== String(after.adminResponse || '');
    if (!statusChanged && !responseChanged) return;

    const rollNo = normalizeId(after.rollNumber);
    if (!rollNo) return;

    const status = String(after.status || 'Updated').trim();
    const response = String(after.adminResponse || '').trim();
    const body = response
      ? `Status: ${status}. Admin response: ${response}`
      : `Your grievance status is now ${status}.`;

    const targets = await getRoleTargets('student', rollNo);
    await dispatchNotifications({
      targets,
      type: 'grievance_response',
      title: 'Grievance Update',
      body,
      relatedDocId: context.params.docId,
      metadata: {
        status,
      },
    });
  });

exports.notifyFacultyOnCourseAssignment = functions
  .region('us-central1')
  .firestore.document('facultyAssignments/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    // Assignment deleted
    if (before && !after) {
      const prevFacultyId = normalizeId(before.facultyId);
      if (!prevFacultyId) return;
      const targets = await getRoleTargets('faculty', prevFacultyId);
      await dispatchNotifications({
        targets,
        type: 'faculty_assignment_removed',
        title: 'Course Assignment Removed',
        body: `Your assignment for ${before.subjectCode || 'a subject'} was removed.`,
        relatedDocId: context.params.docId,
      });
      return;
    }

    if (!after) return;

    const changed = !before || hasAnyValueChanged(before, after, [
      'facultyId',
      'subjectCode',
      'subjectName',
      'year',
      'semester',
      'assignedBatches',
      'isActive',
      'academicYear',
    ]);
    if (!changed) return;

    const currentFacultyId = normalizeId(after.facultyId);
    if (!currentFacultyId) return;

    if (before && normalizeId(before.facultyId) && normalizeId(before.facultyId) !== currentFacultyId) {
      const oldTargets = await getRoleTargets('faculty', normalizeId(before.facultyId));
      await dispatchNotifications({
        targets: oldTargets,
        type: 'faculty_assignment_reassigned',
        title: 'Course Assignment Reassigned',
        body: `Your assignment for ${before.subjectCode || 'a subject'} was reassigned.`,
        relatedDocId: context.params.docId,
      });
    }

    const title = 'Course Assignment Updated';
    const subjectCode = String(after.subjectCode || '').trim();
    const subjectName = String(after.subjectName || '').trim();
    const year = String(after.year || '').trim();
    const semester = String(after.semester || '').trim();
    const isActive = after.isActive !== false;
    const body = isActive
      ? `Assigned ${subjectCode ? `${subjectCode} - ` : ''}${subjectName || 'subject'} for Year ${year || 'N/A'}, Sem ${semester || 'N/A'}.`
      : `${subjectCode || 'Course'} assignment is now inactive.`;

    const targets = await getRoleTargets('faculty', currentFacultyId);
    await dispatchNotifications({
      targets,
      type: 'faculty_assignment_updated',
      title,
      body,
      relatedDocId: context.params.docId,
      metadata: {
        subjectCode,
        year,
        semester,
      },
    });
  });

exports.notifyFacultyOnMentorAssignment = functions
  .region('us-central1')
  .firestore.document('mentorAssignments/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    if (before && !after) {
      const prevFacultyId = normalizeId(before.facultyId);
      if (!prevFacultyId) return;
      const oldTargets = await getRoleTargets('faculty', prevFacultyId);
      await dispatchNotifications({
        targets: oldTargets,
        type: 'mentor_assignment_removed',
        title: 'Mentor Assignment Removed',
        body: `Mentor assignment for Year ${before.year || 'N/A'} Batch ${before.batchNumber || 'N/A'} was removed.`,
        relatedDocId: context.params.docId,
      });
      return;
    }

    if (!after) return;

    const changed = !before || hasAnyValueChanged(before, after, [
      'facultyId',
      'year',
      'department',
      'batchNumber',
    ]);
    if (!changed) return;

    const facultyId = normalizeId(after.facultyId);
    if (!facultyId) return;

    if (before && normalizeId(before.facultyId) && normalizeId(before.facultyId) !== facultyId) {
      const previousTargets = await getRoleTargets('faculty', normalizeId(before.facultyId));
      await dispatchNotifications({
        targets: previousTargets,
        type: 'mentor_assignment_reassigned',
        title: 'Mentor Assignment Reassigned',
        body: `Your mentorship assignment for Year ${before.year || 'N/A'} Batch ${before.batchNumber || 'N/A'} was reassigned.`,
        relatedDocId: context.params.docId,
      });
    }

    const targets = await getRoleTargets('faculty', facultyId);
    await dispatchNotifications({
      targets,
      type: 'mentor_assignment_updated',
      title: 'Mentor Assignment Updated',
      body: `Assigned as mentor for Year ${after.year || 'N/A'} ${after.department || ''} Batch ${after.batchNumber || 'N/A'}.`,
      relatedDocId: context.params.docId,
      metadata: {
        year: String(after.year || ''),
        department: String(after.department || ''),
        batchNumber: String(after.batchNumber || ''),
      },
    });
  });

exports.notifyStudentsOnCieMemoRelease = functions
  .region('us-central1')
  .firestore.document('cieMemoReleases/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const becameActive = after.isActive === true && (!before || before.isActive !== true);
    if (!becameActive) return;

    const targets = await getStudentTargetsByScope({
      year: after.year,
      semester: after.semester,
      branch: after.branch,
    });

    if (targets.length === 0) return;

    const title = 'CIE Memo Released';
    const body = `CIE memo is now available for Year ${after.year || 'N/A'}, Sem ${after.semester || 'N/A'}${after.branch ? ` (${after.branch})` : ''}.`;

    await dispatchNotifications({
      targets,
      type: 'cie_memo_released',
      title,
      body,
      relatedDocId: context.params.docId,
      metadata: {
        year: String(after.year || ''),
        semester: String(after.semester || ''),
        branch: String(after.branch || ''),
      },
    });
  });

exports.notifyStudentsOnHallticketRelease = functions
  .region('us-central1')
  .firestore.document('hallticketReleases/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const targets = await getStudentTargetsByScope({
      year: data.year,
      semester: data.semester,
      branch: data.branch,
    });

    if (targets.length === 0) return;

    const examType = String(data.examType || '').trim();
    const title = 'Hall Ticket Released';
    const body = `Hall ticket has been released${examType ? ` for ${examType}` : ''}.`;

    await dispatchNotifications({
      targets,
      type: 'hallticket_released',
      title,
      body,
      relatedDocId: context.params.docId,
      metadata: {
        examType,
        year: String(data.year || ''),
        semester: String(data.semester || ''),
        branch: String(data.branch || ''),
      },
    });
  });

async function notifyStudentsOnWindowActivation({
  before,
  after,
  context,
  type,
  title,
  bodyBuilder,
}) {
  if (!after) return;
  const becameActive = after.isActive === true && (!before || before.isActive !== true);
  if (!becameActive) return;

  const targets = await getStudentTargetsByScope();
  if (targets.length === 0) return;

  const body = bodyBuilder(after);
  await dispatchNotifications({
    targets,
    type,
    title,
    body,
    relatedDocId: context.params.docId,
  });
}

exports.notifyStudentsOnRegularFeeWindow = functions
  .region('us-central1')
  .firestore.document('regularExamWindows/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    await notifyStudentsOnWindowActivation({
      before,
      after,
      context,
      type: 'regular_fee_window_open',
      title: 'Regular Exam Fee Window Open',
      bodyBuilder: (window) => `${window.title || 'Regular exam fee window'} is now open.`,
    });
  });

exports.notifyStudentsOnSupplyWindow = functions
  .region('us-central1')
  .firestore.document('supplyWindows/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    await notifyStudentsOnWindowActivation({
      before,
      after,
      context,
      type: 'supply_window_open',
      title: 'Supply Exam Window Open',
      bodyBuilder: (window) => `${window.title || 'Supply exam window'} is now open.`,
    });
  });

exports.notifyStudentsOnMakeupMidWindow = functions
  .region('us-central1')
  .firestore.document('makeupMidWindows/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    await notifyStudentsOnWindowActivation({
      before,
      after,
      context,
      type: 'makeup_mid_window_open',
      title: 'Makeup Mid Window Open',
      bodyBuilder: (window) => `${window.title || 'Makeup mid window'} is now open.`,
    });
  });

exports.notifyStudentsOnFeedbackSession = functions
  .region('us-central1')
  .firestore.document('feedbackSessions/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const becameActive = after.isActive === true && (!before || before.isActive !== true);
    if (!becameActive) return;

    const enabledYears = Array.isArray(after.enabledYears)
      ? after.enabledYears.map((y) => parseYearValue(y)).filter(Boolean)
      : [];
    const enabledBranches = Array.isArray(after.enabledBranches)
      ? after.enabledBranches.map((b) => String(b || '').trim()).filter(Boolean)
      : [];

    const studentsSnap = await db.collection('students').get();
    const targets = [];

    studentsSnap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const studentId = getStudentIdFromData(data, doc.id);
      if (!studentId) return;

      const studentYear = parseYearValue(data.year);
      if (enabledYears.length > 0 && !enabledYears.includes(studentYear)) return;

      if (enabledBranches.length > 0) {
        const studentBranch = data.branch || data.department || data.dept || '';
        const branchOk = enabledBranches.some((b) => branchMatches(studentBranch, b));
        if (!branchOk) return;
      }

      targets.push(buildTarget('student', studentId, doc.ref, data));
    });

    if (targets.length === 0) return;

    await dispatchNotifications({
      targets,
      type: 'feedback_session_open',
      title: 'Feedback Window Open',
      body: 'Feedback submission is now open for eligible students.',
      relatedDocId: context.params.docId,
      metadata: {
        semester: String(after.semester || ''),
        academicYear: String(after.academicYear || ''),
      },
    });
  });

exports.notifyStudentsOnCourseRegistrationOpen = functions
  .region('us-central1')
  .firestore.document('settings/courseRegistration')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const wasEnabled = before?.isRegistrationEnabled === true;
    const isEnabled = after.isRegistrationEnabled === true;
    if (!isEnabled || wasEnabled) return;

    const enabledYears = Array.isArray(after.enabledYears)
      ? after.enabledYears.map((y) => parseYearValue(y)).filter(Boolean)
      : [];
    const enabledSemesters = Array.isArray(after.enabledSemesters)
      ? after.enabledSemesters.map((s) => normalizeSemester(s)).filter(Boolean)
      : [];
    const enabledBranches = Array.isArray(after.enabledBranches)
      ? after.enabledBranches.map((b) => String(b || '').trim()).filter(Boolean)
      : [];

    const studentsSnap = await db.collection('students').get();
    const targets = [];

    studentsSnap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const studentId = getStudentIdFromData(data, doc.id);
      if (!studentId) return;

      const studentYear = parseYearValue(data.year);
      if (enabledYears.length > 0 && !enabledYears.includes(studentYear)) return;

      const studentSemester = normalizeSemester(data.semester);
      if (enabledSemesters.length > 0 && !enabledSemesters.includes(studentSemester)) return;

      if (enabledBranches.length > 0) {
        const studentBranch = data.branch || data.department || data.dept || '';
        const branchOk = enabledBranches.some((b) => branchMatches(studentBranch, b));
        if (!branchOk) return;
      }

      targets.push(buildTarget('student', studentId, doc.ref, data));
    });

    if (targets.length === 0) return;

    await dispatchNotifications({
      targets,
      type: 'course_registration_open',
      title: 'Course Registration Open',
      body: 'Course registration is now enabled for your batch/branch.',
      relatedDocId: context.params.docId,
    });
  });

exports.notifyStudentOnFeePaymentStatus = functions
  .region('us-central1')
  .firestore.document('feePayments/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return;

    const newStatus = String(after.status || '').trim().toLowerCase();
    const oldStatus = String(before?.status || '').trim().toLowerCase();
    if (newStatus !== 'paid' || oldStatus === 'paid') return;

    const rollNo = normalizeId(after.rollNo || after.hallTicketNumber || after.studentId);
    if (!rollNo) return;

    const feeType = String(after.feeTypeLabel || after.paymentType || 'Fee').trim();
    const amount = Number(after.amount ?? 0);

    const targets = await getRoleTargets('student', rollNo);
    await dispatchNotifications({
      targets,
      type: 'fee_payment_paid',
      title: 'Fee Payment Confirmed',
      body: `${feeType} payment marked as paid${amount > 0 ? ` (Rs. ${amount.toFixed(2)})` : ''}.`,
      relatedDocId: context.params.docId,
      metadata: {
        paymentType: String(after.paymentType || ''),
        amount,
      },
    });
  });
