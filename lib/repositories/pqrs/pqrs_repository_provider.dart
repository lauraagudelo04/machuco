import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/repository/auth/user_profile_repository.dart';
import 'package:machuco/database/repository/image_format/pqrs_validation_repository.dart';
import 'package:machuco/database/repository/image_format/supabase_pqrs_validation_repository.dart';
import 'package:machuco/database/repository/pqrs/firestore_pqrs_repository.dart';
import 'package:machuco/database/repository/pqrs/pqrs_repository.dart';
import 'package:machuco/database/repository/pqrs/synced_pqrs_repository.dart';
import 'package:machuco/database/repository/pqrs_type/pqrs_type_repository.dart';
import 'package:machuco/database/repository/pqrs_type/supabase_pqrs_type_repository.dart';
import 'package:machuco/models/auth/account_status.dart';
import 'package:machuco/models/auth/registered_user.dart';
import 'package:machuco/models/booking/booking.dart';
import 'package:machuco/models/pqrs/pqrs.dart';
import 'package:machuco/models/pqrs/pqrs_motel_option.dart';
import 'package:machuco/models/pqrs/pqrs_session.dart';
import 'package:machuco/repositories/booking/booking_repository.dart';
import 'package:machuco/service/firebase/current_user.dart';
import 'package:machuco/service/media/pqrs_photo_picker.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

/// Holds what the PQRS controllers need by default: the repository, the
/// configuration repositories, the motel list for the form and the photo
/// source.
///
/// Everything is `null` (or a safe default) until [useDatabase] runs, so
/// widget tests without Firebase never reach a real service.
class PqrsRepositoryProvider {
  const PqrsRepositoryProvider._();

  static PqrsRepository? instance;

  /// Allowed formats and photo settings (Supabase with cache and defaults).
  static PqrsValidationRepository? validation;

  /// Type catalog (Supabase with cache and defaults).
  static PqrsTypeRepository? types;

  /// Motels the client can file a PQRS against.
  static Future<List<PqrsMotelOption>> Function() motelOptions =
      _loadMotelOptions;

  /// Photo source; replaceable in tests.
  static PqrsPhotoPicker Function() photoPicker =
      ImagePickerPqrsPhotoPicker.new;

  /// uid of the signed-in user, or `null` without a session.
  static String? Function() currentUid = () => CurrentUser.uidOrNull;

  /// Role and name of the signed-in user, or `null` without a usable session
  /// (no uid, no profile or an account that is not active).
  static Future<PqrsSession?> Function() sessionResolver = _resolveSession;

  /// Composes the SQLite store synced with Firestore. Called once from `main`
  /// after Firebase and the local database are initialized.
  static Future<void> useDatabase() async {
    final database = await AppDatabaseProvider.database;
    instance = SyncedPqrsRepository(
      dao: database.pqrsDao,
      remote: FirestorePqrsRepository(),
      currentUid: () => currentUid(),
    );
    validation = SupabasePqrsValidationRepository(
      daoProvider: () async => database.allowedImageFormatDao,
      preferences: SharedPreferencesLocalService(namespace: 'pqrs'),
    );
    types = SupabasePqrsTypeRepository(
      daoProvider: () async => database.pqrsTypeDao,
    );
    // Not awaited: the app must not wait for the network at startup.
    unawaited(refreshConfiguration());
  }

  /// Reservation states that mean the client has a real link with the motel
  /// (not an unpaid or cancelled booking).
  static const _reservationStatusesForPqrs = {
    ReservationStatus.active,
    ReservationStatus.upcoming,
    ReservationStatus.completed,
  };

  /// Motels where the signed-in client has a reservation, one per motel and
  /// sorted by name. The motel stays listed even if it is no longer
  /// available, so a client can still file a PQRS about a past stay.
  static Future<List<PqrsMotelOption>> _loadMotelOptions() async {
    final uid = currentUid();
    if (uid == null) return const [];
    final reservations = await BookingRepositoryProvider.instance.getAll();
    final byMotel = <String, PqrsMotelOption>{};
    for (final reservation in reservations) {
      if (reservation.guestId != uid ||
          !_reservationStatusesForPqrs.contains(reservation.status)) {
        continue;
      }
      byMotel.putIfAbsent(
        reservation.motelId,
        () => PqrsMotelOption(
          id: reservation.motelId,
          name: reservation.motelName,
        ),
      );
    }
    return byMotel.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Reads the Supabase configuration (formats, settings and types) once so
  /// the cache is fresh for the session. Failures are ignored: the
  /// repositories fall back to the cache and then to the defaults.
  static Future<void> refreshConfiguration() async {
    try {
      await Future.wait([
        validation?.loadImageFormats() ?? Future<void>.value(),
        validation?.loadSettings() ?? Future<void>.value(),
        types?.loadTypes() ?? Future<void>.value(),
      ]);
    } on Object catch (error) {
      debugPrint('PQRS: config refresh ${error.runtimeType}');
    }
  }

  static Future<PqrsSession?> _resolveSession() async {
    final uid = currentUid();
    if (uid == null) return null;
    final profile = await FirestoreUserProfileRepository().getProfile(uid);
    if (profile == null || profile.accountStatus != AccountStatus.active) {
      return null;
    }
    return PqrsSession(
      uid: uid,
      role: switch (profile.role) {
        RegisteredUserRole.client => PqrsActor.client,
        RegisteredUserRole.owner => PqrsActor.owner,
        RegisteredUserRole.admin => PqrsActor.systemAdmin,
      },
      name: profile.fullName,
    );
  }
}
