# Admin Panel Integration Guide

## What's Ready

✅ **Admin Panel** - Complete academic calendar management page with:
- Form to add new academic calendars
- PDF file upload to Firebase Storage (automatic)
- View all existing calendars
- Delete calendars

✅ **Student Screen** - View academic calendars with:
- Filter by Academic Year, Degree, Semester
- Table display of calendars
- PDF viewer from Firebase Storage

✅ **Backend** - Firebase setup ready:
- Firestore collection structure
- Storage folder hierarchy
- Security rules template
- Role-based access control

## Quick Integration Steps

### Step 1: Add to Admin Navigation

In your admin drawer/menu navigation file, add:

```dart
import 'package:sscp/roles/admin/pages/academic_calendar_management_page.dart';

// In your admin menu
ListTile(
  leading: const Icon(Icons.calendar_today),
  title: const Text('Academic Calendar'),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const AcademicCalendarManagementPage(),
    ),
  ),
),
```

### Step 2: Set Up Firebase (One Time)

1. **Create Firestore Collection**
   - Open Firebase Console
   - Go to Firestore Database
   - Create collection: `academic_calendars`
   - (Fields auto-create on first add)

2. **Set Security Rules**
   ```firestore
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /academic_calendars/{document=**} {
         allow read: if request.auth.uid != null;
         allow write: if request.auth.token.role == 'admin';
         allow delete: if request.auth.token.role == 'admin';
       }
     }
   }
   ```

3. **Set Storage Rules**
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /academic_calendars/{allPaths=**} {
         allow read: if request.auth.uid != null;
         allow write: if request.auth.token.role == 'admin';
       }
     }
   }
   ```

4. **Mark User as Admin**
   - Go to Firebase Auth → Users
   - Click on admin user
   - Click Custom Claims (pencil icon)
   - Add: `{"role": "admin"}`
   - Save

### Step 3: Test

**Admin Flow:**
1. Login as admin
2. Go to "Academic Calendar" menu
3. Fill form with calendar details
4. Select & upload PDF
5. Click "Add Academic Calendar"
6. View in "Existing Academic Calendars" list

**Student Flow:**
1. Login as student
2. Go to "Academic Calendar" screen
3. Select year, degree, semester
4. Click "Search"
5. View results in table
6. Click PDF icon to view PDF

## File Locations

| File | Purpose |
|------|---------|
| `lib/roles/admin/pages/academic_calendar_management_page.dart` | Admin panel |
| `lib/roles/student/screens/academics_screen.dart` | Student view |
| `ACADEMIC_CALENDAR_SETUP.md` | Complete setup guide |

## Key Features

### Admin Panel
- ✅ Add academic calendars
- ✅ Upload PDFs automatically
- ✅ View all calendars
- ✅ Delete calendars
- ✅ Auto-generates Firebase Storage paths
- ✅ Displays success/error messages

### Student Screen
- ✅ Filter by Year, Degree, Semester
- ✅ Table view matching your design
- ✅ View PDF files
- ✅ Download capability
- ✅ Zoom & scroll in PDF viewer

### Backend (Firebase)
- ✅ Firestore storage (documents)
- ✅ Firebase Storage (PDF files)
- ✅ Automatic URL generation
- ✅ Role-based access control
- ✅ Secure read/write rules

## Admin User Setup

### Method 1: Firebase Console (Easiest)
1. Go to Firebase Console
2. Authentication → Users
3. Click on the user you want to make admin
4. Click "Custom Claims" (pencil icon)
5. Paste: `{"role": "admin"}`
6. Save

### Method 2: Firebase CLI
```bash
firebase auth:set --custom-claims='{"role":"admin"}' user_uid
```

## Deployment Checklist

- [ ] Create Firestore collection `academic_calendars`
- [ ] Update Firestore security rules
- [ ] Update Storage security rules
- [ ] Set admin user custom claims
- [ ] Add admin menu item to your app
- [ ] Test admin panel (add calendar)
- [ ] Test student screen (view calendar)
- [ ] Deploy to production

## Support

Reference the complete setup guide: **ACADEMIC_CALENDAR_SETUP.md**

For issues:
1. Check Firebase Console
2. Verify security rules
3. Confirm admin role is set
4. Check app logs for errors
5. Ensure PDFs < 50MB
