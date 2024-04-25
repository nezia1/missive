import 'package:dio/dio.dart';
import 'package:missive/constants/api.dart';

final dio = Dio(BaseOptions(
  baseUrl:
      const String.fromEnvironment('API_URL', defaultValue: 'localhost/api/v1'),
  headers: {
    'Content-Type': 'application/json',
  },
  connectTimeout: const Duration(seconds: 5),
));
