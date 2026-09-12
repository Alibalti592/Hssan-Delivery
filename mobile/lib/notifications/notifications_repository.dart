import '../core/api_client.dart';

/// Registers/unregisters this device's FCM token against the signed-in
/// account, so the backend knows where to push that account's
/// notifications (see PushNotificationService).
class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<void> registerDeviceToken(String token, {String? platform}) async {
    await _api.post('/api/notifications/device-token', {
      'token': token,
      if (platform != null) 'platform': platform,
    });
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _api.delete('/api/notifications/device-token', {'token': token});
  }
}
