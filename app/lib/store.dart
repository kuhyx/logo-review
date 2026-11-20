/// Where this device's key lives between runs.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the device key.
abstract interface class TokenStore {
  /// The saved key, or empty.
  Future<String> read();

  /// Saves [token]; an empty one forgets the pairing.
  Future<void> write(String token);
}

/// The Android keystore.
class SecureTokenStore implements TokenStore {
  /// Wraps the platform store.
  const new([this._storage = const FlutterSecureStorage()]);

  static const _key = 'device_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String> read() async => await _storage.read(key: _key) ?? '';

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
}

/// A store for tests and previews.
class MemoryTokenStore implements TokenStore {
  /// Starts with [token].
  new([this.token = '']);

  /// The key held.
  String token;

  @override
  Future<String> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}
