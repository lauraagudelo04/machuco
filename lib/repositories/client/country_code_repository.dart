import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/client/phone_country_code.dart';

class CountryCodeRepository {
  static const _baseUrl = 'https://ogrbbuwtsyezegkpwtsl.supabase.co/rest/v1/phone_country_codes?select=*';
  static const _apiKey = 'sb_publishable_Wv16MVxsTzA89lBeocarLQ_YL33Ya_E';

  Future<List<PhoneCountryCode>> getActiveCountryCodes() async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'apikey': _apiKey,
        'Authorization': 'Bearer $_apiKey',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => PhoneCountryCode.fromJson(json))
          .where((code) => code.active)
          .toList();
    } else {
      throw Exception('Error al cargar los códigos de país desde Supabase');
    }
  }
}