import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple wrapper around backend receipt validation API.
class ReceiptValidationService {
  /// HTTP client used for requests. Can be replaced in tests.
  static http.Client client = http.Client();

  /// Endpoint called to validate receipts.
  static const String endpoint = 'https://example.com/verifyReceipt';

  /// Send receipt data to backend and return whether it is valid.
  static Future<bool> validateReceipt({
    required String platform,
    required String receiptData,
  }) async {
    final response = await client.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'platform': platform,
        'receiptData': receiptData,
      }),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);
      return json['valid'] == true;
    }
    return false;
  }
}
