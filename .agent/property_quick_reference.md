# Property Creation Quick Reference

## Property Type IDs

| Property Type | ID |
|--------------|-----|
| Studio | 1 |
| Apartments | 2 |
| Houses | 3 |
| Bureau | 4 |
| Hotels | 5 |
| Vacances | 6 |

## Feature IDs

| Feature | ID |
|---------|-----|
| WiFi | 1 |
| Climatisation | 2 |
| Chauffage | 3 |
| Cuisine équipée | 4 |
| Lave-linge | 5 |
| Parking | 6 |
| Ascenseur | 7 |
| Piscine | 8 |
| Jardin | 9 |
| Terrasse | 10 |
| Gym | 11 |
| Sécurité | 12 |
| Animaux acceptés | 13 |

## Transaction Types

- **location**: Rental property
- **vente**: Property for sale

## Electric/Water Values

Values represent hours of availability (0-24):
- **0**: Not available
- **12**: Available 12 hours per day
- **24**: Available 24/7

## Image Categories

### Standard Properties
- **propertyImage**: Main property images
- **propertyImageRoom**: Bedroom images
- **propertyImageLivingRoom**: Living room images
- **propertyImageKitchen**: Kitchen images

### Bureau
- **propertyImage**: Main office images
- **propertyImageRoom**: Office room images

### Festive/Funeraire
- All images in a single flat array

## API Endpoints

Based on the PropertyController methods:
- **Standard Properties**: `createProperty(propertyData)`
- **Bureau**: `createBureau(bureauData)`
- **Festive**: `createFestive(festiveData)`
- **Funeraire**: `createFuneraire(funeraireData)`

## Common Validation Rules

### Required Fields (All Types)
- title
- description
- price
- address
- At least 1 image

### Standard Properties Additional Requirements
- surface > 0
- bedrooms >= 1
- bathrooms >= 1
- livingRoom >= 1
- kitchen >= 1
- floor >= 1
- Location data (city, commune, quartier)

### Bureau Additional Requirements
- numberPiece > 0

### Festive/Funeraire Additional Requirements
- capacityPeople > 0
- Coordinates (latitude, longitude)

## Default Values

- **postalCode**: "243"
- **countryValue**: "RDC"
- **deviseId**: 1 (for Festive/Funeraire)
- **deviseId**: 0 (for Bureau)
- **sold**: false
- **available**: true
- **isAvailable**: true

## Image Format

All images must be:
- Base64 encoded strings
- Valid image files (JPEG, PNG, etc.)
- Properly converted from File objects

## Error Messages

Common errors and their meanings:
- **"Null check operator used on a null value"**: Fixed - was accessing wrong key in image map
- **"Pas de connexion internet"**: No network connectivity
- **"Une erreur est survenue"**: Generic API error
- Validation errors show specific field requirements
