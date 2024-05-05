import 'package:dio/dio.dart';

/// The global Dio instance used for all HTTP requests.
final dio = Dio(BaseOptions(
  baseUrl:
      const String.fromEnvironment('API_URL', defaultValue: 'localhost/api/v1'),
  headers: {
    'Content-Type': 'application/json',
  },
  connectTimeout: const Duration(seconds: 5),
));
