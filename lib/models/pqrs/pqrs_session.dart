import 'package:machuco/models/pqrs/pqrs.dart';

/// Who is acting on the PQRS module: uid, role and display name.
///
/// The role decides which actions the controller allows. That is only a
/// simulation for the UI: the real authorization is the Firestore rules.
class PqrsSession {
  const PqrsSession({
    required this.uid,
    required this.role,
    required this.name,
  });

  final String uid;
  final PqrsActor role;
  final String name;
}
