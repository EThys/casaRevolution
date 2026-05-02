import 'package:cached_network_image/cached_network_image.dart';
import 'package:casa/controllers/CotationController.dart';
import 'package:casa/models/CotationModel.dart';
import 'package:casa/models/PrestationModel.dart';
import 'package:casa/models/SollicitationModel.dart';
import 'package:casa/screens/ServiceDetailPage.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SollicitationDetailPage extends StatefulWidget {
  final SollicitationModel sollicitation;
  final int? currentUserId;
  final bool canRateForTest;

  const SollicitationDetailPage({
    Key? key,
    required this.sollicitation,
    required this.currentUserId,
    this.canRateForTest = true,
  }) : super(key: key);

  @override
  State<SollicitationDetailPage> createState() => _SollicitationDetailPageState();
}

class _SollicitationDetailPageState extends State<SollicitationDetailPage> {
  static const Color _primary = Color(0xFF1976D2);
  static const Color _bg = Color(0xFFF5F6FA);
  bool _loadingCotations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = context.read<CotationController>();
      await ctrl.fetchPublicCotations(forceRefresh: false);
      if (!mounted) return;
      setState(() => _loadingCotations = false);
      // SWR refresh in background for freshness
      ctrl.fetchPublicCotations(forceRefresh: true);
    });
  }

  bool get _canRate {
    final me = widget.currentUserId;
    final s = widget.sollicitation;
    if (!widget.canRateForTest) return false;
    if (me == null || s.id == null) return false;
    if (s.userId != me) return false;
    // status rules handled in MyServices for now; keep open here for tests
    return true;
  }

  Future<void> _showCotationDialog() async {
    final me = widget.currentUserId;
    final sid = widget.sollicitation.id;
    if (me == null || sid == null) return;

    final commentCtrl = TextEditingController();
    double cote = 4.0;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Consumer<CotationController>(
          builder: (ctx, cotationCtrl, _) {
            return StatefulBuilder(
              builder: (ctx, setDialogState) {
                return AlertDialog(
                  title: Text(
                    'Mettre un avis',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note : ${cote.toStringAsFixed(1)} / 5',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        Slider(
                          value: cote,
                          min: 0.5,
                          max: 5.0,
                          divisions: 9,
                          label: cote.toStringAsFixed(1),
                          activeColor: _primary,
                          onChanged: cotationCtrl.loading ? null : (v) => setDialogState(() => cote = v),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Commentaire',
                            hintText: 'Décrivez votre expérience',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: cotationCtrl.loading ? null : () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: cotationCtrl.loading
                          ? null
                          : () async {
                              final text = commentCtrl.text.trim();
                              if (text.length < 3) {
                                FancyNotification.show(
                                  ctx,
                                  'Le commentaire doit contenir au moins 3 caractères.',
                                  type: NotificationType.warning,
                                );
                                return;
                              }
                              final resp = await cotationCtrl.upsertCotation(
                                userId: me,
                                sollicitationId: sid,
                                commentaire: text,
                                cote: cote,
                              );
                              if (!ctx.mounted) return;
                              if (resp.status) {
                                Navigator.pop(ctx);
                                FancyNotification.show(
                                  context,
                                  'Merci pour votre avis.',
                                  type: NotificationType.success,
                                );
                                await cotationCtrl.fetchPublicCotations(forceRefresh: true);
                              } else {
                                FancyNotification.show(
                                  ctx,
                                  resp.errorMsg ?? 'Impossible d\'enregistrer l\'avis.',
                                  type: NotificationType.error,
                                );
                              }
                            },
                      child: cotationCtrl.loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Envoyer'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    commentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sollicitation;
    final prestation = s.prestation;
    final PrestationModel? prestationForDetail = prestation ??
        (s.prestationId != null
            ? PrestationModel(id: s.prestationId)
            : null);
    final img = prestation?.profile ?? (prestation?.images?.isNotEmpty ?? false ? prestation!.images!.first : null);
    final title = prestation?.title ?? 'Sollicitation';
    final status = (s.status ?? '').trim();

    final cotationCtrl = context.watch<CotationController>();
    final List<CotationModel> cotations = (s.id != null) ? cotationCtrl.cotationsForSollicitation(s.id!) : const [];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Détails', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: img != null && img.trim().isNotEmpty
                        ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover)
                        : Container(
                            color: _primary.withOpacity(0.08),
                            child: const Icon(Icons.miscellaneous_services_rounded, size: 56, color: _primary),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _primary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if ((s.description ?? '').trim().isNotEmpty)
                        Text(
                          s.description!.trim(),
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563), height: 1.4),
                        ),
                      if (_canRate) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _showCotationDialog,
                            icon: const Icon(Icons.star_rounded),
                            label: Text('Noter le prestataire', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                      if (prestationForDetail != null &&
                          s.id != null &&
                          prestationForDetail.id != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceDetailPage(
                                    service: prestationForDetail,
                                    sollicitationId: s.id,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.miscellaneous_services_rounded, size: 20),
                            label: Text(
                              'Voir la fiche du service',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text('Avis', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
          const SizedBox(height: 10),

          if (_loadingCotations)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Chargement des avis...', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563))),
                ],
              ),
            )
          else if (cotations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text('Aucun avis pour cette sollicitation.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563))),
            )
          else
            ...cotations.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _reviewTile(c),
                )),
        ],
      ),
    );
  }

  Widget _reviewTile(CotationModel c) {
    final note = (c.cote ?? 0).toStringAsFixed(1);
    final text = (c.commentaire ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF64B5F6)]),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('★ $note', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sollicitation #${c.sollicitationId ?? '-'}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111827), height: 1.35)),
          ],
        ],
      ),
    );
  }
}

