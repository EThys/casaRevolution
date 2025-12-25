# Debugging Guide - Property Creation Errors

## Quick Diagnostic Checklist

When you encounter an error during property creation, follow this checklist:

### 1. Check Console Logs

Look for these key log messages in order:

```
🎯 DEBUT _handleCreatePropertyPost
✅ Validation réussie, début du chargement...
🖼️ Début de la préparation des images...
📸 Traitement catégorie [category]: [count] images
✅ Image [name] convertie ([size] caractères)
🎯 Catégorie [category]: [count] images converties
🖼️ Préparation terminée. Total des données: [count] catégories
👤 PostBy: [username]
📦 PAYLOAD STRUCTURE:
📡 Réponse API: [status] - [errorMsg]
```

### 2. Identify Error Location

Based on where the logs stop, you can identify the problem:

| Last Log Seen | Problem Area | What to Check |
|--------------|--------------|---------------|
| `🎯 DEBUT _handleCreatePropertyPost` | Validation | Check validation errors in UI |
| `🖼️ Début de la préparation des images` | Image preparation | Check image file paths and permissions |
| `📸 Traitement catégorie` | Image conversion | Check specific image file integrity |
| `👤 PostBy` | User data | Check GetStorage for user data |
| `📦 PAYLOAD STRUCTURE` | Payload creation | Check all required fields |
| `📡 Réponse API` | API call | Check network and API response |

### 3. Common Error Messages

#### "Null check operator used on a null value"

**Possible Causes:**
1. Accessing a map key that doesn't exist (e.g., `e['base64']` instead of `e['image']`)
2. Using an undefined variable (e.g., `fullname` not defined)
3. Accessing a null object with `!` operator

**How to Debug:**
1. Check the stack trace for the exact line
2. Look for `!` operators on that line
3. Verify all variables are defined before use
4. Check map key names match between creation and access

**Example Fix:**
```dart
// ❌ Wrong
final value = map['key']!;  // Crashes if key doesn't exist

// ✅ Correct
final value = map['key'] ?? 'default';  // Safe with fallback
```

#### "Pas de connexion internet"

**Possible Causes:**
1. Device is offline
2. Network permissions not granted
3. Firewall blocking connection

**How to Debug:**
1. Check device network settings
2. Verify `AndroidManifest.xml` has internet permission
3. Test with other network-dependent features

#### "Une erreur est survenue lors de la publication"

**Possible Causes:**
1. API returned an error
2. Invalid payload structure
3. Missing required fields
4. Server-side validation failed

**How to Debug:**
1. Check `📡 Réponse API data:` log for error details
2. Verify payload structure matches API requirements
3. Check all required fields are present and valid
4. Review API documentation for field constraints

### 4. Image-Related Errors

#### Images not converting

**Symptoms:**
```
❌ Fichier introuvable: [path]
```

**Possible Causes:**
1. File was deleted after selection
2. Incorrect file path
3. Permission issues

**How to Debug:**
1. Check if file exists at the logged path
2. Verify app has storage permissions
3. Check if image was properly selected

#### Images too large

**Symptoms:**
- App crashes during conversion
- Out of memory errors

**Solutions:**
1. Implement image compression before base64 conversion
2. Limit number of images
3. Reduce image quality/size

### 5. Validation Errors

#### Form not submitting

**Symptoms:**
- Button click doesn't trigger submission
- Stays on current step

**Possible Causes:**
1. Validation failing on one or more steps
2. Required fields empty
3. Field errors present

**How to Debug:**
1. Check `_stepValidations` map
2. Look for error messages in UI
3. Review `_stepErrorMessages` for details
4. Check console for validation logs

### 6. API Response Errors

#### Understanding API Response Structure

The API can return different response structures:

```dart
// Success with property data
{
  "status": true,
  "data": {
    "properties": { ... }  // or "data" or direct property object
  }
}

// Success with message only
{
  "status": true,
  "data": {
    "message": "Property created successfully"
  }
}

// Error response
{
  "status": false,
  "errorMsg": "Error message",
  "data": {
    "detailMessage": "Detailed error",
    "message": "Error message",
    "error": "Error description"
  }
}
```

**How to Debug:**
1. Check `📡 Réponse API data type:` to see response structure
2. Look for error messages in `data.detailMessage`, `data.message`, or `data.error`
3. Verify the response matches expected structure

---

## Step-by-Step Debugging Process

### Step 1: Enable Detailed Logging

The code now includes comprehensive logging. Make sure to:
1. Run in debug mode
2. Watch the console output
3. Note the last successful log message

### Step 2: Reproduce the Error

1. Try to create the property again
2. Note exactly when the error occurs
3. Capture the full error message and stack trace

### Step 3: Analyze the Logs

Look for patterns:

```
✅ = Success
❌ = Error
⚠️ = Warning
📦 = Data structure
🔄 = Processing
📡 = Network/API
```

### Step 4: Check Payload Structure

Before the API call, you should see:

```
📦 PAYLOAD STRUCTURE:
  - Property fields: [title, description, price, ...]
  - Address fields: [address, cityId, communeId, ...]
  - GeoZone: {lat: X, lng: Y}
  - TypeProperty: {propertyTypeId: N}
  - Features count: N
  - Images main: N
  - Images room: N
  - Images living: N
  - Images kitchen: N
```

**Verify:**
- All expected fields are present
- Image counts match what you selected
- No null or undefined values

### Step 5: Check API Response

After the API call:

```
📡 Réponse API: true/false - error message
📡 Réponse API data: {...}
📡 Réponse API data type: _Map<String, dynamic>
```

**Verify:**
- Status is true for success
- Data structure matches expected format
- Error message is clear if status is false

### Step 6: Identify the Fix

Based on your findings:

1. **Validation Error**: Fix the form fields
2. **Image Error**: Check image files and permissions
3. **Payload Error**: Verify all required fields
4. **API Error**: Check network and server status
5. **Code Error**: Review the stack trace and fix the bug

---

## Common Fixes

### Fix 1: Missing Required Fields

```dart
// Check all required fields have values
final title = _titleController.text.trim();
if (title.isEmpty) {
  print("❌ Title is required");
  return;
}
```

### Fix 2: Null Safety Issues

```dart
// Use null-aware operators
final value = object?.property ?? defaultValue;

// Instead of
final value = object!.property;  // Can crash
```

### Fix 3: Map Key Mismatches

```dart
// Ensure keys match
imageList.add({"image": base64String});  // Creation

// Later access
final img = imageList[0]["image"];  // Must use same key
```

### Fix 4: Undefined Variables

```dart
// Define before use
final String fullname = userData?['fullname'] ?? "Default";

// Then use
"postBy": fullname
```

---

## Testing Checklist

Before deploying fixes:

- [ ] Test with all property types
- [ ] Test with minimum required fields
- [ ] Test with all optional fields
- [ ] Test with no images
- [ ] Test with maximum images
- [ ] Test with poor network
- [ ] Test with no network
- [ ] Test validation errors
- [ ] Test successful creation
- [ ] Verify error messages are clear

---

## Prevention Tips

1. **Always use null-safe operators** (`?.`, `??`) instead of force unwrap (`!`)
2. **Log payload structure** before API calls
3. **Validate early** - check fields before building payload
4. **Use constants** for map keys to avoid typos
5. **Add unit tests** for payload construction
6. **Document expected structures** in code comments
7. **Handle all error cases** with clear messages

---

## Getting Help

If you're still stuck:

1. **Collect Information:**
   - Full console logs
   - Error message and stack trace
   - Steps to reproduce
   - Property type being created
   - Device/emulator info

2. **Check Documentation:**
   - `property_payload_documentation.md` - Payload structures
   - `property_quick_reference.md` - Quick lookup
   - `bug_fixes_summary.md` - Known issues and fixes

3. **Review Code:**
   - `CreatePropertyPostPage.dart` - Main creation logic
   - `PropertyCtrl.dart` - API communication
   - Error handling in both files

4. **Common Solutions:**
   - Clear app cache and restart
   - Check API server status
   - Verify network connectivity
   - Update dependencies
   - Clean and rebuild project
