# Instructions pour Copier le Keystore Original

## 📋 Étapes à Suivre

### 1. Localiser le Keystore Original

Trouvez le fichier `upload-keystore.jks` dans votre autre projet :
```
VotreAutreProjet/
  └── android/
      └── app/
          └── upload-keystore.jks  ← Ce fichier
```

### 2. Copier le Keystore

#### Option A : Utiliser le script automatique

1. Exécutez : `android/copier_keystore_original.bat`
2. Entrez le chemin complet vers le keystore original
3. Le script copiera et vérifiera l'empreinte

#### Option B : Copie manuelle

1. **Copiez** le fichier `upload-keystore.jks` depuis :
   ```
   VotreAutreProjet/android/app/upload-keystore.jks
   ```

2. **Collez-le** dans :
   ```
   D:\myproject\casaNayo\casaRevolution\android\app\upload-keystore.jks
   ```

3. **Remplacez** le fichier existant si demandé

### 3. Vérifier l'Empreinte

Vérifiez que l'empreinte SHA1 correspond :

```bash
cd android/app
keytool -list -v -keystore upload-keystore.jks -storepass MUZOLA
```

L'empreinte SHA1 doit être : **D2:26:39:78:08:F4:BC:1F:2D:47:E0:1C:BE:C6:59:9D:DA:1C:F7:CA**

### 4. Vérifier key.properties

Assurez-vous que `android/key.properties` contient :

```properties
storePassword=MUZOLA
keyPassword=MUZOLA
keyAlias=upload
storeFile=upload-keystore.jks
```

### 5. Générer l'App Bundle

Une fois le keystore original copié et vérifié :

```bash
flutter build appbundle --release
```

## ✅ Vérification Finale

Après avoir copié le keystore, vérifiez :

1. ✅ Le fichier `android/app/upload-keystore.jks` existe
2. ✅ L'empreinte SHA1 correspond à celle attendue par Play Store
3. ✅ Le fichier `android/key.properties` est correctement configuré
4. ✅ L'App Bundle se génère sans erreur

## 🔍 Si l'Empreinte ne Correspond Toujours Pas

Si après avoir copié le keystore, l'empreinte ne correspond toujours pas :

1. Vérifiez que vous avez copié le **bon fichier** (pas une copie récente)
2. Vérifiez que le keystore n'a pas été modifié
3. Vérifiez dans votre autre projet l'empreinte du keystore :
   ```bash
   keytool -list -v -keystore chemin/vers/autre/projet/android/app/upload-keystore.jks -storepass MUZOLA
   ```

## 📝 Note

Le keystore actuel dans ce projet a été créé récemment (empreinte : `34:5F:1A:DC:8F:1F:DB:D5:E0:20:91:D2:AF:7C:F2:15:19:2E:63:FA`). Vous devez le remplacer par l'original qui a l'empreinte : `D2:26:39:78:08:F4:BC:1F:2D:47:E0:1C:BE:C6:59:9D:DA:1C:F7:CA`.


