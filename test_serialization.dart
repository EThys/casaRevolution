
import 'dart:convert';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/PropertyImageModel.dart';

void main() {
  // 1. Manually create a PropertyModel with images (simulating a Bureau)
  final image = PropertyImageModel(
    propertyImageId: 101,
    name: "test_image.jpg",
    path: "https://example.com/image.jpg",
  );

  final bureau = PropertyModel(
    propertyId: 1,
    title: "Test Bureau",
    description: "A nice office",
    propertyImage: [image],
    propertyTypeId: 4, // Bureau
  );

  print("Original Model Images: ${bureau.propertyImage?.length}");
  print("Original Image Path: ${bureau.propertyImage?.first.path}");

  // 2. Serialize to JSON (mimicking DatabaseHelper insert)
  final jsonMap = bureau.toJson();
  final jsonString = json.encode(jsonMap);
  print("\nSerialized JSON:");
  print(jsonString);

  // 3. Deserialize back to Model (mimicking DatabaseHelper get)
  final decodedMap = json.decode(jsonString);
  final restoredBureau = PropertyModel.fromJson(decodedMap);

  print("\nRestored Model Images: ${restoredBureau.propertyImage?.length}");
  
  if (restoredBureau.propertyImage != null && restoredBureau.propertyImage!.isNotEmpty) {
      print("Restored Image Path: ${restoredBureau.propertyImage?.first.path}");
  } else {
      print("❌ FAILED: Images lost during roundtrip!");
  }

  // 4. Test "Nested" structure simulation (if API returns differently)
  // This simulates how the API might return data vs how it is saved.
  // Although the issue is about Offline access (DB read), so step 2->3 is the critical one.
}
