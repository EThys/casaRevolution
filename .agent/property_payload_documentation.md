# Property Creation Payload Documentation

This document describes the payload structures for creating different types of properties in the Casa Revolution application.

## Overview

The application supports multiple property types, each with its own specific payload structure:
1. **Standard Properties** (Studio, Apartments, Houses)
2. **Bureau** (Office spaces)
3. **Festive** (Event halls)
4. **Funeraire** (Funeral halls)

---

## 1. Standard Properties (Studio, Apartments, Houses)

### Payload Structure

```json
{
  "property": {
    "title": "string",
    "description": "string",
    "price": 0.1,
    "surface": 0.1,
    "rooms": 0,
    "bedrooms": 0,
    "kitchen": 0,
    "livingRoom": 0,
    "bathroom": 0,
    "floor": 0,
    "electric": 0,
    "water": 0,
    "guarantee": "string",
    "sold": false,
    "transactionType": "location|vente",
    "available": true,
    "userId": 0
  },
  "postBy": "string",
  "address": {
    "address": "string",
    "cityId": "string",
    "communeId": "string",
    "quartierId": "string",
    "cityValue": "string",
    "communeValue": "string",
    "quartierValue": "string",
    "postalCode": "string",
    "countryValue": "string"
  },
  "geoZone": {
    "lat": 0.1,
    "lng": 0.1
  },
  "typeProperty": {
    "propertyTypeId": 0
  },
  "features": [
    {
      "featureId": 0
    }
  ],
  "images": {
    "main": [
      {
        "image": "base64_string"
      }
    ],
    "room": [
      {
        "image": "base64_string"
      }
    ],
    "living": [
      {
        "image": "base64_string"
      }
    ],
    "kitchen": [
      {
        "image": "base64_string"
      }
    ]
  }
}
```

### Field Descriptions

#### Property Object
- **title**: Property title/name
- **description**: Detailed description of the property
- **price**: Rental or sale price
- **surface**: Total surface area in square meters
- **rooms**: Total number of rooms (calculated automatically)
- **bedrooms**: Number of bedrooms
- **kitchen**: Number of kitchens
- **livingRoom**: Number of living rooms
- **bathroom**: Number of bathrooms
- **floor**: Floor number
- **electric**: Electricity availability (0-24, representing hours)
- **water**: Water availability (0-24, representing hours)
- **guarantee**: Guarantee/deposit amount
- **sold**: Whether the property is sold (boolean)
- **transactionType**: "location" (rent) or "vente" (sale)
- **available**: Property availability status
- **userId**: ID of the user creating the property

#### Address Object
- **address**: Full street address
- **cityId**: City ID (for Kinshasa, use the selected city ID)
- **communeId**: Commune ID (for Kinshasa)
- **quartierId**: Quartier ID (for Kinshasa)
- **cityValue**: City name
- **communeValue**: Commune name
- **quartierValue**: Quartier/neighborhood name
- **postalCode**: Postal code (default: "243")
- **countryValue**: Country name (default: "RDC")

#### GeoZone Object
- **lat**: Latitude coordinate
- **lng**: Longitude coordinate

#### TypeProperty Object
- **propertyTypeId**: Property type identifier
  - 1: Studio
  - 2: Apartments
  - 3: Houses
  - 4: Bureau
  - 5: Hotels
  - 6: Vacances

#### Features Array
List of property features/amenities:
- Each feature has a `featureId` (1-13)
- Examples: WiFi, Air conditioning, Heating, Equipped kitchen, etc.

#### Images Object
Contains categorized images in base64 format:
- **main**: Main property images
- **room**: Bedroom images
- **living**: Living room images
- **kitchen**: Kitchen images

---

## 2. Bureau (Office Spaces)

### Payload Structure

```json
{
  "bureau": {
    "userId": 0,
    "deviseId": 0,
    "title": "string",
    "description": "string",
    "price": 0.1,
    "roomMeet": 0,
    "numberPiece": 0,
    "isEquip": true,
    "address": "string"
  },
  "images": [
    {
      "image": "base64_string"
    }
  ]
}
```

### Field Descriptions

#### Bureau Object
- **userId**: ID of the user creating the bureau
- **deviseId**: Currency ID (0 for default)
- **title**: Bureau title/name
- **description**: Detailed description
- **price**: Rental or sale price
- **roomMeet**: Number of meeting rooms
- **numberPiece**: Total number of rooms/pieces
- **isEquip**: Whether the office is equipped (boolean)
- **address**: Full address

#### Images Array
Flat array of all bureau images in base64 format

---

## 3. Festive (Event Halls)

### Payload Structure

```json
{
  "userId": 0,
  "deviseId": 1,
  "title": "string",
  "description": "string",
  "usage": "string",
  "capacityPeople": 0,
  "electric": 0,
  "price": 0.1,
  "address": "string",
  "latitude": 0.1,
  "longitude": 0.1,
  "isAvailable": true,
  "isDecore": true,
  "pisteDanse": true,
  "images": [
    "base64_string"
  ]
}
```

### Field Descriptions

- **userId**: ID of the user creating the festive hall
- **deviseId**: Currency ID (1 for default)
- **title**: Hall title/name
- **description**: Detailed description
- **usage**: Intended usage (e.g., "Mariage", "Anniversaire", "Autre")
- **capacityPeople**: Maximum capacity (number of people)
- **electric**: Electricity availability (0-24 hours)
- **price**: Rental price
- **address**: Full address
- **latitude**: Latitude coordinate
- **longitude**: Longitude coordinate
- **isAvailable**: Availability status
- **isDecore**: Whether the hall is decorated
- **pisteDanse**: Whether there's a dance floor
- **images**: Flat array of base64-encoded images

---

## 4. Funeraire (Funeral Halls)

### Payload Structure

```json
{
  "userId": 0,
  "deviseId": 1,
  "title": "string",
  "description": "string",
  "capacityPeople": 0,
  "price": 0.1,
  "address": "string",
  "latitude": 0.1,
  "longitude": 0.1,
  "isAvailable": true,
  "images": [
    "base64_string"
  ]
}
```

### Field Descriptions

- **userId**: ID of the user creating the funeral hall
- **deviseId**: Currency ID (1 for default)
- **title**: Hall title/name
- **description**: Detailed description
- **capacityPeople**: Maximum capacity (number of people)
- **price**: Rental price
- **address**: Full address
- **latitude**: Latitude coordinate
- **longitude**: Longitude coordinate
- **isAvailable**: Availability status
- **images**: Flat array of base64-encoded images

---

## Implementation Notes

### Image Handling

The application uses different image structures depending on the property type:

1. **Standard Properties & Bureau**: 
   - Images are organized by category (main, room, living, kitchen)
   - Each image is an object with an "image" key containing the base64 string
   - Structure: `[{"image": "base64_string"}]`

2. **Festive & Funeraire**:
   - Images are in a flat array
   - Each element is a base64 string directly
   - Structure: `["base64_string1", "base64_string2", ...]`

### Location Handling

The application supports two location modes:

1. **Kinshasa Mode**: Uses structured location data with IDs
   - cityId, communeId, quartierId are populated
   - Values are selected from predefined lists

2. **Other Cities Mode**: Uses text-based location data
   - IDs are empty strings
   - cityValue, communeValue, quartierValue are free text

### Validation

Before submission, the application validates:
- All required fields are filled
- Images are properly uploaded and converted to base64
- Location data is complete
- Network connectivity is available

### Error Handling

The `_handleCreatePropertyPost()` method includes:
- Step-by-step validation
- Network connectivity check
- Proper error messages
- Loading state management
- Draft clearing on success

---

## Code Reference

The main implementation is in `CreatePropertyPostPage.dart`:

- **_handleCreatePropertyPost()**: Main method for creating properties (line 4093)
- **_prepareImagesData()**: Prepares images in the correct format (line 4406)
- **_getPropertyTypeId()**: Maps category names to IDs (line 4502)
- **_getFeatureId()**: Maps feature names to IDs (line 4521)

---

## Recent Fixes

### Fixed: Null Check Operator Error #1 - Image Key (2025-12-25)

**Issue**: The code was accessing `e['base64']` when the actual key in the map is `'image'`.

**Location**: Line 4206-4209 in `_handleCreatePropertyPost()`

**Fix**: Changed all occurrences of `e['base64']` to `e['image']` to match the structure created in `_prepareImagesData()`.

```dart
// Before (INCORRECT)
allImagesBase64.addAll(imagesData['propertyImage']!.map((e) => e['base64']!).toList());

// After (CORRECT)
allImagesBase64.addAll(imagesData['propertyImage']!.map((e) => e['image']!).toList());
```

### Fixed: Null Check Operator Error #2 - Undefined fullname Variable (2025-12-25)

**Issue**: The variable `fullname` was used in the payload but was never defined, causing a null check operator error.

**Location**: Line 4312 in `_handleCreatePropertyPost()` (Standard Properties section)

**Fix**: Added proper retrieval of the user's full name from storage with fallback values.

```dart
// Added before creating propertyData
final GetStorage storage = GetStorage();
final dynamic userData = storage.read(StockageKeys.userKey);
final String fullname = userData?['fullname'] ?? 
                       userData?['user']?['fullname'] ?? 
                       userData?['name'] ?? 
                       userData?['user']?['name'] ?? 
                       "Utilisateur";
```

**Additional Enhancement**: Added comprehensive payload structure logging to help debug future issues:
- Logs all property fields
- Logs address fields
- Logs image counts for each category
- Logs features count
- Logs geoZone and typeProperty data

### Fixed: Type Casting Error #3 - List<dynamic> vs List<String> (2025-12-25)

**Issue**: Type mismatch error `'List<dynamic>' is not a subtype of type 'Iterable<String>'` when extracting image base64 strings.

**Location**: Line 4205-4208 in `_handleCreatePropertyPost()`

**Root Cause**: When accessing `e['image']` from a map, Dart returns a `dynamic` type. The `.map()` operation then produces a `List<dynamic>`, but we were trying to add it to a `List<String>` without explicit casting.

**Fix**: Added explicit type casting for both the list and the string values.

```dart
// Before (INCORRECT - causes type error)
allImagesBase64.addAll(imagesData['propertyImage']!.map((e) => e['image']!).toList());

// After (CORRECT - with explicit casting)
allImagesBase64.addAll(
  (imagesData['propertyImage'] as List).map((e) => (e['image'] as String)).toList()
);
```

**Additional Enhancement**: Improved code readability by formatting the casting operations on multiple lines for better maintainability.

---

These fixes resolve all "Null check operator used on a null value" and type casting errors that were occurring during property publication.
