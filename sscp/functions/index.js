const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');
const { logger } = require('firebase-functions');

admin.initializeApp();

exports.notifyStudentOnMarksUpload = functions
  .region('us-central1')
  .firestore.document('studentMarks/{docId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    if (!after) return;

    const beforeTotal = Number(before?.totalMarks ?? -1);
    const afterTotal = Number(after?.totalMarks ?? -1);
    const beforeMarksJson = JSON.stringify(before?.componentMarks ?? {});
    const afterMarksJson = JSON.stringify(after?.componentMarks ?? {});

    // Skip updates that do not change marks to avoid duplicate notifications.
    if (before && beforeTotal === afterTotal && beforeMarksJson === afterMarksJson) {
      return;
    }

    const studentId = String(after.studentId || '').trim().toUpperCase();
    if (!studentId) {
      logger.warn('Skipping marks notification: studentId missing', {
        docId: context.params.docId,
      });
      return;
    }

    const db = admin.firestore();
    const studentRef = db.collection('students').doc(studentId);
    const studentSnap = await studentRef.get();

    if (!studentSnap.exists) {
      logger.warn('Skipping marks notification: student doc not found', { studentId });
      return;
    }

    const studentData = studentSnap.data() || {};
    const fcmTokens = Array.isArray(studentData.fcmTokens)
      ? studentData.fcmTokens.filter((t) => typeof t === 'string' && t.length > 0)
      : [];

    if (fcmTokens.length === 0) {
      logger.info('Skipping push: student has no FCM tokens', { studentId });
      return;
    }

    let facultyName = String(after.facultyName || '').trim();
    const facultyId = String(after.facultyId || '').trim();
    if (!facultyName && facultyId) {
      const facultySnap = await db.collection('faculty').doc(facultyId).get();
      if (facultySnap.exists) {
        const facultyData = facultySnap.data() || {};
        facultyName = String(facultyData.name || facultyData.facultyName || facultyId).trim();
      }
    }
    if (!facultyName) {
      facultyName = 'Faculty';
    }

    const subjectCode = String(after.subjectCode || '').trim();
    const subjectName = String(after.subjectName || 'Subject').trim();
    const totalMarks = Number(after.totalMarks ?? 0);
    const maxMarks = Number(after.maxMarks ?? 0);

    const title = 'Marks Uploaded';
    const body = `${subjectCode ? `${subjectCode} - ` : ''}${subjectName}: ${totalMarks}/${maxMarks} by ${facultyName}`;

    const notificationRef = db.collection('notifications').doc();
    await notificationRef.set({
      recipientRole: 'student',
      recipientId: studentId,
      type: 'marks_uploaded',
      title,
      body,
      isRead: false,
      relatedDocId: context.params.docId,
      metadata: {
        assignmentId: String(after.assignmentId || ''),
        subjectCode,
        subjectName,
        facultyId,
        facultyName,
        totalMarks,
        maxMarks,
        academicYear: String(after.academicYear || ''),
        semester: String(after.semester || ''),
        year: Number(after.year || 0),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const message = {
      tokens: fcmTokens,
      notification: {
        title,
        body,
      },
      data: {
        type: 'marks_uploaded',
        notificationId: notificationRef.id,
        studentId,
        subjectCode,
        subjectName,
        totalMarks: `${totalMarks}`,
        maxMarks: `${maxMarks}`,
      },
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    };

    const sendResponse = await admin.messaging().sendEachForMulticast(message);

    if (sendResponse.failureCount > 0) {
      const invalidTokens = [];
      sendResponse.responses.forEach((res, index) => {
        if (!res.success) {
          const code = res.error?.code || '';
          if (
            code.includes('registration-token-not-registered') ||
            code.includes('invalid-argument')
          ) {
            invalidTokens.push(fcmTokens[index]);
          }
          logger.warn('Push send failed for token', {
            studentId,
            tokenIndex: index,
            errorCode: code,
          });
        }
      });

      if (invalidTokens.length > 0) {
        await studentRef.set(
          {
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
            fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }

    logger.info('Marks upload notification processed', {
      studentId,
      successCount: sendResponse.successCount,
      failureCount: sendResponse.failureCount,
    });
  }
);
