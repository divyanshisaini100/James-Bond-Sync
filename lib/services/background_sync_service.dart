import 'dart:io';

import 'package:flutter_background/flutter_background.dart';

class BackgroundSyncService {
  static const FlutterBackgroundAndroidConfig _androidConfig =
      FlutterBackgroundAndroidConfig(
    notificationTitle: 'Clipboard Sync Running',
    notificationText: 'Syncing clipboard in the background',
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
      name: 'ic_launcher',
      defType: 'mipmap',
    ),
  );

  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> enable() async {
    if (!Platform.isAndroid) {
      _enabled = true;
      return;
    }
    final initialized = await FlutterBackground.initialize(androidConfig: _androidConfig);
    if (!initialized) {
      return;
    }
    _enabled = await FlutterBackground.enableBackgroundExecution();
  }

  Future<void> disable() async {
    if (Platform.isAndroid) {
      await FlutterBackground.disableBackgroundExecution();
    }
    _enabled = false;
  }
}
