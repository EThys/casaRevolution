import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/utils/StockageKeys.dart';
import 'package:casa/utils/export_directory.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:casa/utils/Routes.dart';
import 'package:shimmer/shimmer.dart';

class PaymentHistoryPage extends StatefulWidget {
  /// Si présent (ex. depuis une notif de paiement), la ligne correspondante est dépliée et scrollée.
  final int? highlightPaymentId;

  const PaymentHistoryPage({Key? key, this.highlightPaymentId}) : super(key: key);

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final GetStorage _storage = GetStorage();
  final GlobalKey _highlightKey = GlobalKey();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  int? _userId;
  String? _username;
  String? _profileFullName;
  bool _isPremium = false;
  pw.MemoryImage? _logoImage;
  /// Clé `id` ou `reference` du paiement en cours de génération PDF (téléchargement ou partage).
  String _busyReceiptKey = '';

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _loadPayments();
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/images/logoCasa.png');
      setState(() {
        _logoImage = pw.MemoryImage(data.buffer.asUint8List());
      });
    } catch (_) {}
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final userData = _storage.read(StockageKeys.userKey);
      if (userData != null) {
        _userId = userData['userId'];
        _username = userData['username']?.toString();
      }
      final profile = _storage.read(StockageKeys.profileKey);
      if (profile is Map) {
        _profileFullName = profile['fullName']?.toString() ??
            profile['fullname']?.toString();
      }
      
      final token = _storage.read(StockageKeys.tokenKey);
      
      if (_userId != null) {
        final response = await getData(Endpoints.paymentHistory + _userId.toString(), token: token);
        
        if (response != null && response['log'] != null) {
          final logData = response['log'];
          final List<dynamic> paymentsList = logData['payment'] ?? [];
          final userDataFromApi = logData['user'];
          
          setState(() {
            _payments = paymentsList.map((e) => Map<String, dynamic>.from(e)).toList();
            _payments.sort(_comparePaymentsNewestFirst);
            if (userDataFromApi != null) {
              _isPremium = userDataFromApi['premium'] ?? false;
            }
            _isLoading = false;
          });
          _scrollToHighlightIfNeeded();
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ Error loading payments: $e");
      setState(() => _isLoading = false);
    }
  }

  /// Plus récent en tête de liste.
  static int _comparePaymentsNewestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime? parse(Map<String, dynamic> m) =>
        DateTime.tryParse(m['dateCreated']?.toString() ?? '') ??
        DateTime.tryParse(m['createdAt']?.toString() ?? '');
    final ta = parse(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = parse(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  }

  void _scrollToHighlightIfNeeded() {
    if (widget.highlightPaymentId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
    });
  }

  bool _paymentMatchesHighlight(Map<String, dynamic> payment) {
    if (widget.highlightPaymentId == null) return false;
    final pid = payment['id'];
    if (pid == null) return false;
    return pid.toString() == widget.highlightPaymentId!.toString();
  }

  String _paymentKey(Map<String, dynamic> p) =>
      '${p['id'] ?? p['reference'] ?? ''}';

  String get _clientDisplayName {
    final u = (_username ?? '').trim();
    if (u.isNotEmpty) return u;
    final n = (_profileFullName ?? '').trim();
    if (n.isNotEmpty) return n;
    return 'Client CasaNayo';
  }

  ({String label, Color bg, Color fg, Color border}) _statusStyle(String status) {
    final s = status.toUpperCase();
    if (s == 'SUCCESS') {
      return (
        label: 'Réussi',
        bg: const Color(0xFFECFDF5),
        fg: const Color(0xFF047857),
        border: const Color(0xFFA7F3D0),
      );
    }
    if (s == 'PENDING') {
      return (
        label: 'En cours',
        bg: const Color(0xFFE3F2FD),
        fg: const Color(0xFF1565C0),
        border: const Color(0xFFBBDEFB),
      );
    }
    return (
      label: 'Échoué',
      bg: const Color(0xFFFEF2F2),
      fg: const Color(0xFF991B1B),
      border: const Color(0xFFFECACA),
    );
  }

  Future<Uint8List> _buildInvoicePdf(Map<String, dynamic> payment) async {
    final doc = pw.Document();
    
    // Charger une police pour les accents
    pw.Font? ttf;
    try {
      final fontData = await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (_) {}

    final dateToken = DateTime.tryParse(payment['dateCreated'] ?? '') ?? DateTime.now();
    final now = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(DateTime.now());
    final currency = payment['devise'] == 'CDF' ? 'FC' : (payment['devise'] == 'USD' ? '\$' : payment['devise'] ?? '');

    // Helper pour les lignes de détails
    pw.Widget pdfDetailRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // --- HEADER PREMIUM ---
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Column(
                     crossAxisAlignment: pw.CrossAxisAlignment.start,
                     children: [
                       pw.Text(
                         'REÇU DE PAIEMENT',
                         style: pw.TextStyle(
                           color: PdfColors.white,
                           fontSize: 22,
                           fontWeight: pw.FontWeight.bold,
                         ),
                       ),
                       pw.Text(
                         'Confirmation Officielle de Transaction',
                         style: pw.TextStyle(
                           color: PdfColor.fromInt(0xE6FFFFFF),
                           fontSize: 11,
                         ),
                       ),
                     ],
                   ),
                   if (_logoImage != null)
                     pw.Container(
                       width: 45,
                       height: 45,
                       decoration: pw.BoxDecoration(
                         color: PdfColors.white,
                         shape: pw.BoxShape.circle,
                       ),
                       padding: const pw.EdgeInsets.all(4),
                       child: pw.Image(_logoImage!),
                     ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- INFOS GÉNÉRALES ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Référence : #${payment['reference'] ?? payment['id']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Date d\'émission : $now', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(
                  'PAIEMENT VALIDÉ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1565C0),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // --- SECTION : DÉTAILS DU PAIEMENT ---
            pw.Text('1. INFORMATIONS SUR LA TRANSACTION', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pdfDetailRow('Client / Utilisateur', _clientDisplayName),
                  pdfDetailRow('Description', payment['description'] ?? 'Abonnement Annuel'),
                  pdfDetailRow('Mode de Paiement', payment['typePayment'] ?? 'MOBILE_MONEY'),
                  pdfDetailRow('Date du Paiement', DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateToken)),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // --- SECTION : RÉSUMÉ FINANCIER ---
            pw.Text('2. RÉSUMÉ DU RÈGLEMENT', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('DESIGNATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(payment['description'] ?? 'Abonnement Annuel CasaNayo', style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${payment['amount']} $currency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1976D2'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'MONTANT TOTAL PAYÉ : ${payment['amount']} $currency',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // --- FOOTER ---
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              "Merci de faire confiance à CasaNayo pour vos transactions immobilières. Ce reçu est généré automatiquement par le système et ne nécessite pas de signature.",
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              textAlign: pw.TextAlign.justify,
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CasaNayo Support : +243 836 323 805', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Email : contact@casanayo.com', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Généré par CasaNayo - www.casanayo.com', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      'Adresse : 14 Avenue Pumbu, Gombe, Kinshasa - RDC',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Future<void> _downloadInvoice(Map<String, dynamic> payment) async {
    if (payment['status']?.toUpperCase() != 'SUCCESS') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reçu disponible uniquement pour les paiements réussis.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final key = _paymentKey(payment);
    setState(() => _busyReceiptKey = key);
    try {
      final dir = await pickExportDirectoryOrNull();
      if (dir == null) {
        if (mounted) {
          SnackbarForCasa.info(
            context,
            'Enregistrement annulé : aucun dossier sélectionné.',
          );
        }
        return;
      }

      final bytes = await _buildInvoicePdf(payment);
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final filePath = '${dir.path}/Facture_Paiement_Ref_${payment['id']}_du_$generationDate.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } catch (e) {
      if (mounted) {
        SnackbarForCasa.error(
          context,
          "La facture n’a pas pu être enregistrée. Vérifiez l’espace disque et réessayez.",
        );
      }
    } finally {
      if (mounted) setState(() => _busyReceiptKey = '');
    }
  }

  Future<void> _shareInvoice(Map<String, dynamic> payment) async {
    if (payment['status']?.toUpperCase() != 'SUCCESS') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partage du reçu réservé aux paiements réussis.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final key = _paymentKey(payment);
    setState(() => _busyReceiptKey = key);
    try {
      final bytes = await _buildInvoicePdf(payment);
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Facture_Paiement_Ref_${payment['id']}_du_$generationDate.pdf';

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      final xfile = XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);

      await SharePlus.instance.share(
        ShareParams(
          files: [xfile],
          text:
              'Reçu de paiement CasaNayo — Réf. ${payment['reference'] ?? payment['id']}',
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackbarForCasa.error(
          context,
          "Le partage n’a pas abouti. Réessayez ou enregistrez le PDF puis partagez-le depuis vos fichiers.",
        );
      }
    } finally {
      if (mounted) setState(() => _busyReceiptKey = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF475569), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1976D2), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TRANSACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                  Text(
                    'Paiements & reçus',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _loadPayments(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: _isLoading ? Colors.grey : const Color(0xFF475569),
                ),
                const SizedBox(width: 4),
                Text(
                  'Actualiser',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _isLoading ? Colors.grey : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.subscriptionPaymentRoute),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE3F2FD),
                foregroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0x661976D2)),
                ),
              ),
              child: Text(
                'Abonnement',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1976D2),
        onRefresh: _loadPayments,
        child: _isLoading && _payments.isEmpty
          ? _buildShimmer()
          : _payments.isEmpty
              ? _buildEmpty()
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildSummaryHeader()),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        24 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPaymentCard(_payments[index]),
                          childCount: _payments.length,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
    );
  }

  Widget _buildSummaryHeader() {
    double totalUSD = 0;
    double totalCDF = 0;
    int pendingCount = 0;

    for (var p in _payments) {
      final status = p['status']?.toString().toUpperCase() ?? '';
      if (status == 'SUCCESS') {
        final amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        if (p['devise'] == 'USD') totalUSD += amt;
        if (p['devise'] == 'CDF') totalCDF += amt;
      } else if (status == 'PENDING') {
        pendingCount++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PAYÉ (SUCCÈS)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          totalUSD.toStringAsFixed(0),
                          style: GoogleFonts.inter(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: Colors.white,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'USD',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ),
                        if (totalCDF > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '· ${NumberFormat.decimalPattern('fr_FR').format(totalCDF.round())} FC',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMPTE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPremium ? 'Premium actif' : 'Standard',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$pendingCount en attente',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFE082),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    double? width,
    required double height,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildShimmer() {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
      children: [
        Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0),
          highlightColor: const Color(0xFFF8FAFC),
          child: Container(
            height: 156,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: const Color(0xFFF8FAFC),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _shimmerBox(height: 16)),
                      const SizedBox(width: 12),
                      _shimmerBox(width: 72, height: 24, radius: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _shimmerBox(width: 150, height: 12),
                  const SizedBox(height: 12),
                  _shimmerBox(width: 96, height: 22, radius: 6),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _shimmerBox(height: 42, radius: 12)),
                      const SizedBox(width: 10),
                      Expanded(child: _shimmerBox(height: 42, radius: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (i < 3) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 28),
            Text(
              'Aucun paiement',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Après souscription, vos transactions et reçus apparaîtront ici.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.45,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: () => Navigator.pushNamed(context, Routes.subscriptionPaymentRoute),
              child: Text(
                'Souscrire — 5 \$ / an',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final isSuccess = status == 'SUCCESS';
    final dateToken = DateTime.tryParse(payment['dateCreated']?.toString() ?? '') ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(dateToken);

    final currency = payment['devise'] == 'CDF'
        ? 'FC'
        : (payment['devise'] == 'USD' ? '\$' : payment['devise']?.toString() ?? '');
    final amount = payment['amount']?.toString() ?? '0';
    final st = _statusStyle(status);
    final pKey = _paymentKey(payment);
    final busy = _busyReceiptKey == pKey && pKey.isNotEmpty;

    final highlight = _paymentMatchesHighlight(payment);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? const Color(0xFF1976D2) : const Color(0xFFE2E8F0),
          width: highlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['description']?.toString() ?? 'Abonnement CasaNayo',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${payment['reference'] ?? payment['id']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: st.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: st.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : (status == 'PENDING' ? Icons.schedule_rounded : Icons.cancel_rounded),
                      size: 14,
                      color: st.fg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      st.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: st.fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateStr,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Text(
            '$amount $currency'.trim(),
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1976D2),
            ),
          ),
          if ((payment['typePayment'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              payment['typePayment'].toString(),
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
          if (isSuccess) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildReceiptCtaButton(
                    icon: Icons.download_rounded,
                    label: 'PDF',
                    loading: busy,
                    onTap: busy ? null : () => _downloadInvoice(payment),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReceiptCtaButton(
                    icon: Icons.share_rounded,
                    label: 'Partager',
                    loading: busy,
                    onTap: busy ? null : () => _shareInvoice(payment),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (highlight) {
      return KeyedSubtree(key: _highlightKey, child: card);
    }
    return card;
  }

  /// Boutons style dashboard web : bordure bleue, fond #E3F2FD.
  Widget _buildReceiptCtaButton({
    required IconData icon,
    required String label,
    required bool loading,
    VoidCallback? onTap,
  }) {
    return Material(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x661976D2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                )
              else
                Icon(icon, size: 18, color: const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
