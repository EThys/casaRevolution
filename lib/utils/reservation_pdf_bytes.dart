import 'package:casa/models/ReservationModel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import 'status_labels_fr.dart';

/// Génère le PDF « bon de réservation » (même contenu que [BookingHistoryPage]).
Future<Uint8List> buildReservationPdfBytes(
  ReservationModel reservation,
  pw.MemoryImage? logoImage,
) async {
  final doc = pw.Document();

  pw.Font? ttf;
  try {
    final fontData = await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf');
    ttf = pw.Font.ttf(fontData);
  } catch (e) {
    // ignore font load
  }

  final now = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());

  final property = reservation.property;

  final advertiserName =
      property?.postBy?.toString() ?? property?.user?.username?.toString() ?? 'Non renseigné';
  final propTypeName = property?.propertyType?.name?.toString() ?? 'Propriété';
  final publisher = property?.user;
  String telOrEmpty(String? s) {
    final t = s?.trim() ?? '';
    if (t.isEmpty || t == 'null') return '';
    return t;
  }

  final publisherPhone = () {
    final fromApi = telOrEmpty(reservation.postByTel);
    if (fromApi.isNotEmpty) return fromApi;
    final fb = telOrEmpty(publisher?.phone?.toString());
    return fb.isNotEmpty ? fb : 'Non renseigné';
  }();
  final typeAccountName = (publisher?.typeAccount?.name?.toString() ?? '').toLowerCase();
  final publisherRole = typeAccountName.contains('bailleur')
      ? 'Bailleur'
      : (typeAccountName.contains('commission') || typeAccountName.contains('commissionnaire')
          ? 'Commissionnaire'
          : 'Annonceur');

  final qv = property?.quartierValue?.toString() ?? '';
  final qn = property?.quartier?.toString() ?? '';
  final quartierName =
      qv.isNotEmpty ? qv : (qn.isNotEmpty ? qn : '');
  final communeName = property?.communeValue?.toString() ?? '';
  final cityName = property?.cityValue?.toString() ?? '';
  final countryName = property?.countryValue?.toString() ?? '';

  String getCleanAddress(dynamic rawAddress) {
    if (rawAddress == null) return '';
    final str = rawAddress.toString();
    if (str.contains('{') && str.contains('}')) {
      try {
        final match = RegExp(r'(?:adresse|address)\s?[:=]\s?([^,}]+)').firstMatch(str);
        if (match != null) {
          return match.group(1)?.trim().replaceAll('"', '').replaceAll("'", "") ?? '';
        }
      } catch (_) {}
    }
    return str;
  }

  DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return DateFormat('dd-MM-yyyy').parse(dateStr);
      } catch (_) {
        return null;
      }
    }
  }

  String formatElegantDate(String? dateStr, {String? heureStr}) {
    final date = parseDate(dateStr);
    if (date == null) return dateStr ?? 'Non spécifiée';
    try {
      String formatted = DateFormat("EEEE 'le' dd-MM-yyyy", 'fr_FR').format(date);
      formatted = formatted.replaceRange(0, 1, formatted[0].toUpperCase());
      if (heureStr != null && heureStr.isNotEmpty) {
        return "$formatted à $heureStr";
      }
      return formatted;
    } catch (e) {
      return dateStr ?? 'Non spécifiée';
    }
  }

  String getEstimatedEnd(String? dateStr, String? heureStr) {
    if (dateStr == null || heureStr == null || heureStr.isEmpty) return 'Non spécifiée';
    try {
      final timeParts = heureStr.split(':');
      if (timeParts.length >= 2) {
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        hour = (hour + 1) % 24;
        final estimatedTime =
            "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        return formatElegantDate(dateStr, heureStr: estimatedTime);
      }
      return formatElegantDate(dateStr, heureStr: heureStr);
    } catch (_) {
      return formatElegantDate(dateStr, heureStr: heureStr);
    }
  }

  final userName = reservation.user?.username?.toString() ?? 'Client';
  final userPhone = reservation.user?.phone?.toString() ?? '';
  final userEmail = reservation.user?.email?.toString() ?? '';
  final statusFr = frReservationStatus(reservation.status);

  pw.Widget buildPdfDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  pw.TableRow buildPdfTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  doc.addPage(
    pw.Page(
      theme: ttf != null ? pw.ThemeData.withFont(base: ttf, bold: ttf) : null,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
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
                      'BON DE RÉSERVATION',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Confirmation Officielle de Demande de Visite',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xE6FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (logoImage != null)
                  pw.Container(
                    width: 50,
                    height: 50,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.white,
                      shape: pw.BoxShape.circle,
                    ),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Image(logoImage),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Référence : #${reservation.reservationId}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date d\'émission : $now',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text('Statut : $statusFr',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text('CASANAYO OFFICIEL',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),
          pw.Text('1. DÉTAILS DE LA PROPRIÉTÉ',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(property?.title ?? 'Propriété Non Spécifiée',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                buildPdfDetailRow('Adresse', getCleanAddress(property?.address)),
                buildPdfDetailRow('Type', propTypeName),
                buildPdfDetailRow('Emplacement', '$quartierName, $communeName'),
                buildPdfDetailRow('Ville / Pays', '$cityName, $countryName'),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text('2. RENDEZ-VOUS DE VISITE',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1976D2'))),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              buildPdfTableRow('Date de Visite', formatElegantDate(reservation.startDate)),
              buildPdfTableRow(
                  'Heure du RDV', (reservation.reservationHeure ?? '14:00').split(':').take(2).join(':')),
              buildPdfTableRow(
                  'Fin Estimée',
                  getEstimatedEnd(reservation.endDate ?? reservation.startDate, reservation.reservationHeure)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('3. INFORMATIONS CLIENT',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Nom : $userName', style: const pw.TextStyle(fontSize: 11)),
                    if (userPhone.isNotEmpty) pw.Text('Tel : $userPhone', style: const pw.TextStyle(fontSize: 11)),
                    if (userEmail.isNotEmpty) pw.Text('Email : $userEmail', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('4. INFORMATIONS ANNONCEUR',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text('Nom : $advertiserName', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Rôle : $publisherRole', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Tel : $publisherPhone', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text(
            "IMPORTANT : Ce document est une preuve de demande de visite. Il doit être validé par l'annonceur via l'application CasaNayo. Pour toute assistance, contactez notre support.",
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
              pw.Text('Émis par le système CasaNayo - www.casanayo.com', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
