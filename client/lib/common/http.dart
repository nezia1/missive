import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl:
      const String.fromEnvironment('API_URL', defaultValue: 'localhost/api/v1'),
  headers: {
    'Content-Type': 'application/json',
  },
  connectTimeout: const Duration(seconds: 5),
));
