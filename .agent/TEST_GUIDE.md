# 🧪 Guide de Test Rapide - Création de Propriété

## Avant de Tester

### Vérifications Préalables
- [ ] L'application est compilée avec les dernières modifications
- [ ] Vous êtes connecté avec un compte utilisateur
- [ ] Vous avez des images de test prêtes
- [ ] Vous avez une connexion internet active

---

## Test 1: Propriété Standard (Recommandé en premier)

### Configuration
- **Type**: Appartement
- **Transaction**: Location
- **Images**: 
  - 2 images principales
  - 2 images salon
  - 0 images chambre
  - 0 images cuisine

### Étapes
1. Ouvrir la page de création
2. Sélectionner "Appartement"
3. Remplir tous les champs obligatoires
4. Ajouter 2 images dans "Images principales"
5. Ajouter 2 images dans "Salon"
6. Cliquer sur "Publier"

### Logs Attendus
```
🎯 DEBUT _handleCreatePropertyPost
✅ Validation réussie
🖼️ Début de la préparation des images...
🎯 Catégorie propertyImage: 2 images converties
🎯 Catégorie propertyImageLivingRoom: 2 images converties
👤 PostBy: [Votre nom]
📦 PAYLOAD STRUCTURE:
  - Images main: 2
  - Images living: 2
📡 Réponse API: true
✅ Propriété ajoutée avec succès
```

### Résultat Attendu
✅ Redirection vers la page d'accueil
✅ Message de succès affiché
✅ Propriété visible dans "Mes annonces"

---

## Test 2: Bureau

### Configuration
- **Type**: Bureau
- **Images**: 
  - 3 images principales
  - 1 image salle de réunion

### Étapes
1. Sélectionner "Bureau"
2. Remplir les champs spécifiques (nombre de salles de réunion, équipé, etc.)
3. Ajouter les images
4. Publier

### Logs Attendus
```
💼 Création de Bureau
📦 PAYLOAD STRUCTURE:
  - Images: 4 total
📡 Réponse API: true
```

---

## Test 3: Salle de Fête

### Configuration
- **Type**: Festive
- **Images**: 5 images (toutes catégories confondues)

### Étapes
1. Sélectionner "Salle de Fête"
2. Remplir capacité, usage, etc.
3. Ajouter 5 images
4. Publier

### Logs Attendus
```
🎉 Création de Salle de Fête
images: [base64_1, base64_2, base64_3, base64_4, base64_5]
📡 Réponse API: true
```

---

## Scénarios d'Erreur à Tester

### Scénario 1: Sans Internet
1. Désactiver le WiFi/données
2. Essayer de publier

**Attendu**: 
```
❌ Pas de connexion internet
```

### Scénario 2: Champs Manquants
1. Ne pas remplir le titre
2. Essayer de publier

**Attendu**:
- Reste sur l'étape avec erreur
- Message d'erreur sur le champ titre

### Scénario 3: Sans Images
1. Remplir tous les champs
2. Ne pas ajouter d'images
3. Essayer de publier

**Attendu**:
- Erreur de validation
- Message demandant d'ajouter au moins 1 image

---

## Checklist de Vérification

### Après Chaque Test Réussi
- [ ] La propriété apparaît dans "Mes annonces"
- [ ] Les images sont bien affichées
- [ ] Toutes les informations sont correctes
- [ ] Pas d'erreur dans les logs

### Si Erreur
1. **Copier le message d'erreur complet**
2. **Copier le stack trace**
3. **Noter l'étape où l'erreur s'est produite**
4. **Vérifier les logs pour identifier le problème**

---

## Logs de Débogage

### Logs à Surveiller

#### ✅ Logs de Succès
```
✅ Validation réussie
✅ Image [nom] convertie
🎯 Catégorie [nom]: N images converties
👤 PostBy: [nom]
📡 Réponse API: true
✅ Propriété ajoutée avec succès
```

#### ❌ Logs d'Erreur
```
❌ Fichier introuvable
❌ Erreur lors de la conversion
❌ API Error - Status: false
❌ EXCEPTION lors de la publication
```

---

## Problèmes Connus (Résolus)

### ✅ "Null check operator used on a null value"
**Statut**: RÉSOLU
**Cause**: 3 bugs différents (clé image, fullname, cast de type)
**Solution**: Tous corrigés

### ✅ "List<dynamic> is not a subtype of Iterable<String>"
**Statut**: RÉSOLU
**Cause**: Pas de cast explicite
**Solution**: Cast ajouté

---

## En Cas de Problème

### Étape 1: Vérifier les Logs
Cherchez le dernier log réussi (✅) avant l'erreur (❌)

### Étape 2: Identifier le Type d'Erreur
- **Validation**: Problème de formulaire
- **Images**: Problème de conversion d'images
- **API**: Problème réseau ou serveur
- **Exception**: Bug dans le code

### Étape 3: Consulter la Documentation
- `debugging_guide.md` - Guide de débogage complet
- `bug_fixes_summary.md` - Bugs connus et solutions
- `property_payload_documentation.md` - Structure des payloads

### Étape 4: Actions Correctives

#### Si erreur de validation:
- Vérifier que tous les champs obligatoires sont remplis
- Vérifier le format des données (nombres, texte, etc.)

#### Si erreur d'images:
- Vérifier que les images existent
- Vérifier les permissions de stockage
- Essayer avec d'autres images

#### Si erreur API:
- Vérifier la connexion internet
- Vérifier que le serveur est accessible
- Consulter les logs de réponse API

#### Si exception:
- Noter le stack trace complet
- Identifier la ligne exacte
- Consulter le code à cette ligne

---

## Commandes Utiles

### Nettoyer le Cache
```bash
flutter clean
flutter pub get
```

### Rebuild l'Application
```bash
flutter run
```

### Voir les Logs en Temps Réel
```bash
flutter logs
```

---

## Résultats Attendus

### Tous les Tests Passent ✅
- Création réussie pour tous les types
- Images correctement uploadées
- Données correctement sauvegardées
- Redirection fonctionnelle

### Un Test Échoue ❌
- Logs détaillés disponibles
- Stack trace complet
- Message d'erreur clair
- Documentation pour résoudre

---

## Rapport de Test

Après les tests, notez:

| Type de Propriété | Statut | Images | Commentaires |
|-------------------|--------|--------|--------------|
| Studio | ⬜ | 0/0 | |
| Appartement | ⬜ | 0/0 | |
| Maison | ⬜ | 0/0 | |
| Bureau | ⬜ | 0/0 | |
| Salle de Fête | ⬜ | 0/0 | |
| Salle Funéraire | ⬜ | 0/0 | |

Légende:
- ✅ = Succès
- ❌ = Échec
- ⬜ = Non testé

---

## Contact/Support

Si vous rencontrez un problème non documenté:

1. Collectez toutes les informations (logs, stack trace, étapes)
2. Vérifiez la documentation dans `.agent/`
3. Consultez le `debugging_guide.md`
4. Si le problème persiste, documentez-le pour investigation

---

**Bonne chance avec les tests!** 🚀
