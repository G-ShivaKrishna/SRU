# Course Registration Feature Implementation Guide

## Overview

This document outlines the course registration feature implementation with admin controls. The feature has three main components:

1. **Admin Enable/Disable Registration** - Admin can toggle course registration on/off with date ranges
2. **Course Definition** - Admin defines which courses are available for which year and branch
3. **Course Requirements** - Admin sets how many courses of each type (OE, PE, SE) are required for each year/branch

## Data Models

### 1. Course Model (`lib/models/course_model.dart`)

Represents a course with the following properties:

- `code`: Course code (e.g., "22CS301")
- `name`: Course name
- `credits`: Credit hours
- `type`: CourseType enum (OE, PE, or SE)
- `applicableYears`: List of years this course is for (e.g., ['1', '2'])
- `applicableBranches`: List of branches this course is for (e.g., ['CSE', 'ECE'])
- `isActive`: Whether the course is active
- `createdAt`, `updatedAt`: Timestamps

### 2. CourseType Enum

```dart
enum CourseType {
  OE,  // Open Elective
  PE,  // Program Elective
  SE   // Subject Elective
}
```

### 3. CourseRequirement Model

Defines how many courses of each type are required for a year/branch combination:

- `year`: Year of study ('1', '2', '3', '4')
- `branch`: Branch name ('CSE', 'ECE', etc.)
- `oeCount`: Number of Open Electives required
- `peCount`: Number of Program Electives required
- `seCount`: Number of Subject Electives required

### 4. CourseRegistrationSettings Model

Stores the course registration status:

- `isRegistrationEnabled`: Toggle to enable/disable registration
- `registrationStartDate`: When registration opens
- `registrationEndDate`: When registration closes
- `lastModifiedBy`: Timestamp of last modification

## Firestore Collection Structure

```
/courses
  - {courseId}
    - code: string
    - name: string
    - credits: number
    - type: string ("OE", "PE", or "SE")
    - applicableYears: array
    - applicableBranches: array
    - isActive: boolean
    - createdAt: timestamp
    - updatedAt: timestamp

/courseRequirements
  - {requirementId}
    - year: string
    - branch: string
    - oeCount: number
    - peCount: number
    - seCount: number
    - createdAt: timestamp
    - updatedAt: timestamp

/settings
  - courseRegistration (document)
    - isRegistrationEnabled: boolean
    - registrationStartDate: timestamp
    - registrationEndDate: timestamp
    - lastModifiedBy: timestamp
    - createdAt: timestamp
    - updatedAt: timestamp
```

## Service Layer

### AdminCourseService (`lib/services/admin_course_service.dart`)

Methods for managing registration settings:

- `getRegistrationSettings()` - Get current registration status
- `toggleRegistration(bool enable, DateTime startDate, DateTime endDate)` - Enable/disable registration

Methods for managing courses:

- `addCourse(Course course)` - Add a new course
- `updateCourse(String courseId, Course course)` - Update a course
- `deleteCourse(String courseId)` - Delete a course
- `getCourse(String courseId)` - Get a single course
- `getAllCourses()` - Get all courses
- `getCoursesByType(CourseType type)` - Get courses of a specific type
- `getCoursesForYearAndBranch(String year, String branch)` - Get courses for a specific year/branch
- `getCoursesByTypeForYearAndBranch(CourseType type, String year, String branch)` - Get specific course types for a year/branch
- `getCoursesByTypeForYearAndBranchGrouped(String year, String branch)` - Get courses grouped by type

Methods for managing course requirements:

- `addCourseRequirement(CourseRequirement requirement)` - Add or update requirement
- `updateCourseRequirement(String requirementId, CourseRequirement requirement)` - Update requirement
- `getCourseRequirement(String year, String branch)` - Get requirement for a year/branch
- `getAllCourseRequirements()` - Get all requirements
- `deleteCourseRequirement(String requirementId)` - Delete a requirement

## Admin Screens

### 1. AdminCourseManagementScreen (`lib/roles/admin/screens/admin_course_management_screen.dart`)

Three-tab interface for complete course management:

#### Tab 1: Registration Settings

- Toggle to enable/disable course registration
- Set registration start and end dates
- Display current registration status

#### Tab 2: Manage Courses

- **Add New Course Form:**
  - Course Code
  - Course Name
  - Credits
  - Course Type (OE/PE/SE) dropdown
  - Select Years (multi-select chips)
  - Select Branches (multi-select chips)
- **View All Courses:**
  - List view of all added courses
  - Shows course details and applicable years/branches
  - Delete option for each course

#### Tab 3: Course Requirements

- **Set Requirements Form:**
  - Year selector
  - Branch selector
  - Counter inputs for OE, PE, and SE counts
- **View Current Requirements:**
  - Display all configured requirements
  - Shows count for each course type
  - Delete option for each requirement

### 2. AdminHomeScreen (`lib/roles/admin/screens/admin_home_screen.dart`)

Dashboard with menu items for different admin functions:

- Course Management (fully implemented)
- Faculty Management (placeholder)
- Student Management (placeholder)
- Reports (placeholder)

## Integration Steps

### Step 1: Add to Role Selection

Update `lib/screens/role_selection_screen.dart` to include Admin role navigation.

### Step 2: Update App Navigation

In `lib/app/app.dart` or your main navigation, add routes for admin screens:

```dart
// Example navigation
if (userRole == 'admin') {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const AdminHomeScreen(),
    ),
  );
}
```

### Step 3: Initialize Firestore Rules

Ensure Firestore security rules allow admin users to create/update the following collections:

- `/courses` - Create, read, update, delete
- `/courseRequirements` - Create, read, update, delete
- `/settings/courseRegistration` - Read, update

Example Firestore rules:

```javascript
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
```

## Usage Flow

### For Admin Users:

1. Login → Navigate to Admin Dashboard
2. Click "Course Management"
3. Go to "Registration Settings" tab
4. Toggle registration ON/OFF and set dates
5. Go to "Manage Courses" tab
6. Add courses with:
   - Course code, name, credits
   - Type (OE/PE/SE)
   - Applicable years and branches
7. Go to "Course Requirements" tab
8. Set how many courses of each type are needed for each year/branch

### For Student Users:

(Will be implemented in next phase)

1. Check if registration is enabled ← Uses `getRegistrationSettings()`
2. View available courses for their year/branch ← Uses `getCoursesByTypeForYearAndBranchGrouped()`
3. Select required number of each course type ← Uses `getCourseRequirement()`
4. Submit registration

## Next Steps (For Student-Facing Features)

1. **Student Course Registration View:**
   - Display available courses by type
   - Validate course selections against requirements
   - Submit/save course selections to new `studentCourses` collection

2. **Student Course Status View:**
   - Show registered courses grouped by type
   - Display registration status (pending, confirmed, etc.)

3. **Edit/Update Registration:**
   - Allow students to modify selections within the registration window
   - Implement validation against available slots

4. **Timetable Integration:**
   - Show course schedules/timetables
   - Handle time conflict detection

5. **Lab/Tutorial Batch Assignment:**
   - Map selected courses to lab/tutorial batches
   - Show batch allocation information

## Testing Checklist

- [ ] Admin can toggle registration on/off
- [ ] Admin can set registration date ranges
- [ ] Admin can add courses with all properties
- [ ] Admin can assign courses to specific years/branches
- [ ] Admin can add course type assignments
- [ ] Admin can set course requirements (OE/PE/SE counts)
- [ ] Course data persists in Firestore
- [ ] Requirements validation works correctly
- [ ] Mobile responsive layouts function properly
- [ ] Error messages display appropriately

## Files Created/Modified

### New Files:

1. `lib/models/course_model.dart` - Data models
2. `lib/services/admin_course_service.dart` - Firebase service
3. `lib/roles/admin/screens/admin_course_management_screen.dart` - Admin management UI
4. `lib/roles/admin/screens/admin_home_screen.dart` - Admin dashboard
5. `COURSE_REGISTRATION_SETUP.md` - This file

### Files to Modify:

1. `lib/screens/role_selection_screen.dart` - Add admin option
2. `lib/app/app.dart` - Add admin routes and navigation
3. Firestore security rules - Update permissions
