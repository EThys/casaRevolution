/// Arguments pour préremplir [LoginScreen] après une inscription (secours).
class LoginRouteArgs {
  const LoginRouteArgs({
    required this.contact,
    required this.isPhone,
    this.countryCode = '+243',
  });

  final String contact;
  final String countryCode;
  final bool isPhone;
}
