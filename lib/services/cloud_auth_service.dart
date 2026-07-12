import 'dart:convert';
import 'dart:io';

import '../core/constants/env_config.dart';
import '../data/models/cloud_credentials.dart';
import 'thingd_service.dart';

class CloudAuthService {
  final ThingdService _local;

  static const _collection = 'config';
  static const _credsId = 'cloud_credentials';

  CloudAuthService(this._local);

  /// Save cloud credentials to local thingd.
  Future<void> saveCredentials(CloudCredentials creds) async {
    await _local.bridge.putObject(
      collection: _collection,
      id: _credsId,
      body: jsonEncode(creds.toJson()),
    );
  }

  /// Load cloud credentials.
  ///
  /// Priority: stored override > environment variables > null
  Future<CloudCredentials?> loadCredentials() async {
    // First check local thingd storage (user-entered override)
    final body = await _local.bridge.getObject(
      collection: _collection,
      id: _credsId,
    );
    if (body != null) {
      return CloudCredentials.fromJson(
          jsonDecode(body) as Map<String, dynamic>);
    }

    // Fall back to environment variables
    if (EnvConfig.hasCloudConfig) {
      return CloudCredentials(
        serverUrl: EnvConfig.cloudUrl,
        apiKey: EnvConfig.cloudApiKey,
        email: 'env',
        registeredAt: DateTime.now(),
      );
    }

    return null;
  }

  /// Whether the active credentials come from env vars (not a stored override).
  Future<bool> isUsingEnvConfig() async {
    final body = await _local.bridge.getObject(
      collection: _collection,
      id: _credsId,
    );
    if (body != null) return false;
    return EnvConfig.hasCloudConfig;
  }

  /// Clear stored cloud credentials (does not clear env vars).
  Future<void> clearCredentials() async {
    await _local.bridge.deleteObject(
      collection: _collection,
      id: _credsId,
    );
  }

  /// Ping the thingd.cloud health endpoint to verify connectivity.
  Future<bool> pingServer(String serverUrl, {String? apiKey}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('$serverUrl/v1/health');
      final request = await client.getUrl(uri);
      if (apiKey != null) {
        request.headers.set('Authorization', 'Bearer $apiKey');
      }
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Call a GET endpoint on thingd.cloud.
  Future<Map<String, dynamic>?> get(
    String serverUrl,
    String apiKey,
    String path,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$serverUrl$path');
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) return null;
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Call a POST endpoint on thingd.cloud.
  Future<Map<String, dynamic>?> post(
    String serverUrl,
    String apiKey,
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$serverUrl$path');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.add(utf8.encode(jsonEncode(data)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Call a PUT endpoint on thingd.cloud.
  Future<Map<String, dynamic>?> put(
    String serverUrl,
    String apiKey,
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final uri = Uri.parse('$serverUrl$path');
      final request = await client.putUrl(uri);
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'application/json');
      request.add(utf8.encode(jsonEncode(data)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
