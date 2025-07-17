import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/services/receipt_validation_service.dart';

void main() {
  test('validateReceipt returns true on success', () async {
    ReceiptValidationService.client = MockClient((request) async {
      return http.Response(jsonEncode({'valid': true}), 200);
    });

    final result = await ReceiptValidationService.validateReceipt(
      platform: 'ios',
      receiptData: 'data',
    );
    expect(result, isTrue);
  });

  test('validateReceipt returns false on failure', () async {
    ReceiptValidationService.client = MockClient((request) async {
      return http.Response(jsonEncode({'valid': false}), 200);
    });

    final result = await ReceiptValidationService.validateReceipt(
      platform: 'android',
      receiptData: 'data',
    );
    expect(result, isFalse);
  });
}
