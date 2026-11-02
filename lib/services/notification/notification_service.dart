import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:haipee/utils/logger.dart';
import 'package:haipee/utils/utils.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';

/// Unified cross-platform notification service for Haipee.
///
/// Wraps [FlutterLocalNotificationsPlugin] with ergonomic high-level APIs
/// for download completions, media stream readiness, and general alerts,
/// strictly adhering to macOS, Windows, Linux, Android, and iOS standards.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService();

  @visibleForTesting
  static void setMockInstance(NotificationService? mockInstance) {
    _instance = mockInstance;
  }

  final FlutterLocalNotificationsPlugin _plugin;
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Android notification channels
  static const String downloadChannelId = 'haipee_downloads';
  static const String downloadChannelName = '下载通知';
  static const String downloadChannelDescription = 'Haipee 资源下载与分片合成完成通知';

  static const String streamChannelId = 'haipee_stream';
  static const String streamChannelName = '媒体流通知';
  static const String streamChannelDescription = 'Haipee 边下边播与媒体流预缓冲就绪通知';

  /// Initializes notification capabilities across all supported platforms.
  Future<void> initialize({
    void Function(NotificationResponse response)? onNotificationClick,
  }) async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: 'haipee',
        appUserModelId: 'io.github.hugetiny.haipee',
        guid: 'c7c5957b-7b56-4b47-b807-6a4a15a818c7',
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
        windows: windowsSettings,
      );

      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) async {
          HaipeeLogger().log(
            Level.info,
            '[NotificationService] Notification tapped: id=${response.id}, payload=${response.payload}',
          );
          if (Utils.isDesktop()) {
            try {
              await windowManager.show();
              await windowManager.focus();
            } catch (_) {}
          }
          onNotificationClick?.call(response);
        },
      );

      // Create Android channels if running on Android
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              downloadChannelId,
              downloadChannelName,
              description: downloadChannelDescription,
              importance: Importance.high,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              streamChannelId,
              streamChannelName,
              description: streamChannelDescription,
              importance: Importance.defaultImportance,
            ),
          );
        }
      }

      _isInitialized = true;
      HaipeeLogger().log(Level.info, '[NotificationService] Initialized successfully');
    } catch (e, stack) {
      HaipeeLogger().log(
        Level.warning,
        '[NotificationService] Failed to initialize notifications: $e\n$stack',
      );
    }
  }

  /// Explicitly requests notification permissions on platforms requiring it (macOS/iOS/Android 13+).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isMacOS) {
        final macosPlugin = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      } else if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      } else if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[NotificationService] Failed to request notification permission: $e',
      );
      return false;
    }
  }

  /// Displays a localized notification with platform-optimized presentation details.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? subtitle,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        subtitle: subtitle,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        subtitle: subtitle,
      ),
      android: const AndroidNotificationDetails(
        downloadChannelId,
        downloadChannelName,
        channelDescription: downloadChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: const WindowsNotificationDetails(),
      linux: const LinuxNotificationDetails(),
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      HaipeeLogger().log(
        Level.warning,
        '[NotificationService] Failed to post notification: $e',
      );
    }
  }

  /// Notifies the user that a download has completed.
  Future<void> showDownloadCompleted({
    required String taskName,
    String? savePath,
    int? id,
    String? payload,
  }) async {
    final notificationId = id ?? (taskName.hashCode.abs() % 100000);
    final body = (savePath != null && savePath.isNotEmpty)
        ? '已保存至: $savePath'
        : '全部文件已下载完成并已就绪';

    await showNotification(
      id: notificationId,
      title: '下载完成',
      subtitle: taskName,
      body: '$taskName\n$body',
      payload: payload ?? savePath,
    );
  }

  /// Notifies the user that a streaming media cache is ready for playback.
  Future<void> showStreamReady({
    required String title,
    int? id,
    String? payload,
  }) async {
    final notificationId = id ?? (title.hashCode.abs() % 100000);
    await showNotification(
      id: notificationId,
      title: '媒体流就绪',
      subtitle: title,
      body: '已缓冲足够数据，可以流畅在线播放',
      payload: payload,
    );
  }
}
