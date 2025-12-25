# 🔧 Bug Fix #4 - Structure du Payload API

## Date: 2025-12-25

---

## 🐛 Problème Identifié

### Erreur du Serveur
```
JSON parse error: Cannot deserialize value of type `java.lang.String` 
from Object value (token `JsonToken.START_OBJECT`)
```

### Traduction
Le serveur backend (Java) **attendait une String** mais **recevait un Object** (Map/JSON imbriqué).

---

## 🔍 Analyse Détaillée

### Structure Envoyée (INCORRECTE)
```json
{
  "property": {
    "title": "...",
    "price": 100,
    ...
  },
  "address": {              // ← OBJET IMBRIQUÉ
    "address": "...",
    "cityId": "",
    ...
  },
  "geoZone": {              // ← OBJET IMBRIQUÉ
    "lat": 0.1,
    "lng": 0.1
  },
  "typeProperty": {         // ← OBJET IMBRIQUÉ
    "propertyTypeId": 2
  },
  "images": {               // ← OBJET IMBRIQUÉ
    "main": [...],
    "room": [...],
    ...
  }
}
```

### Structure Attendue par l'API (CORRECTE)
```json
{
  "title": "...",
  "description": "...",
  "price": 100,
  "surface": 50.5,
  "rooms": 3,
  "bedrooms": 2,
  "kitchen": 1,
  "livingRoom": 1,
  "bathroom": 1,
  "floor": 2,
  "address": "123 Rue Example",    // ← STRING SIMPLE
  "guarantee": "500",
  "communeValue": "Gombe",
  "quartierValue": "Matonge",
  "cityValue": "Kinshasa",
  "countryValue": "RDC",
  "cityId": 1,                     // ← INTEGER au niveau racine
  "communeId": 5,
  "quartierId": 12,
  "electric": 24,
  "water": 24,
  "postalCode": "243",
  "quartier": "Matonge",
  "sold": false,
  "transactionType": "location",
  "propertyTypeId": 2,             // ← INTEGER au niveau racine
  "userId": 123,
  "latitude": -4.3276,             // ← DOUBLE au niveau racine
  "longitude": 15.3136,
  "features": [
    {"featureId": 1},
    {"featureId": 6}
  ],
  "propertyImage": [               // ← ARRAY au niveau racine
    {"image": "base64..."}
  ],
  "propertyImageRoom": [...],
  "propertyImageLivingRoom": [...],
  "propertyImageKitchen": [...]
}
```

---

## ✅ Solution Appliquée

### Changements Majeurs

1. **Suppression de l'objet "property"**
   - Tous les champs sont maintenant au niveau racine

2. **Suppression de l'objet "address"**
   - `address` est maintenant une string simple
   - `cityId`, `communeId`, `quartierId` sont au niveau racine

3. **Suppression de l'objet "geoZone"**
   - `latitude` et `longitude` sont au niveau racine

4. **Suppression de l'objet "typeProperty"**
   - `propertyTypeId` est au niveau racine

5. **Suppression de l'objet "images"**
   - Les arrays d'images sont directement au niveau racine
   - Noms: `propertyImage`, `propertyImageRoom`, etc.

6. **Changement des IDs vides**
   - Avant: `""` (string vide)
   - Après: `0` (integer)
   - Raison: L'API attend des integers, pas des strings

---

## 📝 Code Avant/Après

### ❌ AVANT (Structure Imbriquée)
```dart
final propertyData = {
  "property": {
    "title": title,
    "price": price,
    ...
  },
  "address": {
    "address": address,
    "cityId": _isKinshasaSelected ? _selectedCity!.cityId! : "",
    ...
  },
  "geoZone": {
    "lat": _selectedLocation?.latitude ?? 0.1,
    "lng": _selectedLocation?.longitude ?? 0.1,
  },
  "typeProperty": {
    "propertyTypeId": _selectedPropertyTypeId ?? 2,
  },
  "images": {
    "main": [...],
    "room": [...],
    ...
  }
};
```

### ✅ APRÈS (Structure Plate)
```dart
final propertyData = {
  "title": title,
  "description": description,
  "price": price,
  "surface": double.tryParse(_areaController.text) ?? 0.1,
  "rooms": _calculateTotalRooms(),
  "bedrooms": int.tryParse(_bedroomsController.text) ?? 1,
  "kitchen": int.tryParse(_kitchensController.text) ?? 1,
  "livingRoom": int.tryParse(_livingRoomsController.text) ?? 1,
  "bathroom": int.tryParse(_bathroomsController.text) ?? 1,
  "floor": int.tryParse(_floorController.text) ?? 1,
  "electric": electric,
  "water": _selectedWater != null ? int.tryParse(_selectedWater!) : 0,
  "guarantee": _guaranteeController.text.trim().isNotEmpty ? _guaranteeController.text.trim() : "0",
  "sold": false,
  "transactionType": _isForRent ? "location" : "vente",
  "address": address,  // ← String simple
  "cityId": _isKinshasaSelected && _selectedCity?.cityId != null ? _selectedCity!.cityId! : 0,  // ← Integer
  "communeId": _isKinshasaSelected && _selectedCommune?.communeId != null ? _selectedCommune!.communeId! : 0,
  "quartierId": _isKinshasaSelected && _selectedQuartier?.quartierId != null ? _selectedQuartier!.quartierId! : 0,
  "cityValue": _isKinshasaSelected ? (_selectedCity?.name ?? 'Kinshasa') : (...),
  "communeValue": _isKinshasaSelected ? (_selectedCommune?.name ?? "") : (...),
  "quartierValue": quartierValue,
  "postalCode": _postalCodeController.text.trim().isNotEmpty ? _postalCodeController.text.trim() : "243",
  "countryValue": "RDC",
  "quartier": quartierValue,
  "latitude": _selectedLocation?.latitude ?? 0.1,  // ← Au niveau racine
  "longitude": _selectedLocation?.longitude ?? 0.1,
  "propertyTypeId": _selectedPropertyTypeId ?? 2,  // ← Au niveau racine
  "userId": uId,
  "features": _selectedFeatureIds.map((id) => {"featureId": id}).toList(),
  "propertyImage": (imagesData is Map) ? (imagesData["propertyImage"] ?? []) : [],  // ← Au niveau racine
  "propertyImageRoom": (imagesData is Map) ? (imagesData["propertyImageRoom"] ?? []) : [],
  "propertyImageLivingRoom": (imagesData is Map) ? (imagesData["propertyImageLivingRoom"] ?? []) : [],
  "propertyImageKitchen": (imagesData is Map) ? (imagesData["propertyImageKitchen"] ?? []) : []
};
```

---

## 🎯 Points Clés

### Types de Données Corrigés

| Champ | Type Avant | Type Après | Raison |
|-------|------------|------------|--------|
| `cityId` | `String ("")` | `int (0)` | API attend un integer |
| `communeId` | `String ("")` | `int (0)` | API attend un integer |
| `quartierId` | `String ("")` | `int (0)` | API attend un integer |
| `address` | `Object {...}` | `String` | API attend une string |
| `latitude` | Dans `geoZone` | Au niveau racine | Structure plate |
| `longitude` | Dans `geoZone` | Au niveau racine | Structure plate |
| `propertyTypeId` | Dans `typeProperty` | Au niveau racine | Structure plate |

### Champs Ajoutés
- `quartier`: Doublon de `quartierValue` (requis par l'API)
- `userId`: Maintenant au niveau racine (pas dans "property")

### Champs Supprimés
- `postBy`: N'était pas dans le payload initial fourni
- `available`: N'était pas dans le payload initial fourni

---

## 📊 Impact

### Avant la Correction
```
❌ API Error - Status: false
❌ Message: Internal server error
❌ Detail: JSON parse error: Cannot deserialize value of type `java.lang.String` from Object value
```

### Après la Correction (Attendu)
```
✅ API Response - Status: true
✅ Propriété créée avec succès
✅ Redirection vers la page d'accueil
```

---

## 🧪 Tests Recommandés

1. **Test avec Kinshasa**
   - Sélectionner Ville, Commune, Quartier
   - Vérifier que les IDs sont des integers (pas 0)

2. **Test avec Autre Ville**
   - Entrer ville/commune/quartier manuellement
   - Vérifier que les IDs sont 0
   - Vérifier que les Values sont remplis

3. **Test avec Images**
   - Ajouter images dans différentes catégories
   - Vérifier que les arrays sont au bon niveau

4. **Test avec Features**
   - Sélectionner plusieurs features
   - Vérifier le format `[{"featureId": 1}, ...]`

---

## 💡 Leçons Apprises

### Pourquoi Cette Erreur?

1. **Mauvaise Compréhension du Contrat API**
   - Le payload initial fourni montrait une structure plate
   - Le code utilisait une structure imbriquée

2. **Erreur de Désérialisation Java**
   - Le backend Java utilise Jackson ou similaire
   - Il attend des types spécifiques (String, Integer, etc.)
   - Recevoir un Object au lieu d'une String cause l'erreur

3. **Importance de la Documentation API**
   - Toujours se référer au payload exact attendu
   - Tester avec Postman/Insomnia d'abord
   - Valider la structure avant d'implémenter

### Comment Éviter à l'Avenir?

1. **Valider le Payload**
   - Comparer avec la documentation API
   - Tester manuellement avec curl/Postman
   - Logger le JSON exact envoyé

2. **Typage Strict**
   - Utiliser des modèles de données
   - Valider les types avant l'envoi
   - Utiliser des serializers

3. **Tests d'Intégration**
   - Tester chaque endpoint
   - Vérifier les réponses d'erreur
   - Documenter les structures attendues

---

## 📚 Documentation Mise à Jour

Les fichiers suivants ont été mis à jour:
- ✅ `property_payload_documentation.md` - Structure corrigée
- ✅ `bug_fixes_summary.md` - Bug #4 ajouté
- ⏳ `FINAL_SUMMARY.md` - À mettre à jour

---

## 🚀 Prochaines Étapes

1. **Tester la création** avec la nouvelle structure
2. **Vérifier les logs** pour confirmer la structure plate
3. **Valider la réponse** de l'API
4. **Documenter** tout problème restant

---

**Ce bug était critique car il empêchait complètement la création de propriétés!**

La structure est maintenant **exactement** celle attendue par l'API backend. ✅
