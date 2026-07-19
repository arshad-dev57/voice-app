import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';

class AuthState {
  final AppUser? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AppUser? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(AuthState()) {
    checkAuthStatus();
  }

  /// Restores the session. Prefers the live Firebase user; falls back to the
  /// last locally-saved user so the app still works offline.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    final firebase = _ref.read(firebaseServiceProvider);
    final repo = _ref.read(localRepositoryProvider);

    final fbUser = firebase.currentUser;
    if (fbUser != null) {
      final user = AppUser(
        id: fbUser.uid,
        name: fbUser.displayName ?? (fbUser.email?.split('@').first ?? 'User'),
        email: fbUser.email ?? '',
        isAuthenticated: true,
        createdAt: DateTime.now(),
      );
      await repo.clearAuthUsers();
      await repo.saveUser(user);
      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
      return;
    }

    // Offline fallback: use the locally cached user if present.
    final localUser = await repo.getCurrentUser();
    if (localUser != null) {
      state = AuthState(
        currentUser: localUser,
        isAuthenticated: true,
        isLoading: false,
      );
    } else {
      state = AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true);

    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = AuthState(
        isLoading: false,
        errorMessage: 'Fields cannot be empty.',
      );
      return false;
    }

    final firebase = _ref.read(firebaseServiceProvider);
    final repo = _ref.read(localRepositoryProvider);

    try {
      final fbUser = await firebase.signIn(email: email, password: password);
      if (fbUser == null) {
        state = AuthState(isLoading: false, errorMessage: 'Login failed.');
        return false;
      }

      final user = AppUser(
        id: fbUser.uid,
        name: fbUser.displayName ?? email.split('@').first,
        email: fbUser.email ?? email,
        isAuthenticated: true,
        createdAt: DateTime.now(),
      );

      await repo.clearAuthUsers();
      await repo.saveUser(user);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthState(isLoading: false, errorMessage: _authError(e));
      return false;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: 'Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true);

    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.trim().isEmpty) {
      state = AuthState(
        isLoading: false,
        errorMessage: 'Fields cannot be empty.',
      );
      return false;
    }

    final firebase = _ref.read(firebaseServiceProvider);
    final repo = _ref.read(localRepositoryProvider);

    try {
      final fbUser = await firebase.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (fbUser == null) {
        state = AuthState(isLoading: false, errorMessage: 'Sign up failed.');
        return false;
      }

      final user = AppUser(
        id: fbUser.uid,
        name: name.trim(),
        email: email.trim(),
        isAuthenticated: true,
        createdAt: DateTime.now(),
      );

      await repo.clearAuthUsers();
      await repo.saveUser(user);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthState(isLoading: false, errorMessage: _authError(e));
      return false;
    } catch (e) {
      state = AuthState(isLoading: false, errorMessage: 'Sign up error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final firebase = _ref.read(firebaseServiceProvider);
    final repo = _ref.read(localRepositoryProvider);
    try {
      await firebase.signOut();
    } catch (_) {}
    await repo.clearAuthUsers();
    state = AuthState(isAuthenticated: false, isLoading: false);
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);
