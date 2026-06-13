import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../models/profile.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    return response;
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Get user profile
  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Create profile
  Future<Profile> createProfile({
    required String id,
    required String username,
    String? avatarUrl,
  }) async {
    final response = await _client.from('profiles').insert({
      'id': id,
      'username': username,
      'avatar_url': avatarUrl,
      'is_premium': false,
    }).select().single();
    return Profile.fromJson(response);
  }

  // Update profile
  Future<Profile> updateProfile({
    required String id,
    String? username,
    String? avatarUrl,
  }) async {
    final response = await _client
        .from('profiles')
        .update({
          if (username != null) 'username': username,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', id)
        .select()
        .single();
    return Profile.fromJson(response);
  }

  // Stream auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
