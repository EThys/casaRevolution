// Future<void> _handleRegister() async {
//   // Marquer tous les champs comme touchés pour afficher les erreurs
//   setState(() {
//     _firstNameTouched = true;
//     _lastNameTouched = true;
//     _phoneTouched = true;
//     _emailTouched = true;
//     _cityTouched = true;
//     _passwordTouched = true;
//     _autoValidateMode = AutovalidateMode.always;
//   });
//
//   await Future.delayed(Duration(milliseconds: 50));
//
//   // Valider tous les champs
//   final firstNameError = _validateName(_firstNameController.text, 'prénom');
//   final lastNameError = _validateName(_lastNameController.text, 'nom');
//   final phoneError = _validatePhone(_phoneController.text);
//   final emailError = _validateEmail(_emailController.text);
//   final cityError = _validateCity(_cityController.text);
//   final passwordError = _validatePassword(_passwordController.text);
//
//   if (firstNameError != null || lastNameError != null || phoneError != null ||
//       emailError != null || cityError != null || passwordError != null) {
//     FancyNotification.show(context, "Veuillez corriger les erreurs ci-dessus");
//     return;
//   }
//
//   if (_selectedAccountType == null) {
//     _showSnackbar("Veuillez sélectionner un type de compte", isError: true);
//     return;
//   }
//
//   if (!_acceptConditions) {
//     _showSnackbar("Veuillez accepter les conditions d'utilisation", isError: true);
//     return;
//   }
//
//   if (!mounted || _isLoading) return;
//   setState(() => _isLoading = true);
//
//   FocusScope.of(context).unfocus();
//
//   final isConnected = await NetworkUtils.checkInternetConnectivity();
//   if (!isConnected) {
//     FancyNotification.show(context, "Pas de connexion internet");
//     setState(() => _isLoading = false);
//     return;
//   }
//
//   try {
//     final accountType = _accountTypes[_selectedAccountType]!;
//
//     // Préparer le numéro de téléphone avec l'indicatif pays
//     String phoneNumber = _phoneController.text.trim();
//     // Nettoyer le numéro (supprimer les espaces, tirets, etc.)
//     final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
//
//     // Formater le numéro avec l'indicatif pays sélectionné
//     String formattedPhone = '$_selectedCountryCode$cleanedPhone';
//
//     // Structure de base pour l'utilisateur
//     final userData = {
//       "phone": formattedPhone,
//       "password": _passwordController.text,
//       "typeAccountId": accountType['value'],
//       "email": _emailController.text.isNotEmpty ? _emailController.text : "",
//       "cityId": 1, // À adapter selon votre système de villes
//     };
//
//     Map<String, dynamic> payload;
//
//     // Construction du payload selon le type de compte
//     switch (_selectedAccountType) {
//       case 'Bailleur':
//         payload = {
//           "user": userData,
//           "bailleur": {
//             "lastName": _lastNameController.text,
//             "firstName": _firstNameController.text,
//             "address": _cityController.text,
//             "images": "",
//             "cardFront": "",
//             "cardBack": "",
//             "parrainId": 0,
//             "typeCardId": 1,
//             "numberCard": "",
//             "note": "Nouveau bailleur"
//           }
//         };
//         break;
//
//       case 'Locataire':
//         payload = {
//           "user": userData,
//           "locataire": {
//             "lastName": _lastNameController.text,
//             "firstName": _firstNameController.text,
//             "address": _cityController.text,
//             "images": "",
//             "cardFront": "",
//             "cardBack": "",
//             "typeCardId": 1,
//             "numberCard": "",
//           }
//         };
//         break;
//
//       case 'Commissionnaire':
//         payload = {
//           "user": userData,
//           "commissionnaire": {
//             "lastName": _lastNameController.text,
//             "firstName": _firstNameController.text,
//             "address": _cityController.text,
//             "images": "",
//             "cardFront": "",
//             "cardBack": "",
//             "typeCardId": 1,
//             "numberCard": "",
//           }
//         };
//         break;
//
//       default:
//         payload = {"user": userData};
//     }
//
//     HttpResponse response;
//
//     // Redirection vers le contrôleur approprié selon le type de compte
//     switch (_selectedAccountType) {
//       case 'Bailleur':
//         final ctrl = context.read<RegisterBailleurCtrl>();
//         response = await ctrl.registerBailleur(
//           payload,
//           typeCompteId: accountType['value'],
//         );
//         break;
//       case 'Locataire':
//         final ctrl = context.read<RegisterLocataireCtrl>();
//         response = await ctrl.registerLocataire(
//           payload,
//           typeCompteId: accountType['value'],
//         );
//         break;
//       case 'Commissionnaire':
//         final ctrl = context.read<RegisterCommissionnaireCtrl>();
//         response = await ctrl.registerCommissionnaire(
//           payload,
//           typeCompteId: accountType['value'],
//         );
//         break;
//       default:
//         final ctrl = context.read<AuthentificationCtrl>();
//         response = await ctrl.register(payload, url: Endpoints.register);
//     }
//
//     if (!mounted) return;
//
//     if (response.status == true) {
//       FancyNotification.show(context, "Inscription réussie!", isError: false);
//       await Future.delayed(const Duration(milliseconds: 1500));
//
//       if (mounted) {
//         Navigator.pushNamedAndRemoveUntil(
//           context,
//           Routes.loginRoute,
//               (route) => false,
//         );
//       }
//     } else {
//       String errorMessage = response.errorMsg ?? "Erreur lors de l'inscription";
//       FancyNotification.show(context, errorMessage);
//     }
//   } catch (e) {
//     FancyNotification.show(context, "Erreur technique lors de l'inscription");
//     print("Register error: $e");
//   } finally {
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }


// Future<void> _handleLogin() async {
//   // Marquer tous les champs comme touchés pour afficher les erreurs
//   setState(() {
//     _emailTouched = true;
//     _passwordTouched = true;
//     _autoValidateMode = AutovalidateMode.always;
//   });
//
//   await Future.delayed(Duration(milliseconds: 50));
//
//   // Valider les champs
//   final emailError = _validateEmail(_emailController.text);
//   final passwordError = _validatePassword(_passwordController.text);
//
//   if (emailError != null || passwordError != null) {
//     FancyNotification.show(context, "Veuillez corriger les erreurs ci-dessus");
//     return;
//   }
//
//   // VÉRIFICATION DES CONDITIONS AJOUTÉE ICI
//   if (!_acceptConditions) {
//     FancyNotification.show(context, "Veuillez accepter les conditions d'utilisation", isError: true);
//     return;
//   }
//
//   if (!mounted || _isLoading) return;
//   setState(() => _isLoading = true);
//
//   FocusScope.of(context).unfocus();
//
//   final isConnected = await NetworkUtils.checkInternetConnectivity();
//   if (!isConnected) {
//     FancyNotification.show(context, "Pas de connexion internet");
//     setState(() => _isLoading = false);
//     return;
//   }
//
//   try {
//     // Préparer l'identifiant en fonction du type (email ou téléphone)
//     String identifiant = _emailController.text.trim();
//
//     // Si c'est un numéro de téléphone, ajouter l'indicatif pays si nécessaire
//     if (_isPhoneInput && !identifiant.startsWith('+')) {
//       // Nettoyer le numéro (supprimer les espaces, tirets, etc.)
//       final cleanedPhone = identifiant.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
//
//       // Si le numéro commence par 0, le remplacer par l'indicatif
//       if (cleanedPhone.startsWith('0')) {
//         final countryCode = _selectedCountryCode.replaceAll('+', '');
//         identifiant = '+$countryCode${cleanedPhone.substring(1)}';
//       } else {
//         // Sinon, ajouter simplement l'indicatif
//         identifiant = '$_selectedCountryCode$cleanedPhone';
//       }
//     }
//
//     final userData = {
//       "identifiant": identifiant,
//       "password": _passwordController.text.trim(),
//     };
//
//     final ctrl = context.read<AuthentificationCtrl>();
//     final res = await ctrl.login(userData);
//
//     if (!mounted) return;
//     String message = res.data['message']?.toString() ?? '';
//     bool isSuccess = message.toLowerCase().contains('réussie');
//
//     if (isSuccess) {
//       await Future.delayed(const Duration(milliseconds: 500));
//
//       if (mounted) {
//         Navigator.pushNamedAndRemoveUntil(
//           context,
//           Routes.bottomPageRoute,
//               (route) => false,
//         );
//       }
//     } else {
//       String errorMessage = getErrorMessage(res.data['detailMessage']);
//       FancyNotification.show(context, errorMessage);
//     }
//   } catch (e) {
//     FancyNotification.show(context, "Erreur technique");
//     print("Login error: $e");
//   } finally {
//     if (mounted) {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }