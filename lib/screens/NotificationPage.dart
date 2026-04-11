import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:casa/controllers/NotificationController.dart';
import '../utils/Routes.dart';
import '../models/ServiceRequestModel.dart';
import 'ServiceRequestDetailPage.dart';
import '../controllers/AuthentificationCtrl.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Suppression de la liste statique _notifications
  bool _showUnreadOnly = false;

  void _markAllAsRead() {
    Provider.of<NotificationController>(context, listen: false).markAllAsRead();
    _showSuccessSnackbar('Toutes les notifications sont marquées comme lues');
  }

  void _toggleReadStatus(String id) {
    // Géré via tap sur item
  }

  void _deleteNotification(String id) {
    Provider.of<NotificationController>(context, listen: false).deleteNotification(id);
    _showSuccessSnackbar('Notification supprimée');
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    } else if (difference.inDays >= 1) {
      return "Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}";
    } else if (difference.inHours >= 1) {
      return "Il y a ${difference.inHours} h";
    } else if (difference.inMinutes >= 1) {
      return "Il y a ${difference.inMinutes} min";
    } else {
      return "À l'instant";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCtrl = Provider.of<AuthentificationCtrl>(context);
    
    if (authCtrl.token.isEmpty) {
      return _buildNotConnectedView();
    }

    return Consumer<NotificationController>(
      builder: (context, controller, child) {
        // Filtrer les notifications
        List<NotificationItem> displayedNotifications = controller.notifications;
        if (_showUnreadOnly) {
          displayedNotifications = displayedNotifications.where((n) => !n.isRead).toList();
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: _buildAppBar(controller),
          body: Column(
            children: [
              _buildFilterSection(displayedNotifications.length),
              Expanded(
                child: displayedNotifications.isEmpty
                    ? _buildEmptyState()
                    : _buildNotificationsList(displayedNotifications),
              ),
            ],
          ),
        );
      }
    );
  }

  PreferredSizeWidget _buildAppBar(NotificationController controller) {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
        onPressed: () => Navigator.of(context).pop(),
        splashRadius: 20,
      ),
      title: Text(
        'Notifications',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        if (controller.notifications.any((n) => !n.isRead))
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
            label: Text(
              "Tout lu",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16),
              foregroundColor: Colors.white, 
            ),
          )
      ],
    );
  }

  Widget _buildFilterSection(int displayedCount) {
    final unreadCount = Provider.of<NotificationController>(context, listen: false).unreadCount;
    
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$unreadCount non lues • Total $displayedCount',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showUnreadOnly ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _showUnreadOnly ? primaryColor : Colors.grey[300]!,
                ),
                 boxShadow: [
                  if (!_showUnreadOnly)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: _showUnreadOnly ? Colors.white : Colors.grey[700],
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Non lues',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _showUnreadOnly ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<NotificationItem> displayedNotifications) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: displayedNotifications.length,
      itemBuilder: (context, index) {
        final notification = displayedNotifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  void _handleNotificationTap(NotificationItem notification) {
    final notifCtrl = Provider.of<NotificationController>(context, listen: false);
    notifCtrl.markAsRead(notification.id);

    final data = notification.data ?? {};
    final propertyId = data['propertyId'] ?? data['property_id'];

    if (propertyId != null) {
      Navigator.pushNamed(
        context,
        Routes.detailPageRoute,
        arguments: {'propertyId': propertyId},
      );
      return;
    }

    switch (notification.type) {
      case NotificationType.serviceRequest:
      case NotificationType.serviceResponse:
      case NotificationType.serviceAccepted:
      case NotificationType.serviceCompleted:
        if (data['requestId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceRequestDetailPage(
                request: ServiceRequestModel(requestId: data['requestId']),
              ),
            ),
          );
          return;
        }
        break;
      default:
        break;
    }

    notifCtrl.navigateFromNotificationPayload(
      data,
      titleFallback: notification.title,
      messageFallback: notification.description,
      openedFromInAppNotificationList: true,
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) => _deleteNotification(notification.id),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(16),
        child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
          border: notification.isRead
              ? null
              : Border.all(
            color: primaryColor,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon avec badge non lu
            Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: notification.iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.iconColor,
                    size: 22,
                  ),
                ),
                if (!notification.isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        _formatTimeAgo(notification.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    notification.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notification.category,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 12),
          Text(
            _showUnreadOnly
                ? 'Vous avez lu toutes vos notifications'
                : 'Vous n\'avez aucune notification pour le moment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 70,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Connectez-vous',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1D26),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connectez-vous pour voir vos notifications en temps réel et rester informé.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.loginRoute),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: primaryColor.withOpacity(0.3),
                  ),
                  child: Text(
                    'SE CONNECTER',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum NotificationType {
  message,
  appointment,
  payment,
  security,
  promotion,
  system,
  serviceRequest, // Nouvelle demande de service
  serviceResponse, // Nouvelle réponse à une demande
  serviceAccepted, // Demande acceptée
  serviceCompleted, // Service terminé
  warning,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color iconColor;
  bool isRead;
  final String category;
  final NotificationType type;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    required this.category,
    this.type = NotificationType.system,
    this.data,
  });
}

// Couleurs (à définir dans votre thème)
const Color darkBlue = Color(0xFF1A237E);
const Color primaryColor = Color(0xFF2196F3);