# Academic Calendar Implementation Summary

## What Was Done

### 1. **Updated UI to Table Format**
   - Changed from event-based calendar view to a data table
   - Table displays columns: S.No, Academic Year, Degree, Year, Sem, S Date, E Date, View
   - Matches your design image exactly

### 2. **Firebase Integration**
   - Added Firestore queries to fetch academic calendar data
   - Filters data by: Academic Year, Degree, and Semester
   - Returns results in a structured table format

### 3. **PDF Viewer Implementation**
   - Added `PdfViewerScreen` widget for viewing PDFs
   - PDF icon in the "View" column is clickable
   - Opens Firebase Storage PDFs directly in the app
   - Supports zoom, pan, and page navigation

### 4. **Data Model**
   - Created `AcademicCalendarModel` class
   - Maps Firestore documents to Dart objects
   - Handles date conversion from Firestore Timestamps

## Dependencies Added

```yaml
pdfx: ^2.9.2  # PDF viewing library with pinch to zoom
intl: ^0.19.0  # Date formatting (yyyy-MM-dd)
```

## File Changes

### [academics_screen.dart](../lib/roles/student/screens/academics_screen.dart)

#### Key Components:

1. **AcademicCalendarModel** (lines 8-43)
   - Firestore document mapper
   - Parses timestamps, dates, and URLs

2. **_AcademicsScreenState** (lines 52-412)
   - Manages state and Firebase queries
   - Methods:
     - `build()` - Main UI layout
     - `_buildFilterCard()` - Filter selection UI
     - `_buildTableContent()` - Table display
     - `_buildNoDataMessage()` - Empty state UI
     - `_onSearchPressed()` - Firestore query handler
     - `_openPdfViewer()` - Navigate to PDF

3. **PdfViewerScreen** (lines 413-502)
   - Full-screen PDF viewer
   - Pinch-to-zoom functionality
   - Error handling with fallback UI

## Firestore Collection Structure

You need to create this structure in Firebase:

```
academic_calendars/
├─ doc_1/
│  ├─ academicYear: "2025-26"
│  ├─ degree: "BTECH"
│  ├─ year: 1
│  ├─ semester: 2
│  ├─ startDate: Timestamp(2026-01-05)
│  ├─ endDate: Timestamp(2026-04-28)
│  └─ pdfUrl: "https://firebasestorage.googleapis.com/..."
```

## How to Use

### Step 1: Set Up Firebase
1. Create Firestore collection: `academic_calendars`
2. Upload PDF files to Firebase Storage
3. Create documents with the structure above

### Step 2: Add Sample Data
```json
{
  "academicYear": "2025-26",
  "degree": "BTECH",
  "year": 1,
  "semester": 2,
  "startDate": "2026-01-05",
  "endDate": "2026-04-28",
  "pdfUrl": "https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/academic_calendars%2F2025-26%2FBTECH%2Fsem_2%2Facademic.pdf?alt=media&token=..."
}
```

### Step 3: Test in App
1. Select Academic Year, Degree, and Semester
2. Click "Search"
3. Results appear in table
4. Click PDF icon to view

## User Flow

```
Student selects filters
    ↓
Clicks "Search"
    ↓
App queries Firestore:
  WHERE academicYear == selected
  AND degree == selected
  AND semester == selected
    ↓
Results displayed in table
    ↓
Student clicks PDF icon
    ↓
PdfViewerScreen opens
    ↓
PDF loads from Firebase Storage
    ↓
Student can scroll, zoom, read
```

## Firebase Security Rules

Add these rules to allow students to read academic calendars:

**Firestore:**
```
match /academic_calendars/{document=**} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.token.role == 'admin';
}
```

**Cloud Storage:**
```
match /academic_calendars/{allPaths=**} {
  allow read: if request.auth.uid != null;
  allow write: if request.auth.token.role == 'admin';
}
```

## API Response Example

When you query Firestore for 2025-26, BTECH, Semester 2:

```json
{
  "documents": [
    {
      "id": "doc_1",
      "academicYear": "2025-26",
      "degree": "BTECH",
      "year": 1,
      "semester": 2,
      "startDate": "2026-01-05",
      "endDate": "2026-04-28",
      "pdfUrl": "https://..."
    },
    {
      "id": "doc_2",
      "academicYear": "2025-26",
      "degree": "BTECH",
      "year": 2,
      "semester": 2,
      "startDate": "2026-01-05",
      "endDate": "2026-04-28",
      "pdfUrl": "https://..."
    }
  ]
}
```

## Backend Upload Example (Node.js)

```javascript
const admin = require('firebase-admin');
const bucket = admin.storage().bucket();
const db = admin.firestore();

async function uploadAcademicCalendar(pdfPath, metadata) {
  // Upload PDF to Storage
  const destination = `academic_calendars/${metadata.academicYear}/${metadata.degree}/sem_${metadata.semester}/calendar.pdf`;
  await bucket.upload(pdfPath, { destination });
  
  // Get download URL
  const file = bucket.file(destination);
  const [url] = await file.getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 15778800000, // 6 months
  });
  
  // Add to Firestore
  await db.collection('academic_calendars').add({
    academicYear: metadata.academicYear,
    degree: metadata.degree,
    year: metadata.year,
    semester: metadata.semester,
    startDate: admin.firestore.Timestamp.fromDate(new Date(metadata.startDate)),
    endDate: admin.firestore.Timestamp.fromDate(new Date(metadata.endDate)),
    pdfUrl: url,
  });
}
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| **No data found** | Check Firestore has documents matching your filters |
| **PDF not loading** | Verify pdfUrl is publicly accessible (check Storage rules) |
| **"Please select all filters"** | Ensure all three dropdowns have values selected |
| **Firebase permission error** | Check Firestore/Storage security rules |
| **PDF loads slowly** | Check PDF file size (keep under 50MB) |

## Next Steps

1. ✅ Replace academics_screen.dart (DONE)
2. ✅ Add dependencies (DONE)
3. ⬜ Create Firestore collection
4. ⬜ Upload PDFs to Firebase Storage
5. ⬜ Add sample documents to Firestore
6. ⬜ Test in emulator/device
7. ⬜ Set up Security Rules for production

See `ACADEMIC_CALENDAR_SETUP.md` for detailed backend setup instructions.
