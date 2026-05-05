// auth_service.dart
//
// Local auth using shared_preferences.
// Stores a map of  email → { name, passwordHash }  as JSON.
//
// No backend. Works fully offline. Data persists across app restarts.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _usersKey   = 'auth_users';
  static const _sessionKey = 'auth_session_email';

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// SHA-256 hash so we never store plain-text passwords.
  String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<Map<String, dynamic>> _readUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeUsers(Map<String, dynamic> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  // ── Sign Up ──────────────────────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName  = name.trim();

    if (trimmedName.isEmpty)  return 'Name cannot be empty.';
    if (trimmedEmail.isEmpty) return 'Email cannot be empty.';
    if (!trimmedEmail.contains('@')) return 'Enter a valid email address.';
    if (password.length < 6)  return 'Password must be at least 6 characters.';

    final users = await _readUsers();

    if (users.containsKey(trimmedEmail)) {
      return 'An account with this email already exists.';
    }

    users[trimmedEmail] = {
      'name': trimmedName,
      'passwordHash': _hash(password),
    };

    await _writeUsers(users);
    debugPrint('[Auth] Signed up: $trimmedEmail');
    return null; // success
  }

  // ── Login ────────────────────────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedEmail.isEmpty) return 'Email cannot be empty.';
    if (password.isEmpty)     return 'Password cannot be empty.';

    final users = await _readUsers();

    if (!users.containsKey(trimmedEmail)) {
      return 'No account found with this email.';
    }

    final stored = users[trimmedEmail] as Map;
    if (stored['passwordHash'] != _hash(password)) {
      return 'Incorrect password.';
    }

    // Persist session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, trimmedEmail);

    debugPrint('[Auth] Logged in: $trimmedEmail');
    return null; // success
  }

  // ── Session ──────────────────────────────────────────────────────────────────

  /// Returns the logged-in user's email, or null if not logged in.
  Future<String?> get currentEmail async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  /// Returns the logged-in user's display name, or null.
  Future<String?> get currentName async {
    final email = await currentEmail;
    if (email == null) return null;
    final users = await _readUsers();
    return (users[email] as Map?)?.cast<String, dynamic>()['name'] as String?;
  }

  /// True if a session exists.
  Future<bool> get isLoggedIn async => (await currentEmail) != null;

  /// Clears the session (logout).
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    debugPrint('[Auth] Logged out');
  }
}