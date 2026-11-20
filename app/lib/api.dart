/// The review server over HTTP: pairing, the round, feedback, pictures.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logo_review/models.dart';
import 'package:logo_review/past.dart';

/// The server's address; a test build may point elsewhere.
const String defaultBase = String.fromEnvironment(
  'LOGO_REVIEW_URL',
  defaultValue: 'https://logos.kuhy.duckdns.org',
);

/// The server answered, but not with what was asked for.
class ApiException implements Exception {
  /// A failure with the server's [status].
  const new(this.status, this.path);

  /// The HTTP status.
  final int status;

  /// The path asked for.
  final String path;

  /// Whether the device key was refused (never paired, or unpaired since).
  bool get refused => status == 401 || status == 403;

  @override
  String toString() => 'ApiException($status $path)';
}

/// Talks to one review server as one paired device.
class ReviewApi {
  /// Requests go through [client] to [base], carrying the device [token].
  new(this.client, {this.base = defaultBase, this.token = ''});

  /// The HTTP client.
  final http.Client client;

  /// The server's address, without a trailing slash.
  final String base;

  /// This device's key; empty until paired.
  String token;

  /// The headers that open the server to this device.
  Map<String, String> get headers => {
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  /// The address of [path].
  Uri url(String path) => Uri.parse('$base$path');

  Future<http.Response> _checked(
    String path,
    Future<http.Response> sent,
  ) async {
    final res = await sent.timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw ApiException(res.statusCode, path);
    return res;
  }

  Future<Json> _get(String path) async {
    final res = await _checked(path, client.get(url(path), headers: headers));
    return asObject(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<Json> _post(String path, Object body, {String? type}) async {
    final res = await _checked(
      path,
      client.post(
        url(path),
        headers: {...headers, 'Content-Type': type ?? 'application/json'},
        body: type == null ? jsonEncode(body) : body,
      ),
    );
    return asObject(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Trades the six-digit [code] from the computer for this device's key.
  Future<String> pair(String code) async =>
      token = '${(await _post('/api/pair', {'code': code}))['token']}';

  /// The round on show.
  Future<Manifest> manifest() async =>
      Manifest.fromJson(await _get('/api/manifest'));

  /// The saved feedback.
  Future<ReviewState> state() async =>
      ReviewState.fromJson(await _get('/api/state'));

  /// The designs' earlier rounds.
  Future<History> history() async =>
      History.fromJson(await _get('/api/history'));

  /// The designer's rationale and answers.
  Future<Designer> designer() async =>
      Designer.fromJson(await _get('/api/claude'));

  /// Replaces the saved feedback.
  Future<void> save(ReviewState state) async {
    const path = '/api/state';
    await _checked(
      path,
      client.put(url(path), headers: headers, body: jsonEncode(state)),
    );
  }

  /// The bytes of the picture at [path].
  Future<Uint8List> picture(String path) async =>
      (await _checked(path, client.get(url(path), headers: headers))).bodyBytes;

  /// Uploads a reference picture; returns the name the server filed it under.
  Future<String> uploadRef(Uint8List bytes, String mime) async =>
      '${(await _post('/api/ref', bytes, type: mime))['file']}';

  /// Files one error report on the computer.
  Future<void> report(Json entry) => _post('/api/error', entry);
}
