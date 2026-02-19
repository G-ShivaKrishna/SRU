# Course Registration Feature - Integration Guide

## Quick Integration Steps

### Step 1: Update AdminHome Navigation
The admin dashboard (`lib/roles/admin/admin_home.dart`) needs to include the course management option.

**Changes needed:**
1. Add 'Course Management' to the menuItems list
2. Add case for 'Course Management' in the _navigateToPage method
3. Add course management action card to the quick actions grid

### Step 2: Import Requirements
Add the following import to your admin screens:
```dart
import 'screens/admin_course_management_screen.dart';
```

### Step 3: Update Firestore Security Rules
Update your Firestore rules to allow admin access to the new collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Course Management Collections
    match /courses/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    match /courseRequirements/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    match /settings/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.role == 'admin';
    }
    
    // Existing rules...
    // (keep your current rules and add above)
  }
}
```

## Feature Components

### Models Created
- **Course** - Represents a course with code, name, credits, type, and applicable years/branches
- **CourseType** - Enum for OE (Open Elective), PE (Program Elective), SE (Subject Elective)
- **CourseRequirement** - Stores requirements (how many of each type) for year/branch combinations
- **CourseRegistrationSettings** - Manages registration enable/disable and date ranges

### Services Created
- **AdminCourseService** - Handles all Firestore operations for course management

### Screens Created
1. **AdminCourseManagementScreen** - Main course management interface with 3 tabs:
   - Registration Settings (enable/disable registration)
   - Manage Courses (add, view, delete courses)
   - Course Requirements (set requirements for year/branch)

2. **AdminHomeScreen** - Alternative admin dashboard (if used separately)

## Admin Workflow

### Basic Setup (First Time)
1. Admin logs in → Goes to Course Management
2. Enable Course Registration:
   - Go to "Registration Settings" tab
   - Toggle "Enable Course Registration"
   - Set registration start and end dates
   - Save

3. Add Courses:
   - Go to "Manage Courses" tab
   - Fill in course details (code, name, credits)
   - Select course type (OE/PE/SE)
   - Select applicable years (1, 2, 3, 4)
   - Select applicable branches (CSE, ECE, etc.)
   - Click "Add Course"
   - Repeat for all courses

4. Set Requirements:
   - Go to "Course Requirements" tab
   - Select a year and branch
   - Set number of courses needed for each type
   - Click "Save Requirements"
   - Repeat for all year/branch combinations

### Ongoing Management
- Toggle registration on/off as needed
- Update course details
- Adjust requirements based on needs

## Database Schema

### /courses Collection
```
{
  code: "22CS301",
  name: "Design and Analysis of Algorithms",
  credits: 3,
  type: "PE",  // OE, PE, or SE
  applicableYears: ["2", "3"],
  applicableBranches: ["CSE", "ECE"],
  isActive: true,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### /courseRequirements Collection
```
{
  year: "2",
  branch: "CSE",
  oeCount: 1,    // 1 Open Elective required
  peCount: 2,    // 2 Program Electives required
  seCount: 1,    // 1 Subject Elective required
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### /settings/courseRegistration Document
```
{
  isRegistrationEnabled: true,
  registrationStartDate: Timestamp,
  registrationEndDate: Timestamp,
  lastModifiedBy: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

## API Reference for Student Features (Phase 2)

These service methods will be used later for student-facing features:

```dart
// Get registration status
final settings = await adminCourseService.getRegistrationSettings();
bool isOpen = settings?.isRegistrationEnabled ?? false;

// Get available courses for student
final courses = await adminCourseService.getCoursesForYearAndBranch('2', 'CSE');

// Get courses grouped by type
final coursesByType = await adminCourseService
  .getCoursesByTypeForYearAndBranchGrouped('2', 'CSE');

// Get requirements for validation
final requirement = await adminCourseService.getCourseRequirement('2', 'CSE');

// Get specific course type
final oeList = await adminCourseService
  .getCoursesByTypeForYearAndBranch(CourseType.OE, '2', 'CSE');
```

## Files Summary

### New Files Created
1. `lib/models/course_model.dart` (280 lines)
   - Course, CourseType, CourseRequirement, CourseRegistrationSettings models

2. `lib/services/admin_course_service.dart` (220 lines)
   - All Firestore operations for course management

3. `lib/roles/admin/screens/admin_course_management_screen.dart` (850 lines)
   - Complete admin UI for managing all course registration aspects

4. `lib/roles/admin/screens/admin_home_screen.dart` (190 lines)
   - Optional alternative admin dashboard

5. `COURSE_REGISTRATION_SETUP.md` (310 lines)
   - Comprehensive implementation documentation

### Files to Update
1. `lib/roles/admin/admin_home.dart`
   - Add 'Course Management' to menuItems
   - Add navigation case for course management
   - Add quick action card for course management

## Testing Checklist

### Admin Course Management
- [ ] Admin can enable/disable registration
- [ ] Admin can set registration date range
- [ ] Admin can add new courses
- [ ] Admin can add multiple courses at once
- [ ] Admin can select multiple years for a course
- [ ] Admin can select multiple branches for a course
- [ ] Admin can delete courses
- [ ] Admin can set course requirements
- [ ] Admin can update existing requirements
- [ ] All data persists in Firestore
- [ ] UI is responsive on mobile and desktop

## Next Phase: Student Features

Will implement:
1. Student course registration form
2. Course selection with validation against requirements
3. Registration status display
4. Edit/update selections during open period
5. Generate registration confirmation/transcript

## Support

For issues or questions:
1. Check COURSE_REGISTRATION_SETUP.md for detailed documentation
2. Verify Firestore collections are created
3. Check console logs for Firebase errors
4. Ensure user has 'admin' role in Firebase Auth custom claims

## Version History

- **v1.0** (Feb 19, 2026)
  - Initial implementation
  - Admin enable/disable registration
  - Course management (add, view, delete)
  - Course type definitions (OE, PE, SE)
  - Course requirements configuration
