# Academic Calendar Backend Setup Guide

## Overview

This guide explains the complete workflow for managing academic calendars. The **Admin Panel** handles all data entry, PDF uploads, and Firestore management. **Students** simply view the data through the student screens.

## Admin vs Student Workflow

### Admin Side (Responsibility)

✅ Upload PDF files to Firebase Storage
✅ Fill in academic calendar details
✅ Manage start/end dates  
✅ Create, edit, delete records in Firestore
✅ Everything is automated through the admin panel

### Student Side (Read Only)

✅ View available academic calendars
✅ Filter by year, degree, semester
✅ Download and view PDFs
✅ No data entry required

## Admin Panel Features

The **Academic Calendar Management Page** provides:

1. **Form to Add New Calendar**
   - Select Academic Year (2022-23 to 2026-27)
   - Select Degree (BTECH, MTECH, MBA, MCA)
   - Select Year (1-4)
   - Select Semester (1-8)
   - Pick Start Date
   - Pick End Date
   - Upload PDF file

2. **Automatic PDF Upload**
   - Select PDF file (max 50MB)
   - File auto-uploads to Firebase Storage
   - Download URL automatically retrieved
   - URL saved in Firestore

3. **View Existing Calendars**
   - List of all added calendars
   - Delete option
   - Quick view of dates and details

## Firebase Setup (One Time)

### 1. Firestore Collection Structure

Create a Firestore collection named `academic_calendars`:

```
academic_calendars/ (Collection)
├─ Document Auto-Generated
│  ├─ academicYear (string): "2025-26"
│  ├─ degree (string): "BTECH"
│  ├─ year (integer): 1
│  ├─ semester (integer): 2
│  ├─ startDate (timestamp): 2026-01-05
│  ├─ endDate (timestamp): 2026-04-28
│  ├─ pdfUrl (string): "https://firebasestorage.googleapis.com/..."
│  └─ createdAt (timestamp): auto
```

### 2. Firebase Storage Structure (Auto-Created)

When admin uploads PDFs, folders are automatically created:

```
academic_calendars/
├─ 2025-26/
│  ├─ BTECH/
│  │  ├─ sem_1/
│  │  │  └─ Academic_Calendar_2025-26_BTECH_Sem1.pdf
│  │  ├─ sem_2/
│  │  │  └─ Academic_Calendar_2025-26_BTECH_Sem2.pdf
│  │  └─ ...
│  ├─ MTECH/
│  │  └─ ...
```

## Security Rules Setup

### Firestore Rules (Copy & Paste)

Go to Firestore → Rules and replace with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read academic calendars
    match /academic_calendars/{document=**} {
      allow read: if request.auth.uid != null;
      // Only admins can write
      allow write: if request.auth.token.role == 'admin';
      allow delete: if request.auth.token.role == 'admin';
    }
  }
}
```

### Storage Rules (Copy & Paste)

Go to Storage → Rules and replace with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /academic_calendars/{allPaths=**} {
      // Authenticated users can read
      allow read: if request.auth.uid != null;
      // Only admins can upload and delete
      allow write: if request.auth.token.role == 'admin';
    }
  }
}
```

## How to Set Admin Role in Firebase

### Option 1: Firebase Console (Manual)

1. Go to Authentication → Users
2. Click on admin user
3. Click "Custom claims" (pencil icon)
4. Add: `{"role": "admin"}`
5. Save

### Option 2: Firebase CLI (Recommended)

```bash
firebase functions:config:set auth.admin_uid="user_uid_here"
```

### Option 3: Create a Cloud Function

```javascript
// Set admin claims via a callable function
const admin = require("firebase-admin");

exports.setAdminRole = functions.https.onCall(async (data, context) => {
  const uid = data.uid;

  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can set roles",
    );
  }

  await admin.auth().setCustomUserClaims(uid, { role: "admin" });
  return { message: `Admin role set for user ${uid}` };
});
```

## Integration with Your App

### Step 1: Add Route in Navigation

In your main navigation/routes file, add:

```dart
import 'package:sscp/roles/admin/pages/academic_calendar_management_page.dart';

// In your navigation
if (userRole == 'admin') {
  routes['/academic-calendar-management'] = (context) =>
    const AcademicCalendarManagementPage();
}
```

### Step 2: Add Menu Item for Admins

In your admin menu/drawer:

```dart
if (userRole == 'admin')
  ListTile(
    leading: const Icon(Icons.calendar_today),
    title: const Text('Academic Calendar Management'),
    onTap: () => Navigator.pushNamed(
      context,
      '/academic-calendar-management'
    ),
  ),
```

## Admin Workflow

### Adding a New Academic Calendar

1. Navigate to "Academic Calendar Management"
2. Fill the form:
   - Select Academic Year (e.g., 2025-26)
   - Select Degree (e.g., BTECH)
   - Select Year (e.g., 1)
   - Select Semester (e.g., 2)
   - Click to pick Start Date (e.g., 01-05-2026)
   - Click to pick End Date (e.g., 28-04-2026)
3. Click "Select PDF file"
   - Browse and select the PDF
   - File displays with name and size
4. Click "Add Academic Calendar"
   - PDF auto-uploads to Firebase Storage
   - Record saved to Firestore
   - Success message appears

### Viewing Added Calendars

- See all added calendars in "Existing Academic Calendars" section
- Quick view shows: Year, Degree, Year Level, Semester, Dates
- Click 3-dot menu to delete if needed

## Student View (Automatic)

Once admin adds calendars:

1. Students go to "Academic Calendar" screen
2. Select filters (Academic Year, Degree, Semester)
3. Click "Search"
4. Table displays all matching calendars
5. Click PDF icon to view the PDF

## Data Flow Diagram

```
┌─────────────────────────────┐
│  Admin Panel                 │
│  - Select Year/Degree/Sem    │
│  - Pick Dates                │
│  - Upload PDF                │
└──────────────┬──────────────┘
               │ Uploads & Forms Data
               ▼
    ┌──────────────────────┐
    │  Firebase Storage    │
    │  (Stores PDFs)       │
    └──────────────┬───────┘
                   │
    ┌──────────────▼──────────────┐
    │  Firestore DB               │
    │  academic_calendars         │
    │  - Records with PDF URLs    │
    └──────────────┬──────────────┘
                   │ Queries Data
                   ▼
         ┌─────────────────────┐
         │  Student App        │
         │  - Filter & Search  │
         │  - View Table       │
         │  - Download PDFs    │
         └─────────────────────┘
```

## Troubleshooting

| Issue                              | Solution                                                     |
| ---------------------------------- | ------------------------------------------------------------ |
| "Permission denied" when uploading | Make sure user has `admin` custom claim set in Firebase Auth |
| PDF not uploading                  | Check file size (max 50MB) and storage quota                 |
| Form won't submit                  | Ensure all fields are filled including PDF                   |
| Students can't see data            | Check Firestore security rules allow authenticated reads     |
| PDF icon doesn't work              | Verify pdfUrl in Firestore is correct and accessible         |

## Database Backup

To backup your academic calendars:

```bash
firebase firestore:export gs://your-bucket/backups/academic-calendars-backup --collection-ids=academic_calendars
```

## Setup Checklist

Follow these steps in order:

- [ ] **Create Firestore Collection**
  - Go to Firebase Console → Firestore
  - Create collection named `academic_calendars`
  - No field creation needed (auto-created on first add)

- [ ] **Configure Security Rules**
  - Copy Firestore rules above
  - Go to Firestore → Rules tab
  - Replace with provided rules

- [ ] **Configure Storage Rules**
  - Copy Storage rules above
  - Go to Storage → Rules tab
  - Replace with provided rules

- [ ] **Set Admin User**
  - Go to Firebase Auth → Users
  - Select admin user
  - Click Custom Claims (pencil icon)
  - Add: `{"role": "admin"}`

- [ ] **Update Your App**
  - Run `flutter pub get`
  - Add route to admin page in navigation
  - Add menu item in admin drawer

- [ ] **Test Admin Panel**
  - Login as admin user
  - Navigate to Academic Calendar Management
  - Add test calendar with PDF
  - Verify it appears in list

- [ ] **Test Student View**
  - Login as student user
  - Go to Academic Calendar screen
  - Search for filters
  - Verify calendar appears
  - Click PDF icon to view

- [ ] **Deploy to Production**
  - Test on real devices
  - Monitor Firebase usage
  - Set up backup schedule

## File Locations

| File                                                           | Purpose                            |
| -------------------------------------------------------------- | ---------------------------------- |
| `lib/roles/admin/pages/academic_calendar_management_page.dart` | Admin panel for managing calendars |
| `lib/roles/student/screens/academics_screen.dart`              | Student view of calendars          |
| `ACADEMIC_CALENDAR_SETUP.md`                                   | This setup guide                   |

## Support

For issues:

1. Check the Troubleshooting section
2. Verify Firebase Console settings
3. Check app logs for detailed errors
4. Ensure PDFs are < 50MB
5. Verify custom claims are set correctly
