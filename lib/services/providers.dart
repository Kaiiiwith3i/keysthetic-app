import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api.dart';

/// Overridden in main() with the loaded instance.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class Session {
  const Session({this.baseUrl, this.token, this.user, this.demo = false});
  final String? baseUrl, token;
  final User? user;
  final bool demo;

  bool get signedIn => demo || (token != null && user != null);
  String get role => user?.role ?? 'buyer';
}

const _kBase = 'session.base_url', _kToken = 'session.token', _kUser = 'session.user', _kDemo = 'session.demo';

class SessionNotifier extends Notifier<Session> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Session build() {
    final u = _p.getString(_kUser);
    final demo = _p.getBool(_kDemo) ?? false;
    return Session(
      baseUrl: _p.getString(_kBase),
      token: _p.getString(_kToken),
      user: u == null ? null : User.fromJson(jsonDecode(u) as Map<String, dynamic>),
      demo: demo,
    );
  }

  Future<void> setBaseUrl(String url) async {
    await _p.setString(_kBase, url);
    state = Session(baseUrl: url, token: state.token, user: state.user);
  }

  Future<void> clearBaseUrl() async {
    await _p.remove(_kBase);
    state = const Session();
  }

  Future<void> signIn(String token, User user) async {
    await _p.setString(_kToken, token);
    await _p.setString(_kUser, jsonEncode(user.toJson()));
    await _p.setBool(_kDemo, false);
    state = Session(baseUrl: state.baseUrl, token: token, user: user);
  }

  Future<void> signOut() async {
    await _p.remove(_kToken);
    await _p.remove(_kUser);
    await _p.setBool(_kDemo, false);
    state = Session(baseUrl: state.baseUrl);
  }

  /// Offline demo: loads the buyer from the bundle (fallback: a fake one).
  Future<void> enterDemo() async {
    await _p.setBool(_kDemo, true);
    state = Session(baseUrl: state.baseUrl, demo: true, user: await _demoUser());
  }

  /// Demo-only: look at the app as another role.
  void demoRole(String role) => state = Session(baseUrl: state.baseUrl, demo: true, user: state.user?.withRole(role));

  Future<void> exitDemo() async {
    await _p.setBool(_kDemo, false);
    state = Session(baseUrl: state.baseUrl);
  }

  Future<User> _demoUser() async {
    try {
      return await Api(demo: true).me();
    } catch (_) {
      return const User(id: 0, email: 'demo@keysthetic.demo', name: 'Demo Buyer', role: 'buyer', area: 'Demo City');
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session>(SessionNotifier.new);

final apiProvider = Provider<Api>((ref) {
  final s = ref.watch(sessionProvider);
  return Api(baseUrl: s.baseUrl, token: s.token, demo: s.demo);
});

/// `mediaImage(ref, url)`: live -> NetworkImage(base+url); demo -> AssetImage('assets/demo'+url).
ImageProvider mediaImage(WidgetRef ref, String url) => ref.read(apiProvider).mediaImage(url);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.values.firstWhere(
      (m) => m.name == ref.read(prefsProvider).getString('theme_mode'),
      orElse: () => ThemeMode.system);

  void set(ThemeMode m) {
    ref.read(prefsProvider).setString('theme_mode', m.name);
    state = m;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
