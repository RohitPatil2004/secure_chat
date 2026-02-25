import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './Auth service.dart';
import '../Model/User model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  User? _firebaseUser;
  UserModel? _userProfile;
  String? _error;
  bool _isLoading = false;

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  String? get error => _error;
  bool get isLoading => _isLoading;
  String? get currentUserId => _firebaseUser?.uid;

  AuthProvider() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      _status = AuthStatus.authenticated;
      await _loadUserProfile(user.uid);
    } else {
      _status = AuthStatus.unauthenticated;
      _userProfile = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile(String uid) async {
    final data = await _authService.getUserProfile(uid);
    if (data != null) {
      _userProfile = UserModel.fromMap(data);
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email: email, password: password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}