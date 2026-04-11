import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/UserModel.dart';

class UserInfoBottomSheet extends StatelessWidget {
  final UserModel user;

  const UserInfoBottomSheet({Key? key, required this.user}) : super(key: key);

  static void show(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserInfoBottomSheet(user: user),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  void _openPhotoZoom(BuildContext context) {
    if (user.profilePicture == null || user.profilePicture!.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                PhotoView(
                  imageProvider: CachedNetworkImageProvider(user.profilePicture!),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: const PhotoViewHeroAttributes(tag: 'user-avatar'),
                ),
                Positioned(
                  top: 48,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1976D2);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar + close button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: Colors.grey[500],
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Compact header row ──────────────────────────────────
                  Row(
                    children: [
                      // Tappable avatar with hero tag
                      GestureDetector(
                        onTap: () => _openPhotoZoom(context),
                        child: Hero(
                          tag: 'user-avatar',
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: primaryColor.withOpacity(0.25),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: user.profilePicture != null &&
                                      user.profilePicture!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: user.profilePicture!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey[100],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => _buildDefaultAvatar(),
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Name + badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayFullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1D26),
                              ),
                            ),
                            if (user.isProUser) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_rounded,
                                        size: 13, color: primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.userStatus,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Zoom hint icon
                      if (user.profilePicture != null &&
                          user.profilePicture!.isNotEmpty)
                        GestureDetector(
                          onTap: () => _openPhotoZoom(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in_rounded,
                                size: 20, color: Color(0xFF7F8C8D)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Info Rows ────────────────────────────────────────────
                  _buildInfoRow(
                    icon: Icons.phone_rounded,
                    label: "Téléphone",
                    value: (user.phone == null || user.phone!.isEmpty || user.phone == 'null')
                        ? "Numéro de téléphone non renseigné"
                        : user.phone!,
                    onTap: (user.phone != null && user.phone!.isNotEmpty && user.phone != 'null')
                        ? () => _makePhoneCall(user.phone!)
                        : null,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.email_rounded,
                    label: "Email",
                    value: user.email ?? "Non renseigné",
                    onTap: user.email != null
                        ? () => _sendEmail(user.email!)
                        : null,
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    label: "Localisation",
                    value: user.formattedLocation.isNotEmpty
                        ? user.formattedLocation
                        : "Non renseigné",
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFF5F6FA),
      child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFFBDC3C7)),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF7F8C8D)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF7F8C8D),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1D26),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[100], indent: 60);
  }
}
