import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Talks to the game server (server/ on Vercel). The phone keeps a private
/// key it got when the player registered; every request carries it.
class Remote {
  Remote._(this._prefs);

  static const _credKey = 'qadam_qala_credentials_v1';
  final SharedPreferences _prefs;
  String? _uid;
  String? _secret;

  static Future<Remote> connect() async {
    final r = Remote._(await SharedPreferences.getInstance());
    final raw = r._prefs.getString(_credKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      r._uid = j['uid'] as String?;
      r._secret = j['secret'] as String?;
    }
    return r;
  }

  bool get hasAccount => _uid != null && _secret != null;
  String? get uid => _uid;

  /// Creates the account on the server and remembers its key on this phone.
  Future<Map<String, dynamic>> register(String name) async {
    final res = await _post('register', {'name': name}, auth: false);
    _uid = res['uid'] as String;
    _secret = res['secret'] as String;
    await _prefs.setString(_credKey, jsonEncode({'uid': _uid, 'secret': _secret}));
    return res;
  }

  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic>? data]) =>
      _post(action, data ?? const {}, auth: true);

  Future<void> saveFcmToken(String token) async {
    try {
      await call('saveFcmToken', {'token': token});
    } catch (_) {}
  }

  Future<void> forget() async {
    _uid = null;
    _secret = null;
    await _prefs.remove(_credKey);
  }

  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> data, {required bool auth}) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kServerUrl/api/$action'),
            headers: {
              'Content-Type': 'application/json',
              if (auth && hasAccount) 'Authorization': 'Bearer $_uid.$_secret',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const RemoteError("Internet aloqasi yo'q yoki server javob bermadi");
    }
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      throw RemoteError('Server xatosi (${res.statusCode})');
    }
    if (res.statusCode == 401) {
      await forget();
    }
    if (res.statusCode != 200) throw RemoteError(body['error'] as String? ?? 'Server xatosi');
    return body;
  }
}

class RemoteError implements Exception {
  const RemoteError(this.message);

  final String message;

  @override
  String toString() => message;
}
