# Guide de Création du Keystore pour la Signature

## Pourquoi un Keystore ?

Un keystore est nécessaire pour signer votre application Android en mode release. C'est obligatoire pour publier sur le Play Store.

## Option 1 : Générer un APK sans signature (pour test uniquement)

Si vous voulez juste tester l'APK sans le publier, le build.gradle a été modifié pour permettre la génération sans keystore.

**⚠️ ATTENTION** : Les APK non signés ne peuvent pas être installés sur les appareils. Pour installer, vous devez créer un keystore.

## Option 2 : Créer un Keystore (Recommandé)

### Étape 1 : Créer le keystore

Ouvrez un terminal dans le dossier `android` et exécutez :

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Vous devrez répondre à plusieurs questions :
- **Mot de passe du keystore** : Choisissez un mot de passe fort (notez-le !)
- **Nom et prénom** : Votre nom
- **Unité organisationnelle** : Votre organisation (ou votre nom)
- **Organisation** : Votre organisation
- **Ville** : Votre ville
- **État/Province** : Votre état/province
- **Code pays** : Votre code pays (ex: FR, US, CD)

### Étape 2 : Créer le fichier key.properties

Créez un fichier `android/key.properties` avec ce contenu :

```properties
storePassword=votre_mot_de_passe_keystore
keyPassword=votre_mot_de_passe_key
keyAlias=upload
storeFile=upload-keystore.jks
```

**⚠️ IMPORTANT** :
- Remplacez `votre_mot_de_passe_keystore` par le mot de passe que vous avez utilisé lors de la création du keystore
- Remplacez `votre_mot_de_passe_key` par le même mot de passe (ou un autre si vous en avez utilisé un différent)
- Le fichier `key.properties` contient des informations sensibles, **NE LE COMMITEZ PAS** dans Git !

### Étape 3 : Ajouter key.properties au .gitignore

Assurez-vous que `android/key.properties` et `android/upload-keystore.jks` sont dans votre `.gitignore` :

```gitignore
# Android
android/key.properties
android/upload-keystore.jks
android/*.jks
```

### Étape 4 : Générer l'APK signé

Maintenant vous pouvez générer l'APK signé :

```bash
flutter build apk --split-per-abi --release
```

## Option 3 : Utiliser un Keystore existant

Si vous avez déjà un keystore :

1. Copiez votre fichier `.jks` ou `.keystore` dans le dossier `android/`
2. Créez `android/key.properties` avec les bonnes informations
3. Générez l'APK

## Sécurité

- **Gardez votre keystore en sécurité** : Si vous le perdez, vous ne pourrez plus mettre à jour votre app sur le Play Store
- **Ne partagez jamais votre keystore** : C'est comme une clé de signature
- **Faites des sauvegardes** : Sauvegardez votre keystore dans un endroit sûr

## Dépannage

### Erreur "keystore was tampered with, or password was incorrect"
- Vérifiez que les mots de passe dans `key.properties` sont corrects
- Vérifiez que le chemin vers le keystore est correct

### Erreur "storeFile not found"
- Vérifiez que le chemin dans `storeFile` est relatif au dossier `android/`
- Exemple : Si le keystore est dans `android/`, utilisez `upload-keystore.jks`
- Exemple : Si le keystore est dans `android/app/`, utilisez `app/upload-keystore.jks`


