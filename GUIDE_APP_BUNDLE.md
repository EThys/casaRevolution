# Guide de Génération d'App Bundle pour Play Store

## 🎯 Qu'est-ce qu'un App Bundle ?

Un **App Bundle (.aab)** est le format recommandé par Google Play Store. Il permet :
- ✅ Distribution optimisée par architecture (plus petit que l'APK universel)
- ✅ Téléchargement adapté à chaque appareil
- ✅ Mises à jour plus rapides
- ✅ Réduction de la taille de téléchargement pour les utilisateurs

## 🚀 Génération de l'App Bundle

### Méthode 1 : Script automatique (Windows)

```bash
build_appbundle.bat
```

### Méthode 2 : Script automatique (Linux/Mac)

```bash
chmod +x build_appbundle.sh
./build_appbundle.sh
```

### Méthode 3 : Commande manuelle

```bash
# 1. Nettoyer (optionnel mais recommandé)
flutter clean

# 2. Récupérer les dépendances
flutter pub get

# 3. Générer l'App Bundle
flutter build appbundle --release
```

## 📦 Emplacement du fichier

L'App Bundle sera généré dans :
```
build/app/outputs/bundle/release/app-release.aab
```

## 📊 Taille attendue

L'App Bundle est généralement **plus petit** qu'un APK universel car :
- Google Play génère des APK optimisés par architecture à partir du bundle
- Les utilisateurs téléchargent uniquement ce dont ils ont besoin
- Taille typique : **30-50 MB** (selon votre app)

## 📤 Upload sur Google Play Console

1. Connectez-vous à [Google Play Console](https://play.google.com/console)
2. Sélectionnez votre application
3. Allez dans **Production** (ou **Internal testing**, **Closed testing**, etc.)
4. Cliquez sur **Create new release**
5. Téléversez le fichier `app-release.aab`
6. Remplissez les notes de version
7. Cliquez sur **Review release**

## ✅ Avantages de l'App Bundle vs APK

| Caractéristique | App Bundle (.aab) | APK |
|----------------|-------------------|-----|
| Format recommandé | ✅ Oui | ❌ Non |
| Taille optimisée | ✅ Oui | ❌ Non |
| Distribution adaptée | ✅ Oui | ❌ Non |
| Installation directe | ❌ Non (nécessite Play Store) | ✅ Oui |
| Tests locaux | ❌ Non | ✅ Oui |

## 🔧 Dépannage

### Erreur de signature
Assurez-vous que votre fichier `android/key.properties` est correctement configuré.

### Erreur de build
```bash
# Nettoyer complètement
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter build appbundle --release
```

### Vérifier la signature de l'App Bundle
```bash
# Windows
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab

# Linux/Mac
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

## 📝 Notes importantes

1. **Signature** : L'App Bundle doit être signé avec le même keystore que vos mises à jour précédentes
2. **Première version** : Si c'est votre première version, vous pouvez utiliser n'importe quel keystore
3. **Mises à jour** : Pour les mises à jour, vous DEVEZ utiliser le même keystore que la version précédente
4. **Test local** : Vous ne pouvez pas installer un .aab directement. Pour tester, générez un APK ou utilisez `bundletool`

## 🧪 Tester l'App Bundle localement

Si vous voulez tester l'App Bundle avant de l'uploader :

1. Installez `bundletool` : https://github.com/google/bundletool
2. Générez un APK à partir du bundle :
```bash
bundletool build-apks --bundle=app-release.aab --output=app.apks
bundletool install-apks --apks=app.apks
```

## 📚 Ressources

- [Documentation Flutter - Build App Bundle](https://docs.flutter.dev/deployment/android#building-the-app-bundle)
- [Google Play - App Bundle](https://developer.android.com/guide/app-bundle)
- [Google Play Console](https://play.google.com/console)


