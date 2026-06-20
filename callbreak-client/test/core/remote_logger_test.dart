import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:callbreak_client/core/remote_logger.dart';

void main() {
  group('RemoteLogger', () {
    test('sends formatted payload to the backend without crashing', () async {
      // Arrange
      bool requestReceived = false;
      String? receivedBody;

      // Mock the HTTP client
      final mockClient = MockClient((request) async {
        requestReceived = true;
        receivedBody = request.body;
        return http.Response('', 200);
      });

      // Inject mock client
      RemoteLogger.httpClient = mockClient;

      // Act
      final testError = Exception('Test UI Exception');
      final testStack = StackTrace.fromString('Test StackTrace');
      
      // Call is synchronous and fire-and-forget
      RemoteLogger.logError(testError, testStack);

      // Give the event loop a tiny moment to process the microtask
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(requestReceived, isTrue);
      
      final payload = jsonDecode(receivedBody!);
      expect(payload['platform'], isNotNull);
      expect(payload['message'], 'Exception: Test UI Exception');
      expect(payload['stackTrace'], 'Test StackTrace');
    });

    test('fails silently if HTTP request throws an exception', () async {
      // Arrange
      bool threwException = false;

      // Mock the HTTP client to explicitly throw an error (e.g. no internet)
      final mockClient = MockClient((request) async {
        throw Exception('Network completely disconnected');
      });

      RemoteLogger.httpClient = mockClient;

      // Act & Assert (Should not throw outside logError)
      try {
        RemoteLogger.logError(Exception('Some error'), null);
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        threwException = true;
      }

      // We assert that the exception inside the HTTP call did NOT bubble up 
      // and crash the caller.
      expect(threwException, isFalse);
    });
  });
}
