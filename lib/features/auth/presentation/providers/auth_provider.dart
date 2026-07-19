import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/errors/failure_messages.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Live authentication state — the single source of truth the router's
/// redirect logic watches to decide between the auth flow and the app.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return GetIt.I<AuthRepository>().authStateChanges;
});

/// Synchronous convenience: `true` once we know the user is signed in.
/// `false` while loading OR when signed out — the splash screen is
/// responsible for not committing to a route until [authStateProvider]
/// leaves its loading state.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

// ── Form state for Login / Sign-up screens ─────────────────────────────────

class AuthFormState {
  const AuthFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.isSuccess = false,
    this.resetEmailSent = false,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final bool isSuccess;
  final bool resetEmailSent;

  AuthFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool? isSuccess,
    bool? resetEmailSent,
    bool clearError = false,
  }) {
    return AuthFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      resetEmailSent: resetEmailSent ?? this.resetEmailSent,
    );
  }
}

class AuthNotifier extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _repo => GetIt.I<AuthRepository>();

  Future<void> signIn({required String email, required String password}) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await _repo.signInWithEmail(
      email: email.trim(),
      password: password,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: FailureMessages.fromFailure(failure),
      ),
      (_) => state = state.copyWith(isSubmitting: false, isSuccess: true),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await _repo.signUpWithEmail(
      email: email.trim(),
      password: password,
      displayName: displayName.trim(),
    );

    result.fold(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: FailureMessages.fromFailure(failure),
      ),
      (_) => state = state.copyWith(isSubmitting: false, isSuccess: true),
    );
  }

  Future<void> sendPasswordReset(String email) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);

    final result = await _repo.sendPasswordResetEmail(email.trim());

    result.fold(
      (failure) => state = state.copyWith(
        isSubmitting: false,
        errorMessage: FailureMessages.fromFailure(failure),
      ),
      (_) => state = state.copyWith(
        isSubmitting: false,
        resetEmailSent: true,
      ),
    );
  }

  Future<void> signOut() => _repo.signOut();

  /// Resets transient flags (isSuccess, resetEmailSent) after the screen
  /// has reacted to them — call from a listener right after navigation.
  void consumeSuccess() {
    state = state.copyWith(isSuccess: false, resetEmailSent: false);
  }
}

final authFormProvider = NotifierProvider<AuthNotifier, AuthFormState>(
  AuthNotifier.new,
);
