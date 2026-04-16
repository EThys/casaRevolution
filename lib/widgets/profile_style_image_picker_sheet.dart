import 'package:flutter/material.dart';

/// Bottom sheet aligné sur le style « Photo de profil » (écran Profil).
Future<void> showProfileStyleImagePickerSheet(
  BuildContext context, {
  required Color primaryColor,
  required String sheetTitle,
  IconData headerIcon = Icons.photo_library_rounded,
  bool showPreview = false,
  String previewTitle = 'Aperçu en plein écran',
  String previewSubtitle = 'Voir l’image actuelle.',
  Future<void> Function()? onPreview,
  required String cameraTitle,
  required String cameraSubtitle,
  required Future<void> Function() onCamera,
  required String galleryTitle,
  required String gallerySubtitle,
  required Future<void> Function() onGallery,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      Widget actionTile({
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(headerIcon, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sheetTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text('Fermer', style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (showPreview && onPreview != null) ...[
                actionTile(
                  icon: Icons.fullscreen_rounded,
                  title: previewTitle,
                  subtitle: previewSubtitle,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await onPreview();
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),
              ],
              actionTile(
                icon: Icons.camera_alt_rounded,
                title: cameraTitle,
                subtitle: cameraSubtitle,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await onCamera();
                },
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              actionTile(
                icon: Icons.photo_library_rounded,
                title: galleryTitle,
                subtitle: gallerySubtitle,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await onGallery();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}
