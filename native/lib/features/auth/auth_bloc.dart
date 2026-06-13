import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile.dart';
import 'auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
    on<AuthResetPasswordRequested>(_onAuthResetPasswordRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = _authRepository.currentUser;
      if (user != null) {
        final profile = await _authRepository.getProfile(user.id);
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        username: event.username,
      );

      if (response.user != null) {
        // Try to create profile — may fail if email confirmation is required
        // Profile will be created on first login if it doesn't exist
        try {
          await _authRepository.createProfile(
            id: response.user!.id,
            username: event.username,
          );
        } catch (_) {
          // Profile creation will be retried on login
        }
        emit(AuthSignUpSuccess());
      } else {
        emit(AuthError('Sign up failed'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final response = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        Profile? profile = await _authRepository.getProfile(response.user!.id);
        // If profile doesn't exist yet, create it now (e.g. after email confirmation)
        if (profile == null) {
          final username = response.user!.email?.split('@').first ?? 'user';
          profile = await _authRepository.createProfile(
            id: response.user!.id,
            username: username,
          );
        }
        emit(AuthAuthenticated(profile));
      } else {
        emit(AuthError('Sign in failed'));
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('email_not_confirmed')) {
        emit(AuthError('Potwierdź adres email — sprawdź skrzynkę pocztową i kliknij link weryfikacyjny.'));
      } else if (errorStr.contains('Invalid login credentials')) {
        emit(AuthError('Nieprawidłowy email lub hasło.'));
      } else {
        emit(AuthError(errorStr));
      }
    }
  }

  Future<void> _onAuthSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onAuthResetPasswordRequested(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.resetPassword(event.email);
      emit(AuthResetPasswordSuccess());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
