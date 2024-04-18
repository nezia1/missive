import 'package:dio/dio.dart';
import 'package:missive/constants/api.dart';

final dio = Dio(BaseOptions(
  baseUrl: ApiConstants.baseUrl,
  headers: {
    'Content-Type': 'application/json',
  },
  connectTimeout: const Duration(seconds: 5),
));
