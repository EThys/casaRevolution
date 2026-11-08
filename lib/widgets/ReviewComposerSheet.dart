import 'package:casa/controllers/CotationController.dart';
import 'package:casa/utils/FancyNotification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Feuille pour laisser un avis lié à une sollicitation déjà éligible.
Future<bool> showReviewComposer({
  required BuildContext context,
  required int userId,
  required int sollicitationId,
  String? serviceTitle,
}) async {
  final commentCtrl = TextEditingController();
  var score = 5.0;
  var submitted = false;
  try {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final inset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final safe = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final loading = ctx.watch<CotationController>().loading;
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + safe),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Votre avis',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B1220),
                      ),
                    ),
                    if ((serviceTitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        serviceTitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final filled = score >= index + 1;
                        return IconButton(
                          onPressed: loading
                              ? null
                              : () => setSheet(() => score = (index + 1).toDouble()),
                          icon: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: const Color(0xFFFFB300),
                            size: 36,
                          ),
                        );
                      }),
                    ),
                    Center(
                      child: Text(
                        '${score.toStringAsFixed(0)} / 5',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1976D2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentCtrl,
                      minLines: 3,
                      maxLines: 5,
                      enabled: !loading,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Comment s’est passée l’intervention ?',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final text = commentCtrl.text.trim();
                                if (text.length < 3) {
                                  FancyNotification.show(
                                    ctx,
                                    'Écrivez au moins quelques mots.',
                                    type: NotificationType.warning,
                                  );
                                  return;
                                }
                                final resp = await ctx.read<CotationController>().createCotation(
                                      userId: userId,
                                      sollicitationId: sollicitationId,
                                      commentaire: text,
                                      cote: score,
                                    );
                                if (!ctx.mounted) return;
                                if (resp.status) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  FancyNotification.show(
                                    ctx,
                                    resp.errorMsg ?? 'Impossible d’enregistrer l’avis.',
                                    type: NotificationType.error,
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Publier l’avis',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    submitted = result == true;
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      commentCtrl.dispose();
    });
  }
  return submitted;
}
