import 'package:flutter/foundation.dart';
import 'package:machuco/database/model/notification/notification.dart';
import 'package:machuco/database/repository/notification/notification_repository.dart';
import 'package:machuco/models/notification/notification_model.dart';
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({
    this.recipientUser,
    NotificationRepository? repository,
    LocalPreferencesService? preferences,
  }) : _repository = repository ?? NotificationRepository(),
       _preferences =
           preferences ??
           SharedPreferencesLocalService(namespace: 'notification') {
    ready = load();
  }

  static const demoClientUser = 'laura@machuco.com';
  static const demoOwnerUser = 'owner-1020304050';
  static const _lastTypeFilterIdKey = 'lastTypeFilterId';

  final String? recipientUser;
  final NotificationRepository _repository;
  final LocalPreferencesService _preferences;
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
      final entries = recipientUser == null
          ? await _repository.findAllNotifications()
          : await _repository.findNotificationsForRecipient(recipientUser!);
      final readIds = recipientUser == null
          ? <int>{}
          : await _repository.findReadNotificationIds(recipientUser!);

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
      _notifications = _toAppNotifications(entries, readIds);
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
    final userId = recipientUser;
    if (userId == null || !notification.isUnread) return;
    await _repository.markAsRead(
      notificationId: notification.id,
      userId: userId,
    );
    await _loadLocalNotifications();
  }

  Future<void> markAllRead() async {
    final userId = recipientUser;
    if (userId == null) return;
    for (final notification in _notifications.where((item) => item.isUnread)) {
      await _repository.markAsRead(
        notificationId: notification.id,
        userId: userId,
      );
    }
    await _loadLocalNotifications();
  }

  Future<void> addNotification({
    required NotificationType type,
    required String title,
    required String message,
    required NotificationTarget target,
    String? recipientUser,
  }) async {
    if (_isSaving) throw StateError('Ya se está guardando una notificación');
    if (title.trim().isEmpty || message.trim().isEmpty) {
      throw ArgumentError('El título y el mensaje son obligatorios');
    }
    if (target == NotificationTarget.specificUser &&
        (recipientUser == null || recipientUser.trim().isEmpty)) {
      throw ArgumentError('El destinatario es obligatorio');
    }
    _isSaving = true;
    _notify();
    try {
      await _repository.saveNotification(
        typeId: type.id,
        title: title,
        message: message,
        target: target,
        recipientUser: recipientUser,
      );
      await _loadLocalNotifications();
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  Future<void> _loadLocalNotifications() async {
    final entries = recipientUser == null
        ? await _repository.findAllNotifications()
        : await _repository.findNotificationsForRecipient(recipientUser!);
    final readIds = recipientUser == null
        ? <int>{}
        : await _repository.findReadNotificationIds(recipientUser!);
    _notifications = _toAppNotifications(entries, readIds);
    _notify();
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
            isUnread: recipientUser != null && !readIds.contains(id),
            target: NotificationTarget.values.byName(entry.target),
            recipientUser: entry.recipientUser,
          );
        })
        .toList(growable: false);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
