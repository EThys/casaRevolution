import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/AuthentificationCtrl.dart';
import '../controllers/PaymentController.dart';
import '../controllers/DeviseController.dart';
import '../utils/casa_payment_log.dart';
import '../utils/FancyNotification.dart';
import '../utils/Routes.dart';
import '../utils/StompService.dart';
import '../utils/StockageKeys.dart';
import '../utils/currency_display.dart';

class PaymentSubscriptionPage extends StatefulWidget {
  /// Si fourni (ex. [SubscriptionHelper]), appelé après succès API ; sinon navigation depuis [Routes.subscriptionPaymentRoute].
  final VoidCallback? onSuccess;

  const PaymentSubscriptionPage({Key? key, this.onSuccess}) : super(key: key);

  @override
  _PaymentSubscriptionPageState createState() => _PaymentSubscriptionPageState();
}

class _PaymentSubscriptionPageState extends State<PaymentSubscriptionPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();

  int _selectedMethod = 0; // 0: Mobile, 1: Card
  bool _isLoading = false;
  /// Après POST Mobile Money : attente confirmation serveur via WebSocket.
  bool _awaitingSubscriptionWs = false;
  /// Après ouverture du checkout carte (retour app → vérif statut premium).
  bool _awaitingCardCheckout = false;
  bool _subscriptionSuccessHandled = false;
  AuthentificationCtrl? _authListener;
  StreamSubscription<Map<String, dynamic>>? _stompSub;
  /// Avant l’initiation du paiement (évite un « succès » si l’utilisateur était déjà premium).
  bool _wasPremiumBeforePaymentIntent = false;
  int _paymentStep = 0; // 0: Idle, 1: Initiating, 2: Processing, 3: Success
  String _detectedNetwork = "Inconnu";
  String _selectedCurrency = "USD"; // Default to USD
  double _subscriptionPriceUsd = 5.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  /// Arrêt du loader + message si aucune notification STOMP (pas de refresh membre : GET indispo).
  Timer? _subscriptionTimeoutTimer;

  /// Mobile Money : validation push + latence réseau.
  /// Attente notification STOMP : Mobile Money et carte (même délai).
  static const Duration _kStompWaitTimeout = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    
    _phoneController.addListener(_detectNetworkFromPhone);
    
    // Fetch latest rates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviseController>().fetchDevises();
      _ensureStompConnected();
      final auth = context.read<AuthentificationCtrl>();
      _authListener = auth;
      auth.addListener(_onAuthPremiumChanged);
      CasaPaymentLog.log(
        'UI/Subscription',
        'Page prête userId=${auth.user.userId} premium=${auth.user.isPremium} stomp=${StompService().IsConnected}',
      );
    });

    _stompSub = StompService().messages.listen((dynamic raw) {
      if (raw is! Map) {
        CasaPaymentLog.log('UI/Subscription', 'STOMP message non-Map ignoré: ${raw.runtimeType}');
        return;
      }
      final map = Map<String, dynamic>.from(raw as Map);
      CasaPaymentLog.log(
        'UI/Subscription',
        '── STOMP (page abonnement) awaitingWs=$_awaitingSubscriptionWs awaitingCard=$_awaitingCardCheckout step=$_paymentStep handled=$_subscriptionSuccessHandled',
      );
      CasaPaymentLog.logJson('UI/Subscription', 'même message JSON (pour corrélation)', map);
      _onStompSubscriptionMessage(map);
    });
  }

  bool get _showPaymentProgress =>
      _isLoading || _awaitingSubscriptionWs;

  /// Bloque le retour système tant qu’un paiement est en cours (annulation explicite).
  bool get _paymentFlowActive =>
      _isLoading ||
      _awaitingSubscriptionWs ||
      _awaitingCardCheckout ||
      (_paymentStep > 0 && _paymentStep < 3);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    CasaPaymentLog.log('UI/Subscription', 'lifecycle → $state (awaitingCard=$_awaitingCardCheckout)');
    if (state != AppLifecycleState.resumed || !_awaitingCardCheckout) return;
    if (!mounted) return;
    CasaPaymentLog.log(
      'UI/Subscription',
      'retour au 1er plan après checkout carte — confiance aux notifs STOMP uniquement (pas de GET membre)',
    );
  }

  /// Extrait l’URL du checkout depuis la réponse API (formes courantes).
  String? _extractCheckoutUrl(dynamic data) {
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    dynamic u = m['url'] ?? m['paymentUrl'] ?? m['checkoutUrl'] ?? m['redirectUrl'];
    if (u is String && u.trim().isNotEmpty) return u.trim();
    final inner = m['data'];
    if (inner is Map) {
      final im = Map<String, dynamic>.from(inner);
      u = im['url'] ?? im['paymentUrl'] ?? im['checkoutUrl'];
      if (u is String && u.trim().isNotEmpty) return u.trim();
    }
    return null;
  }

  /// Ouvre le paiement : navigateur in-app (Custom Tabs / SFSafariViewController), puis navigateur externe en secours.
  Future<bool> _openCheckoutUrl(String urlString) async {
    final uri = Uri.tryParse(urlString.trim());
    CasaPaymentLog.log(
      'UI/Subscription',
      'ouverture checkout host=${uri?.host} scheme=${uri?.scheme} pathLen=${uri?.path.length}',
    );
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      CasaPaymentLog.log('UI/Subscription', 'URL checkout invalide');
      return false;
    }
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        );
        CasaPaymentLog.log('UI/Subscription', 'launchUrl inAppBrowserView → $ok');
        if (ok) return true;
      }
    } catch (e) {
      CasaPaymentLog.log('UI/Subscription', 'launchUrl in-app erreur: $e');
    }
    try {
      final ext = await launchUrl(uri, mode: LaunchMode.externalApplication);
      CasaPaymentLog.log('UI/Subscription', 'launchUrl externalApplication → $ext');
      return ext;
    } catch (e) {
      CasaPaymentLog.log('UI/Subscription', 'launchUrl external erreur: $e');
      return false;
    }
  }

  void _ensureStompConnected() {
    final t = GetStorage().read<String>(StockageKeys.tokenKey) ?? '';
    if (t.isEmpty) {
      CasaPaymentLog.log('UI/Subscription', 'ensureStomp: pas de token, skip');
      return;
    }
    CasaPaymentLog.log(
      'UI/Subscription',
      'ensureStomp: connexion (tokenLen=${t.length}) déjàConnecté=${StompService().IsConnected}',
    );
    StompService().connect(t);
    StompService().logDiagnostics();
    CasaPaymentLog.log(
      'UI/Subscription',
      'Abonnement : suivre les logs [CasaPay][STOMP/QUEUE] pour chaque message /user/queue/notifications.',
    );
  }

  void _cancelSubscriptionWaitTimers() {
    _subscriptionTimeoutTimer?.cancel();
    _subscriptionTimeoutTimer = null;
  }

  void _startSubscriptionWaitTimers({required bool cardCheckout}) {
    _cancelSubscriptionWaitTimers();
    final timeout = _kStompWaitTimeout;
    CasaPaymentLog.log(
      'UI/Subscription',
      'timeout attente STOMP: ${timeout.inSeconds}s (card=$cardCheckout)',
    );

    _subscriptionTimeoutTimer = Timer(timeout, () {
      if (!mounted || _subscriptionSuccessHandled) return;
      if (!_awaitingSubscriptionWs && !_awaitingCardCheckout) return;
      CasaPaymentLog.log(
        'UI/Subscription',
        'timeout ${timeout.inSeconds}s sans confirmation premium → arrêt attente UI',
      );
      _cancelSubscriptionWaitTimers();
      _abortPendingPayment(showSnack: false);
      if (mounted) {
        SnackbarForCasa.warning(
          context,
          'Délai écoulé. Réessayez.',
        );
      }
    });
  }

  /// Même source que [NotificationController] : le backend envoie souvent `user` (premium) comme au login.
  void _onAuthPremiumChanged() {
    if (!mounted || _subscriptionSuccessHandled) return;
    if (!(_awaitingSubscriptionWs || _awaitingCardCheckout)) return;
    final u = _authListener?.user;
    CasaPaymentLog.log(
      'UI/Subscription',
      'listener Auth: isPremium=${u?.isPremium} wasPremiumBefore=$_wasPremiumBeforePaymentIntent',
    );
    if (u?.isPremium == true && !_wasPremiumBeforePaymentIntent) {
      CasaPaymentLog.log('UI/Subscription', '✓ premium détecté via AuthCtrl → confirmation abonnement');
      _handleSubscriptionPaymentConfirmed();
    }
  }

  void _onStompSubscriptionMessage(Map<String, dynamic> data) {
    if (_subscriptionSuccessHandled) {
      CasaPaymentLog.log('UI/Subscription', 'STOMP: succès déjà traité, skip');
      return;
    }

    final tag = (data['tag'] ?? '').toString().toUpperCase();
    if (tag == 'SUBSCRIPTION_CANCEL') {
      final inFlight = _awaitingSubscriptionWs ||
          _awaitingCardCheckout ||
          (_isLoading && _paymentStep >= 1);
      if (inFlight) {
        CasaPaymentLog.log(
          'UI/Subscription',
          'STOMP: SUBSCRIPTION_CANCEL → arrêt attente / loader',
        );
        _cancelSubscriptionWaitTimers();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _awaitingSubscriptionWs = false;
            _awaitingCardCheckout = false;
            _paymentStep = 0;
          });
          final msg = (data['message'] ?? data['body'] ?? 'Paiement annulé.')
              .toString()
              .trim();
          if (msg.isNotEmpty) {
            SnackbarForCasa.warning(context, msg);
          }
        }
      } else {
        CasaPaymentLog.log(
          'UI/Subscription',
          'STOMP: SUBSCRIPTION_CANCEL ignoré (aucun paiement en attente)',
        );
      }
      return;
    }

    if (!_awaitingSubscriptionWs) {
      CasaPaymentLog.log(
        'UI/Subscription',
        'STOMP: pas en attente paiement abonnement (message affiché ci-dessus pour analyse)',
      );
      return;
    }
    final match = _isSubscriptionPaymentSuccess(data);
    CasaPaymentLog.log('UI/Subscription', 'STOMP: critère succès abonnement → $match');
    if (!match) return;
    if (!mounted) return;
    CasaPaymentLog.log('UI/Subscription', '✓ confirmation via STOMP → _handleSubscriptionPaymentConfirmed');
    _handleSubscriptionPaymentConfirmed();
  }

  /// Détecte une notification WebSocket confirmant le paiement d'abonnement (aligner avec le JSON backend).
  bool _isSubscriptionPaymentSuccess(Map<String, dynamic> data) {
    if ((data['tag'] ?? '').toString().toUpperCase() == 'SUBSCRIPTION_CANCEL') {
      return false;
    }
    final type = (data['type'] ?? '').toString().toLowerCase();
    final category = (data['category'] ?? '').toString().toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final body = (data['message'] ?? data['body'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? data['paymentStatus'] ?? '').toString().toLowerCase();

    if (data['subscriptionPayment'] == true || data['subscription_payment'] == true) {
      return true;
    }

    final user = data['user'];
    if (user is Map) {
      final um = Map<String, dynamic>.from(user);
      final p = um['isPremium'] ?? um['is_premium'] ?? um['premium'];
      final isPremium = p == true || p == 1 || p.toString().toLowerCase() == 'true';
      if (isPremium && !_wasPremiumBeforePaymentIntent) {
        return true;
      }
    }

    if (status == 'success' || status == 'paid' || status == 'completed') {
      if (type.contains('pay') ||
          category.contains('pay') ||
          category.contains('premium') ||
          title.contains('abonn') ||
          body.contains('abonnement')) {
        return true;
      }
    }

    return false;
  }

  bool _httpIndicatesSubscriptionSuccess(dynamic data) {
    if (data is! Map) return false;
    final m = Map<String, dynamic>.from(data);
    final u = m['user'];
    if (u is Map) {
      final um = Map<String, dynamic>.from(u);
      final p = um['isPremium'] ?? um['is_premium'];
      if (p == true || p == 1 || p.toString().toLowerCase() == 'true') return true;
    }
    final st = (m['status'] ?? m['paymentStatus'] ?? '').toString().toLowerCase();
    if (st == 'success' || st == 'paid' || st == 'completed') {
      if (m['subscription'] == true) return true;
      final t = (m['type'] ?? '').toString().toLowerCase();
      if (t.contains('subscription') || t.contains('abonn')) return true;
    }
    return false;
  }

  void _handleSubscriptionPaymentConfirmed() {
    if (_subscriptionSuccessHandled) return;
    _cancelSubscriptionWaitTimers();
    CasaPaymentLog.log('UI/Subscription', '═══ SUCCÈS ABONNEMENT (fermeture / callback) ═══');
    _subscriptionSuccessHandled = true;
    _awaitingSubscriptionWs = false;
    _awaitingCardCheckout = false;

    final authCtrl = context.read<AuthentificationCtrl>();
    authCtrl.user = authCtrl.user.copyWith(isPremium: true);
    CasaPaymentLog.log('UI/Subscription', 'premium appliqué localement (source : notification STOMP)');

    final cb = widget.onSuccess;
    if (cb != null) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      cb();
    } else {
      if (!mounted) return;
      setState(() {
        _paymentStep = 3;
        _isLoading = false;
      });
      SnackbarForCasa.success(context, 'Abonnement activé !');
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _detectNetworkFromPhone() {
    String text = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    
    // Automatically remove leading '0' as in LoginScreen.dart
    if (text.startsWith('0') && text.length > 1) {
      text = text.substring(1);
      _phoneController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    setState(() {
      if (text.length >= 2) {
        String p2 = text.substring(0, 2);
        String p3 = text.length >= 3 ? text.substring(0, 3) : "";

        if (['81', '82', '83', '86'].contains(p2)) {
          _detectedNetwork = "Vodacom";
        } else if (['84', '85', '89', '80'].contains(p2)) {
          _detectedNetwork = "Orange";
        } else if (['97', '98', '99', '96'].contains(p2)) {
          _detectedNetwork = "Airtel";
        } else if (['90', '91'].contains(p2)) {
          _detectedNetwork = "Africell";
        } else {
          _detectedNetwork = "Inconnu";
        }
      } else {
        _detectedNetwork = "Inconnu";
      }
    });
  }

  bool _isPhoneValid() {
    String digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9 && _detectedNetwork != "Inconnu";
  }

  int _deviseIdForPayment() {
    final dc = context.read<DeviseController>();
    if (dc.devises.isEmpty) return 2;
    final d = dc.devises.firstWhere(
      (e) => e.code == _selectedCurrency,
      orElse: () => dc.devises.firstWhere(
        (e) => e.code == 'USD',
        orElse: () => dc.devises.first,
      ),
    );
    return d.id ?? 2;
  }

  void _abortPendingPayment({bool showSnack = true}) {
    if (!mounted) return;
    CasaPaymentLog.log('UI/Subscription', 'abort paiement (snack=$showSnack)');
    _cancelSubscriptionWaitTimers();
    final hadProgress = _paymentFlowActive ||
        _awaitingSubscriptionWs ||
        _awaitingCardCheckout ||
        _isLoading;
    setState(() {
      _isLoading = false;
      _awaitingSubscriptionWs = false;
      _awaitingCardCheckout = false;
      _paymentStep = 0;
    });
    if (showSnack && hadProgress) {
      SnackbarForCasa.info(context, 'Paiement annulé.');
    }
  }

  void _handleCloseOrBack() {
    if (_paymentFlowActive) {
      _abortPendingPayment(showSnack: true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _processPayment() async {
    final authCtrl = context.read<AuthentificationCtrl>();
    final paymentCtrl = context.read<PaymentController>();

    _subscriptionSuccessHandled = false;
    _wasPremiumBeforePaymentIntent = authCtrl.user.isPremium == true;
    CasaPaymentLog.log(
      'UI/Subscription',
      '▶ début paiement method=${_selectedMethod == 0 ? "MobileMoney" : "Card"} devise=$_selectedCurrency wasPremium=$_wasPremiumBeforePaymentIntent userId=${authCtrl.user.userId}',
    );
    _ensureStompConnected();

    if (authCtrl.token.isEmpty) {
      CasaPaymentLog.log('UI/Subscription', 'abandon: token vide');
      return;
    }

    if (_selectedMethod == 0) {
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (phoneDigits.length < 9) {
        return;
      }
      if (_detectedNetwork == "Inconnu") {
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _awaitingSubscriptionWs = false;
      _paymentStep = 1;
    });

    try {
      if (_selectedMethod == 0) {
        final cleanedPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
        final finalPhone = '243$cleanedPhone';
        final deviseId = _deviseIdForPayment();

        CasaPaymentLog.log(
          'UI/Subscription',
          'Mobile Money → phone=${CasaPaymentLog.maskPhone(finalPhone)} deviseId=$deviseId',
        );
        setState(() => _paymentStep = 2);

        final response = await paymentCtrl.postSubscriptionPayment(
          phone: finalPhone,
          deviseId: deviseId,
          token: authCtrl.token,
        );

        if (!mounted) return;

        if (!response.status) {
          CasaPaymentLog.log(
            'UI/Subscription',
            'Mobile Money POST échec err=${response.errorMsg}',
          );
          setState(() {
            _paymentStep = 0;
            _awaitingSubscriptionWs = false;
          });
          return;
        }

        if (_httpIndicatesSubscriptionSuccess(response.data)) {
          CasaPaymentLog.log('UI/Subscription', 'Mobile Money: succès HTTP immédiat (user premium dans body)');
          _handleSubscriptionPaymentConfirmed();
          return;
        }

        CasaPaymentLog.log(
          'UI/Subscription',
          'Mobile Money: attente notification STOMP uniquement (awaitingWs=true)',
        );
        setState(() {
          _awaitingSubscriptionWs = true;
          _paymentStep = 2;
          _isLoading = false;
        });
        _startSubscriptionWaitTimers(cardCheckout: false);
      } else {
        final deviseId = _deviseIdForPayment();
        CasaPaymentLog.log('UI/Subscription', 'Carte → deviseId=$deviseId');
        setState(() => _paymentStep = 2);

        final response = await paymentCtrl.postCardPaymentSession(
          deviseId: deviseId,
          token: authCtrl.token,
        );

        if (!mounted) return;

        if (!response.status) {
          if (mounted) {
            SnackbarForCasa.error(
              context,
              response.errorMsg ??
                  'Impossible de démarrer le paiement par carte.',
            );
            setState(() {
              _paymentStep = 0;
              _isLoading = false;
            });
          }
          return;
        }

        final checkoutUrl = _extractCheckoutUrl(response.data);
        CasaPaymentLog.log(
          'UI/Subscription',
          'checkout URL extraite: ${checkoutUrl != null && checkoutUrl.length > 80 ? "${checkoutUrl.substring(0, 80)}…" : checkoutUrl}',
        );
        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          if (mounted) {
            SnackbarForCasa.error(
              context,
              'Réponse serveur sans lien de paiement.',
            );
            setState(() {
              _paymentStep = 0;
              _isLoading = false;
            });
          }
          return;
        }

        final launched = await _openCheckoutUrl(checkoutUrl);
        if (!mounted) return;

        if (!launched) {
          SnackbarForCasa.error(
            context,
            'Impossible d’ouvrir la page de paiement.',
          );
          setState(() {
            _paymentStep = 0;
            _isLoading = false;
          });
          return;
        }

        if (_httpIndicatesSubscriptionSuccess(response.data)) {
          CasaPaymentLog.log('UI/Subscription', 'Carte: succès HTTP immédiat (premium dans body)');
          _handleSubscriptionPaymentConfirmed();
          return;
        }

        CasaPaymentLog.log(
          'UI/Subscription',
          'Carte: navigateur ouvert — attente STOMP + retour app (awaitingCard=true)',
        );
        setState(() {
          _awaitingCardCheckout = true;
          _awaitingSubscriptionWs = true;
          _paymentStep = 2;
          _isLoading = false;
        });

        SnackbarForCasa.info(
          context,
          'Finalisez le paiement dans le navigateur sécurisé, puis revenez à l’app.',
        );
        _startSubscriptionWaitTimers(cardCheckout: true);
      }
    } catch (e, st) {
      CasaPaymentLog.log('UI/Subscription', 'exception paiement: $e');
      CasaPaymentLog.log('UI/Subscription', 'stack: $st');
      _cancelSubscriptionWaitTimers();
      if (mounted) {
        setState(() {
          _paymentStep = 0;
          _awaitingSubscriptionWs = false;
          _awaitingCardCheckout = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          if (!_awaitingSubscriptionWs) {
            _isLoading = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviseCtrl = context.watch<DeviseController>();
    final amount = deviseCtrl.convert(_subscriptionPriceUsd, fromCode: "USD", toCode: _selectedCurrency);
    final fee = _selectedCurrency == "USD" ? 0.13 : 275.0;
    final total = amount + fee;
    
    // Formatting for UI
    String formatValue(double val) {
      if (_selectedCurrency == "CDF") {
        return "${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FC";
      } else {
        return "\$${val.toStringAsFixed(2)}";
      }
    }

    String formattedSubtotal = formatValue(amount);
    String formattedFee = formatValue(fee);
    String formattedTotal = formatValue(total);

    final hasToken =
        (GetStorage().read<String>(StockageKeys.tokenKey) ?? '').isNotEmpty;

    return PopScope(
      canPop: !_paymentFlowActive,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _abortPendingPayment(showSnack: true);
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            widget.onSuccess != null ? Icons.close : Icons.arrow_back,
            color: const Color(0xFF111827),
          ),
          onPressed: _handleCloseOrBack,
        ),
        title: Text(
          "Abonnement",
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      if (!hasToken) ...[
                        _buildLoginRequiredBanner(),
                        const SizedBox(height: 20),
                      ],
                      // Pricing Section
                      _buildHeader(),
                      const SizedBox(height: 32),
                      
                      // Payment Methods (Horizontal Selection)
                      _buildMethodSelection(),
                      const SizedBox(height: 32),

                      // Form Area
                      _showPaymentProgress
                        ? _buildPaymentTimeline()
                        : AnimatedCrossFade(
                            firstChild: _buildMobileMoneyForm(),
                            secondChild: _buildCardForm(),
                            crossFadeState: _selectedMethod == 0 ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 300),
                          ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Payment Button (visible pendant l’appel API : indicateur sur le bouton)
              _buildBottomBar(formattedSubtotal, formattedFee, formattedTotal),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Abonnement CasaNayo",
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Container(
              width: 100,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Text(
            "Publiez vos annonces, publiez vos services et faites vos réservations en illimité pendant 12 mois grâce à votre abonnement.",
            textAlign: TextAlign.left,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4B5563), height: 1.6, letterSpacing: -0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelection() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildMethodButton(0, "Mobile Money", Icons.smartphone_rounded),
          _buildMethodButton(1, "Carte Bancaire", Icons.credit_card_rounded),
        ],
      ),
    );
  }

  Widget _buildMethodButton(int index, String label, IconData icon) {
    bool isSelected = _selectedMethod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            // Pas d’ombre : le blur animé au changement d’onglet produisait un effet disgracieux.
            border: isSelected
                ? Border.all(color: const Color(0xFFE5E7EB))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF1976D2) : const Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(String subtotal, String fee, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow("Sous-total", subtotal),
          const SizedBox(height: 8),
          _buildSummaryRow("Frais de service", fee),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total",
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
              ),
              Row(
                children: [
                  _buildCurrencySelection(),
                  const SizedBox(width: 12),
                  Text(
                    total,
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1976D2)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Consumer<PaymentController>(
            builder: (context, pay, _) {
              final busy = _showPaymentProgress || pay.loading;
              return SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: busy
                      ? null
                      : (_selectedMethod == 0
                          ? (_isPhoneValid() ? _processPayment : null)
                          : _processPayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          "Payer $total",
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280))),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      ],
    );
  }

  Widget _buildCurrencySelection() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: ["USD", "CDF"].map((code) => _buildCurrencyCode(code)).toList(),
      ),
    );
  }

  Widget _buildCurrencyCode(String code) {
    bool isSelected = _selectedCurrency == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          CurrencyDisplay.labelForToggle(code),
          style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.black : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPaymentTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildTimelineStep(1, "Connexion"),
              _buildTimelineDivider(1),
              _buildTimelineStep(2, "Vérification"),
              _buildTimelineDivider(2),
              _buildTimelineStep(3, "Effectué"),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            _timelineTitle(),
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Text(
            _timelineSubtitle(),
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(int step, String label) {
    bool isActive = _paymentStep >= step;
    bool isCurrent = _paymentStep == step;
    
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1976D2) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCurrent 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(isActive ? Icons.check_rounded : Icons.circle_outlined, color: isActive ? Colors.white : const Color(0xFFD1D5DB), size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  String _timelineTitle() {
    if (_paymentStep == 1) return 'Préparation de la session…';
    if (_paymentStep == 2) {
      if (_selectedMethod == 1) {
        return 'Paiement sécurisé en cours…';
      }
      return 'Traitement par l’opérateur…';
    }
    return 'C’est prêt !';
  }

  String _timelineSubtitle() {
    if (_paymentStep == 1) return 'Vérification de vos identifiants';
    if (_paymentStep == 2) {
      if (_selectedMethod == 1) {
        return 'Complétez le paiement dans la fenêtre du navigateur, puis revenez ici.';
      }
      return 'Veuillez valider sur votre téléphone';
    }
    return 'Compte activé avec succès';
  }

  Widget _buildTimelineDivider(int afterStep) {
    bool isPast = _paymentStep > afterStep;
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isPast ? const Color(0xFF1976D2) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildMobileMoneyForm() {
    return Column(
      key: const ValueKey("mobile"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("NUMÉRO DE RÉCEPTION", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280), letterSpacing: 0.5)),
            _buildNetworkStatusRow(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isPhoneValid() ? const Color(0xFF1976D2) : const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text("🇨🇩", style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text("+243", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "854434602",
                    hintStyle: TextStyle(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),
              if (_isPhoneValid()) 
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildNetworkHelpText(),
      ],
    );
  }

  Widget _buildNetworkStatusRow() {
    final networks = ["Vodacom", "Orange", "Airtel", "Africell"];
    return Row(
      children: networks.map((net) {
        bool isDetected = _detectedNetwork == net;
        return Opacity(
          opacity: isDetected ? 1.0 : 0.3,
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            child: _buildNetworkLogoForStatus(net),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNetworkLogoForStatus(String network) {
    String assetPath = "";
    switch (network) {
      case "Orange": assetPath = "assets/images/orange.png"; break;
      case "Vodacom": assetPath = "assets/images/vodacom.jfif"; break;
      case "Airtel": assetPath = "assets/images/airtel.png"; break;
      case "Africell": assetPath = "assets/images/africell.png"; break;
      default: return const SizedBox.shrink();
    }
    return Image.asset(assetPath, width: 24, height: 24);
  }

  Widget _buildNetworkHelpText() {
    if (_phoneController.text.isEmpty) {
      return Text("Entrez votre numéro sans le 0", style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF)));
    }
    if (!_isPhoneValid()) {
      return Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Colors.orange),
          const SizedBox(width: 6),
          Text("Doit contenir exactement 9 chiffres", style: GoogleFonts.inter(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500)),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 6),
        Text(_detectedNetwork, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLoginRequiredBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connexion requise',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Le paiement d’abonnement utilise un compte connecté.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.brown.shade800),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, Routes.loginRoute),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String network) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1976D2).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(network, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1976D2))),
    );
  }

  Widget _buildCardForm() {
    return Column(
      key: const ValueKey("card"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAIEMENT PAR CARTE',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_rounded, color: const Color(0xFF1976D2), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Redirection sécurisée',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Après appui sur « Payer », une page hébergée par notre prestataire s’ouvre dans un navigateur intégré (comme Chrome ou Safari). Vous y saisissez votre carte ; nous ne stockons pas ces données dans l’app.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkLogo({bool small = false}) {
    String assetPath = "";
    switch (_detectedNetwork) {
      case "Orange": assetPath = "assets/images/orange.png"; break;
      case "Vodacom": assetPath = "assets/images/vodacom.jfif"; break;
      case "Airtel": assetPath = "assets/images/airtel.png"; break;
      case "Africell": assetPath = "assets/images/africell.png"; break;
      default: return Icon(Icons.shield_outlined, color: const Color(0xFFD1D5DB), size: small ? 20 : 28);
    }

    return Image.asset(
      assetPath,
      width: small ? 24 : 35,
      height: small ? 24 : 35,
      fit: BoxFit.contain,
      errorBuilder: (c, e, s) => Icon(Icons.phone_android_rounded, color: const Color(0xFFD1D5DB), size: small ? 20 : 28),
    );
  }

  @override
  void dispose() {
    _cancelSubscriptionWaitTimers();
    _authListener?.removeListener(_onAuthPremiumChanged);
    WidgetsBinding.instance.removeObserver(this);
    _stompSub?.cancel();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
