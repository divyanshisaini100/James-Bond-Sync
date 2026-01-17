import 'package:background_fetch/background_fetch.dart';

class BackgroundTaskService {
  bool _configured = false;

  Future<void> configure({required Future<void> Function() onFetch}) async {
    if (_configured) {
      return;
    }
    _configured = true;
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: NetworkType.ANY,
      ),
      (taskId) async {
        await onFetch();
        BackgroundFetch.finish(taskId);
      },
      (taskId) async {
        BackgroundFetch.finish(taskId);
      },
    );
  }
}
