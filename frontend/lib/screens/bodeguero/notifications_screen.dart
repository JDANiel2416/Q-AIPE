import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'bodeguero_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _userId = "";

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final uid = await SessionService().getUserId();
    if (uid != null) {
      _userId = uid;
      final data = await _api.getNotifications(uid);
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    // Optimistic update
    setState(() {
      notification.isRead = true;
    });

    await _api.markNotificationRead(_userId, notification.id);
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var n in _notifications) {
        n.isRead = true;
      }
    });
    await _api.markAllNotificationsRead(_userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BColors.background(context),
      appBar: AppBar(
        title: Text(
          "Notificaciones",
          style: TextStyle(
            color: BColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: BColors.primary(context)),
        actions: [
          IconButton(
            icon: Icon(Icons.done_all, color: BColors.primary(context)),
            onPressed: _markAllAsRead,
            tooltip: "Marcar todas como leídas",
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: BColors.primary(context)),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: BColors.textMuted(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No tienes notificaciones",
                    style: TextStyle(color: BColors.textSecondary(context)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationCard(notification);
              },
            ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    Color iconColor = BColors.primary(context);
    IconData iconData = Icons.info_outline;

    if (notification.type == 'STOCK_ALERT') {
      iconColor = BColors.error;
      iconData = Icons.production_quantity_limits;
    } else if (notification.type == 'WARNING') {
      iconColor = BColors.warning;
      iconData = Icons.warning_amber_rounded;
    } else if (notification.type == 'NEW_ORDER') {
      iconColor = Colors.green; // Hardcoded green for orders
      iconData = Icons.shopping_bag_outlined;
    }

    return Card(
      elevation: 0,
      color: notification.isRead
          ? BColors.surface(context)
          : BColors.primaryLight(context).withOpacity(0.5), // More visible
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notification.isRead
              ? Colors.transparent
              : BColors.primary(context).withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
            color: BColors.textPrimary(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(color: BColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification.createdAt),
              style: TextStyle(fontSize: 12, color: BColors.textMuted(context)),
            ),
          ],
        ),
        onTap: () {
          _markAsRead(notification);
          // Si es un pedido, podríamos navegar al detalle
          // if (notification.type == 'NEW_ORDER') { ... }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return "Hace ${diff.inMinutes} min";
    } else if (diff.inHours < 24) {
      return "Hace ${diff.inHours} horas";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}
