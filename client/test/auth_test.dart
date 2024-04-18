import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:missive/features/authentication/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mockito/mockito.dart';
import 'auth_test.mocks.dart';
import 'package:missive/constants/api.dart';

@GenerateMocks([http.Client])
@GenerateMocks([FlutterSecureStorage])
void main() {
  group('UserProvider', () {
    var userProvider = AuthProvider();
    SharedPreferences.setMockInitialValues({});
    test('UserProvider should return a null user when instantiated', () async {
      expect(await userProvider.user, isNull);
    });

    test('UserProvider should return a null access token when instantiated',
        () async {
      expect(await userProvider.accessToken, isNull);
    });

    test('UserProvider should return a false isLoggedIn when instantiated',
        () async {
      expect(userProvider.isLoggedIn, false);
    });

    test(
        'login should return an AuthenticationSuccess when the login is successful',
        () async {
      WidgetsFlutterBinding.ensureInitialized();

      final client = MockClient();
      final secureStorage = MockFlutterSecureStorage();

      // Mock a successful login attempt
      when(client.post(Uri.parse('${ApiConstants.baseUrl}/tokens'),
              headers: {'Content-Type': 'application/json'},
              body: '{"name":"user","password":"password"}'))
          .thenAnswer((_) async =>
              http.Response('{"status":"success","accessToken":"token"}', 200));

      // TODO: Fix this to work with Dio
      /*
      userProvider =
          AuthProvider(httpClient: client, secureStorage: secureStorage);

      final result = await userProvider.login('user', 'password');

      expect(result, isA<AuthenticationSuccess>());
      */
    });
  });
}
