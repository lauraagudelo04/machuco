import 'package:flutter/foundation.dart';
import 'package:machuco/database/app_database.dart';
import 'package:machuco/database/model/phone_country_code/phone_country_code.dart';
import 'package:machuco/database/repository/motel/phone_country_code_repository.dart';
import 'package:machuco/service/phone_country_code/supabase_phone_country_code_config.dart';

/// Conecta la presentación del maestro de códigos telefónicos de país con su
/// repositorio (Supabase + caché SQLite).
class PhoneCountryCodeController extends ChangeNotifier {
  PhoneCountryCodeController({required this.repository});

  factory PhoneCountryCodeController.fromEnvironment({AppDatabase? database}) {
    final appDatabaseFuture = database == null
        ? AppDatabaseProvider.database
        : Future.value(database);
    return PhoneCountryCodeController(
      repository: PhoneCountryCodeRepository(
        baseUrl: SupabasePhoneCountryCodeConfig.baseUrl,
        apiKey: SupabasePhoneCountryCodeConfig.apiKey,
        daoProvider: () async => (await appDatabaseFuture).phoneCountryCodeDao,
      ),
    );
  }

  final PhoneCountryCodeRepository repository;
  List<PhoneCountryCode> _countryCodes = const [];
  bool _isLoading = false;
  String? _error;

  List<PhoneCountryCode> get countryCodes => List.unmodifiable(_countryCodes);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Carga el maestro usando la caché local cuando existe.
  Future<void> load({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _countryCodes = await repository.getCountryCodes(
        forceRefresh: forceRefresh,
      );
    } on PhoneCountryCodeRepositoryException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'No fue posible cargar los códigos telefónicos de país';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fuerza la consulta al maestro remoto e ignora la caché.
  Future<void> refresh() => load(forceRefresh: true);
}