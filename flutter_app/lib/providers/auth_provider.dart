import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  bool get isLoggedIn => user != null;
  AuthState copyWith({User? user, bool? loading, String? error}) =>
      AuthState(user: user ?? this.user, loading: loading ?? this.loading, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> login(String username, String password) async {
    state = const AuthState(loading: true);
    try {
      final data = await ApiService.instance.post('/auth/login', {
        'username': username,
        'password': password,
      });
      await ApiService.instance.setToken(data['token']);
      state = AuthState(user: User.fromJson(data['user']));
    } on ApiException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: 'Connection failed. Check server URL.');
    }
  }

  Future<void> logout() async {
    await ApiService.instance.setToken(null);
    state = const AuthState();
  }

  Future<bool> tryAutoLogin() async {
    final token = await ApiService.instance.token;
    if (token == null) return false;
    try {
      final data = await ApiService.instance.get('/auth/me');
      state = AuthState(user: User.fromJson(data['user']));
      return true;
    } catch (_) {
      await ApiService.instance.setToken(null);
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
