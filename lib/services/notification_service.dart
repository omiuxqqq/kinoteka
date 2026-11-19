import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_logger.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
  }

  Future<bool> showWatchReminder(String movieTitle) async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      AppLogger.instance.w('Пользователь отклонил разрешение на уведомления');
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'kinoteka_reminders',
      'Напоминания о просмотре',
      channelDescription: 'Уведомления о запланированных фильмах',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Время кино!',
      'Не забудьте посмотреть: «$movieTitle»',
      const NotificationDetails(android: androidDetails),
    );
    AppLogger.instance.i('Отправлено напоминание для фильма');
    return true;
  }
}