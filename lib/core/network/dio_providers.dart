import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'dio_client.dart';

/// Provides the configured [Dio] instance with all interceptors.
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(hiveStorageProvider);
  return createDioClient(storage);
});
