import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_client.dart';

/// Authentication state.
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// Auth state notifier managing login/register/logout.
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api = ApiClient();

  AuthNotifier() : super(const AuthState()) {
    checkAuth();
  }

  /// Check if user has a stored token and is authenticated.
  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final hasToken = await _api.hasToken();
      if (!hasToken) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final response = await _api.getMe();
      final user = User.fromJson(response.data);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      await _api.clearToken();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Register a new user.
  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await _api.register({
        'email': email,
        'username': username.isNotEmpty ? username : email.split('@')[0],
        'password': password,
        'password_confirm': password,
      });

      final token = response.data['token'];
      await _api.saveToken(token);

      final user = User.fromJson(response.data['user']);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
      return false;
    }
  }


  /// Login user.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _api.login(email: email, password: password);
      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);
      await _api.saveToken(token);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      String msg = 'Invalid credentials. Please check your email and password.';
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: msg,
      );
      return false;
    }
  }

  /// Update user profile data.
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      var currentUser = state.user;
      if (currentUser == null) {
        final meResp = await _api.getMe();
        currentUser = User.fromJson(meResp.data);
        state = state.copyWith(status: AuthStatus.authenticated, user: currentUser);
      }
      await _api.updateUser(currentUser.id, data);
      // Refresh user data
      final response = await _api.getMe();
      final updatedUser = User.fromJson(response.data);
      state = state.copyWith(status: AuthStatus.authenticated, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }


  /// Logout.
  Future<void> logout() async {
    await _api.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _extractError(dynamic e) {
    if (e == null) return 'An unexpected error occurred.';
    final str = e.toString();
    if (str.contains('400')) {
      return 'Invalid credentials or request data. Please try again.';
    }
    if (str.contains('401')) {
      return 'Incorrect email or password. Please check your details.';
    }
    return 'Connection error. Please verify server is running.';
  }
}

/// Global auth provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
