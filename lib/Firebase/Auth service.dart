import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Encryption/Encryption service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register a new user and generate their RSA key pair
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(displayName);

    // Generate RSA key pair for E2E encryption
    final keyPair = await E2EEncryptionService.generateRSAKeyPair();
    await E2EEncryptionService.storeKeyPair(keyPair);

    // Store user profile + public key in Firestore
    final publicKeyPem = await E2EEncryptionService.getStoredPublicKeyPem();
    await _db.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'email': email,
      'displayName': displayName,
      'publicKey': publicKeyPem,
      'photoUrl': null,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  /// Sign in existing user
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Update last seen timestamp
  Future<void> updateLastSeen() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Search users by email
  Stream<QuerySnapshot> searchUsers(String query) {
    return _db
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThan: '${query}z')
        .limit(10)
        .snapshots();
  }
}