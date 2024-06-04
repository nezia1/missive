import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockito/mockito.dart';
import 'auth_test.mocks.dart';

@GenerateMocks([Dio])
@GenerateMocks([FlutterSecureStorage])
void main() {
  group('AuthProvider', () {
    final httpClient = MockDio();
    final secureStorage = MockFlutterSecureStorage();
    var userProvider =
        AuthProvider(httpClient: httpClient, secureStorage: secureStorage);
    SharedPreferences.setMockInitialValues({});
    test('AuthProvider should return a null user when instantiated', () async {
      when(secureStorage.read(key: 'accessToken'))
          .thenAnswer((_) => Future.value(null));
      expect(await userProvider.user, isNull);
    });

    test('AuthProvider should return a null access token when instantiated',
        () async {
      when(secureStorage.read(key: 'accessToken'))
          .thenAnswer((_) => Future.value(null));
      expect(await userProvider.accessToken, isNull);
    });

    test('AuthProvider should return a false isLoggedIn when instantiated',
        () async {
      expect(userProvider.isLoggedIn, false);
    });

    test(
        'login should return an AuthenticationSuccess when the login is successful',
        () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Mock a successful login attempt
      when(httpClient.post('/tokens', data: anyNamed('data')))
          .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/api/v1/tokens'),
              data: {
                'data': {'status': 'success', 'accessToken': 'token'}
              },
              statusCode: 200));

      final result = await userProvider.login('user', 'password');

      expect(result, isA<AuthenticationSuccess>());
    });
  });
}
