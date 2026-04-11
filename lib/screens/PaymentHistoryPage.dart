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
import 'package:casa/utils/Constantes.dart';
import 'package:casa/utils/export_directory.dart';

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
  bool _isPremium = false;
  pw.MemoryImage? _logoImage;

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
        _username = userData['username'];
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
    pw.Widget _buildDetailRow(String label, String value) {
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
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text('PAIEMENT VALIDÉ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
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
                  _buildDetailRow('Client / Utilisateur', _username ?? 'Client CasaNayo'),
                  _buildDetailRow('Description', payment['description'] ?? 'Abonnement Annuel'),
                  _buildDetailRow('Mode de Paiement', payment['typePayment'] ?? 'MOBILE_MONEY'),
                  _buildDetailRow('Date du Paiement', DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateToken)),
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
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CasaNayo Support : +243 836 323 805', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Email : contact@casanayo.com', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Text('Généré par CasaNayo - www.casanayo.com', style: const pw.TextStyle(fontSize: 8)),
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
          const SnackBar(content: Text('Impossible de télécharger la facture pour un paiement non réussi.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final bytes = await _buildInvoicePdf(payment);
      final dir = await getUserDownloadExportDirectory();
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final filePath = '${dir.path}/Facture_Paiement_Ref_${payment['id']}_du_$generationDate.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facture enregistrée dans : ${dir.path}'),
            backgroundColor: const Color(0xFF1976D2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareInvoice(Map<String, dynamic> payment) async {
    if (payment['status']?.toUpperCase() != 'SUCCESS') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de partager la facture pour un paiement non réussi.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    try {
      final bytes = await _buildInvoicePdf(payment);
      final generationDate = DateFormat('dd_MMMM_yyyy_HH_mm', 'fr_FR').format(DateTime.now());
      final fileName = 'Facture_Paiement_Ref_${payment['id']}_du_$generationDate.pdf';
      
      // Pour garantir le nom du fichier au partage, on l'écrit d'abord dans un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      final xfile = XFile(tempFile.path, mimeType: 'application/pdf', name: fileName);
      
      await Share.shareXFiles(
        [xfile],
        text: 'Reçu de paiement CasaNayo - ${payment['reference'] ?? payment['id']}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de partage : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Historique des paiements',
          style: GoogleFonts.inter(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : _payments.isEmpty
              ? _buildEmpty()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildSummaryHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildPaymentCard(_payments[index]);
                          },
                          childCount: _payments.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
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
        double amt = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
        if (p['devise'] == 'USD') totalUSD += amt;
        if (p['devise'] == 'CDF') totalCDF += amt;
      } else if (status == 'PENDING') {
        pendingCount++;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username?.toUpperCase() ?? "MON COMPTE",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "DÉPENSES (SUCCÈS)",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${totalUSD.toStringAsFixed(0)} \$",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (totalCDF > 0) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "| ${totalCDF.toStringAsFixed(0)} FC",
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPremium ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPremium ? "Premium" : "Standard",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        "$pendingCount en attente",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          Text('Aucun paiement',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('Votre historique de transactions\napparaîtra ici.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString().toUpperCase() ?? 'UNKNOWN';
    final isSuccess = status == 'SUCCESS';
    final isPending = status == 'PENDING';
    
    final dateToken = DateTime.tryParse(payment['dateCreated'] ?? '') ?? DateTime.now();
    final day = DateFormat('dd').format(dateToken);
    final month = DateFormat('MMM', 'fr_FR').format(dateToken).toUpperCase();

    final currency = payment['devise'] == 'CDF' ? 'FC' : (payment['devise'] == 'USD' ? '\$' : payment['devise'] ?? '');
    final amount = payment['amount']?.toString() ?? '0';

    Color statusColor = const Color(0xFFEF4444); // Red by default
    IconData statusIcon = Icons.error_rounded;

    if (isSuccess) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.more_horiz_rounded;
    }

    final highlight = _paymentMatchesHighlight(payment);

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? const Color(0xFF1976D2) : const Color(0xFFF3F4FB),
          width: highlight ? 2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: highlight,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                Text(month, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280))),
              ],
            ),
          ),
          title: Text(
            payment['description'] ?? 'Paiement abonnement',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "Réf: ${payment['reference'] ?? payment['id']}",
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$amount $currency",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSuccess ? "Payé" : (isPending ? "En attente" : "Échoué"),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(statusIcon, size: 12, color: statusColor),
                ],
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                   Divider(color: const Color(0xFFF3F4F6), height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow("Type", payment['typePayment'] ?? "MOBILE_MONEY"),
                  _buildDetailRow("Date", DateFormat('dd MMMM yyyy HH:mm', 'fr_FR').format(dateToken)),
                  _buildDetailRow("Statut", status),
                  if (isSuccess) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.download_rounded,
                            label: "Reçu",
                            onTap: () => _downloadInvoice(payment),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.share_rounded,
                            label: "Partager",
                            onTap: () => _shareInvoice(payment),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (highlight) {
      return KeyedSubtree(key: _highlightKey, child: tile);
    }
    return tile;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280))),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1976D2))),
          ],
        ),
      ),
    );
  }
}
