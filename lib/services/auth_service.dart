import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _authOrNull => isAvailable ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _firestoreOrNull =>
      isAvailable ? FirebaseFirestore.instance : null;

  User? get currentUser => _authOrNull?.currentUser;

  Stream<User?> get authStateChanges {
    final auth = _authOrNull;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges();
  }

  Future<String?> signUp(String email, String password, String name) async {
    final auth = _authOrNull;
    final firestore = _firestoreOrNull;
    if (auth == null || firestore == null) {
      return 'Firebase is not configured for this environment.';
    }

    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();
        await firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'meshAddress': '0x${user.uid.substring(0, 4)}',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signIn(String email, String password) async {
    final auth = _authOrNull;
    if (auth == null) {
      return 'Firebase is not configured for this environment.';
    }

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _authOrNull?.signOut();
  }
}
