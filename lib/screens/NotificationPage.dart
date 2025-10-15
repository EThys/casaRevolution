import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'Nouveau message',
      description: 'Vous avez reçu un message de Peter Mposhi',
      time: 'Il y a 5 min',
      icon: Icons.message_rounded,
      iconColor: Colors.blueAccent,
      isRead: false,
      category: 'Messages',
    ),
    NotificationItem(
      id: '2',
      title: 'Rappel de rendez-vous',
      description: 'Rendez-vous demain à 14h30',
      time: 'Il y a 1 heure',
      icon: Icons.calendar_today_rounded,
      iconColor: Colors.greenAccent,
      isRead: false,
      category: 'Agenda',
    ),
    NotificationItem(
      id: '3',
      title: 'Paiement confirmé',
      description: 'Votre paiement de 149\$ a été accepté',
      time: 'Il y a 3 heures',
      icon: Icons.payment_rounded,
      iconColor: Colors.greenAccent,
      isRead: true,
      category: 'Finances',
    ),
    NotificationItem(
      id: '4',
      title: 'Sécurité',
      description: 'Connexion détectée depuis un nouvel appareil',
      time: 'Il y a 6 heures',
      icon: Icons.security_rounded,
      iconColor: Colors.orangeAccent,
      isRead: true,
      category: 'Sécurité',
    ),
    NotificationItem(
      id: '5',
      title: 'Promotion spéciale',
      description: 'Profitez de -30% sur tous les services ce week-end',
      time: 'Il y a 1 jour',
      icon: Icons.local_offer_rounded,
      iconColor: Colors.purpleAccent,
      isRead: true,
      category: 'Promotions',
    ),
    NotificationItem(
      id: '6',
      title: 'Mise à jour disponible',
      description: 'Nouvelle version de l\'application Casa',
      time: 'Il y a 2 jours',
      icon: Icons.system_update_rounded,
      iconColor: Colors.blueAccent,
      isRead: true,
      category: 'Système',
    ),
  ];

  bool _showUnreadOnly = false;

  List<NotificationItem> get _filteredNotifications {
    if (_showUnreadOnly) {
      return _notifications.where((notification) => !notification.isRead).toList();
    }
    return _notifications;
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
    _showSuccessSnackbar('Toutes les notifications sont marquées comme lues');
  }

  void _toggleReadStatus(String id) {
    setState(() {
      final notification = _notifications.firstWhere((n) => n.id == id);
      notification.isRead = !notification.isRead;
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: EdgeInsets.only(left: 16, top: 8, bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor,
              primaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
          splashRadius: 20,
        ),
      ),
      title: Text(
        'Notifications',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primaryColor,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        if (_notifications.any((n) => !n.isRead))
          Container(
            margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 22),
              onPressed: _markAllAsRead,
              splashRadius: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_filteredNotifications.length} notification${_filteredNotifications.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showUnreadOnly = !_showUnreadOnly;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _showUnreadOnly
                    ? LinearGradient(
                  colors: [primaryColor, primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: _showUnreadOnly ? null : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: _showUnreadOnly ? Colors.white : Colors.grey[600],
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Non lues',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _showUnreadOnly ? Colors.white : Colors.grey[600],
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

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = _filteredNotifications[index];
        return _buildNotificationCard(notification);
      },
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
                        notification.time,
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
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color iconColor;
  bool isRead;
  final String category;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    required this.category,
  });
}

// Couleurs (à définir dans votre thème)
const Color darkBlue = Color(0xFF1A237E);
const Color primaryColor = Color(0xFF2196F3);