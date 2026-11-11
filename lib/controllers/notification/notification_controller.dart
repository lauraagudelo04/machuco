import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:machuco/database/model/notification/notification.dart';
import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/models/notification/notification_model.dart';
import 'package:machuco/repositories/notification/notification_cloud_repository.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

class NotificationDeliveryException implements Exception {
  const NotificationDeliveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationController extends ChangeNotifier {
  NotificationController({
    this.recipientUid,
    this.recipientRole = 'client',
    NotificationRepository? repository,
    this.cloudRepository,
    LocalPreferencesService? preferences,
  }) : _repository = repository ?? NotificationRepository(),
       _preferences =
           preferences ??
           SharedPreferencesLocalService(namespace: 'notification') {
    ready = load();
  }

  static const demoClientUser = 'laura@machuco.com';
  static const _lastTypeFilterIdKey = 'lastTypeFilterId';

  final String? recipientUid;
  final String recipientRole;
  final NotificationRepository _repository;
  final LocalPreferencesService _preferences;
  final NotificationCloudRepository? cloudRepository;
  late final Future<void> ready;

  List<AppNotification> _notifications = const [];
  List<NotificationType> _types = const [];
  int? _selectedTypeId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _disposed = false;
  String? _errorMessage;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<NotificationType> get types => List.unmodifiable(_types);
  int? get selectedTypeId => _selectedTypeId;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((item) => item.isUnread).length;

  List<AppNotification> get filteredNotifications {
    if (_selectedTypeId == null) return notifications;
    return _notifications
        .where((notification) => notification.typeId == _selectedTypeId)
        .toList(growable: false);
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      try {
        final types = await _repository.findTypes();
        final filterId = await _preferences.getInt(_lastTypeFilterIdKey);
        _types = types;
        _selectedTypeId = types.any((type) => type.id == filterId)
            ? filterId
            : null;
      } on NotificationRepositoryException catch (error) {
        _types = const [];
        _selectedTypeId = null;
        _errorMessage = error.message;
      }
      await _loadLocalNotifications();
    } on NotificationRepositoryException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'No se pudieron cargar las notificaciones.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> selectType(int? typeId) async {
    _selectedTypeId = typeId;
    if (typeId == null) {
      await _preferences.remove(_lastTypeFilterIdKey);
    } else {
      await _preferences.setInt(_lastTypeFilterIdKey, typeId);
    }
    _notify();
  }

  Future<void> markAsRead(AppNotification notification) async {
    final userId = recipientUid;
    if (userId == null || !notification.isUnread) return;
    final remoteId = notification.remoteId;
    if (remoteId != null) {
      await (cloudRepository ?? NotificationCloudRepository()).markRead(
        uid: userId,
        notificationId: remoteId,
      );
    }
    await _repository.markAsRead(
      notificationId: notification.id,
      userId: userId,
    );
    await _loadLocalNotifications();
  }

  Future<void> markAllRead() async {
    final userId = recipientUid;
    if (userId == null) return;
    for (final notification in _notifications.where((item) => item.isUnread)) {
      await markAsRead(notification);
    }
  }

  Future<void> addNotification({
    required NotificationType type,
    required String title,
    required String message,
    required NotificationTarget target,
    String? recipientUid,
    String? recipientName,
    String? recipientEmail,
    String? remoteId,
  }) async {
    if (_isSaving) throw StateError('Ya se está guardando una notificación');
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('El título y el mensaje son obligatorios');
    }
    if (target == NotificationTarget.specificUser &&
        (recipientUid == null || recipientUid.trim().isEmpty)) {
      throw ArgumentError('El destinatario es obligatorio');
    }
    _isSaving = true;
    _notify();
    try {
      final deliveryId =
          remoteId ??
          'manual-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
      await _repository.saveNotification(
        typeId: type.id,
        title: title,
        message: message,
        target: target,
        recipientUid: recipientUid,
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        remoteId: deliveryId,
        syncState: 'pending',
      );
      final actorUid = FirebaseAuth.instance.currentUser?.uid;
      if (actorUid != null) {
        await (cloudRepository ?? NotificationCloudRepository()).publishManual(
          type: type,
          title: title,
          message: message,
          target: target,
          actorUid: actorUid,
          recipientUid: recipientUid,
          recipientName: recipientName,
          recipientEmail: recipientEmail,
          remoteId: deliveryId,
        );
        await _repository.saveNotification(
          typeId: type.id,
          title: title,
          message: message,
          target: target,
          recipientUid: recipientUid,
          recipientName: recipientName,
          recipientEmail: recipientEmail,
          remoteId: deliveryId,
        );
      }
      await _loadLocalNotifications();
    } on NotificationCloudRepositoryException catch (error) {
      throw NotificationDeliveryException(error.message);
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> _loadLocalNotifications() async {
    await _syncCloudNotifications();
    final syncedEntries = recipientUid == null
        ? await _repository.findAllNotifications()
        : await _repository.findNotificationsForRecipient(
            recipientUid!,
            role: recipientRole,
          );
    final syncedReadIds = recipientUid == null
        ? <int>{}
        : await _repository.findReadNotificationIds(recipientUid!);
    _notifications = _hideHistoricalDuplicates(
      _toAppNotifications(syncedEntries, syncedReadIds),
    );
    _notify();
  }

  Future<void> _syncCloudNotifications() async {
    final uid = recipientUid;
    if (uid == null || uid.isEmpty) return;
    try {
      final cloud = cloudRepository ?? NotificationCloudRepository();
      final remote = await cloud.findInbox(uid: uid, role: recipientRole);
      final typesByCode = {for (final type in _types) type.code: type};
      for (final item in remote) {
        final type = typesByCode[item.eventType];
        final localId = await _repository.saveNotification(
          typeId: type?.id ?? 0,
          title: item.title,
          message: item.message,
          sentAt: item.createdAt,
          target: item.target,
          recipientUid: item.recipientUid,
          recipientName: item.recipientName,
          recipientEmail: item.recipientEmail,
          remoteId: item.id,
        );
        if (await cloud.isRead(uid: uid, notificationId: item.id)) {
          await _repository.markAsRead(notificationId: localId, userId: uid);
        }
      }
    } catch (_) {
      // The SQLite inbox remains available when Firestore is offline.
    }
  }

  List<AppNotification> _toAppNotifications(
    List<NotificationEntry> entries,
    Set<int> readIds,
  ) {
    final typesById = {for (final type in _types) type.id: type};
    return entries
        .map((entry) {
          final id = entry.id;
          if (id == null) {
            throw StateError('La notificación no tiene identificador');
          }
          return AppNotification(
            id: id,
            typeId: entry.typeId,
            type: typesById[entry.typeId],
            title: entry.title,
            message: entry.message,
            sentAt: entry.sentAt,
            isUnread: recipientUid != null && !readIds.contains(id),
            target: NotificationTarget.values.byName(entry.target),
            recipientUid: entry.recipientUid,
            recipientName: entry.recipientName,
            recipientEmail: entry.recipientEmail,
            remoteId: entry.remoteId,
          );
        })
        .toList(growable: false);
  }

  /// Los datos históricos ya pueden contener la misma emisión local y remota.
  /// Se ocultan sólo copias equivalentes emitidas en una ventana de cinco minutos.
  List<AppNotification> _hideHistoricalDuplicates(
    List<AppNotification> source,
  ) {
    final visible = <AppNotification>[];
    for (final item in source..sort((a, b) => b.sentAt.compareTo(a.sentAt))) {
      final duplicate = visible.any(
        (other) =>
            other.typeId == item.typeId &&
            other.title == item.title &&
            other.message == item.message &&
            other.target == item.target &&
            other.recipientUid == item.recipientUid &&
            other.sentAt.difference(item.sentAt).abs() <=
                const Duration(minutes: 5),
      );
      if (!duplicate) visible.add(item);
    }
    return visible;
  }

  Future<List<NotificationRecipient>> searchRecipients(String query) =>
      _repository.searchActiveRecipients(query);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
