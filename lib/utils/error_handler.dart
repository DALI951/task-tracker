import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String friendlyError(dynamic e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'email-already-in-use': return 'Email already in use';
      case 'invalid-email': return 'Invalid email address';
      case 'weak-password': return 'Password too weak (min 6 characters)';
      case 'user-not-found': return 'No account found with this email';
      case 'wrong-password': return 'Wrong password';
      case 'too-many-requests': return 'Too many attempts. Try again later';
      case 'network-request-failed': return 'Network error. Check connection';
    }
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'Permission denied';
    if (e.code == 'unavailable') return 'Service unavailable. Try again';
    if (e.code == 'not-found') return 'Resource not found';
  }
  final msg = e.toString();
  if (msg.startsWith('Exception: ')) return msg.substring(11);
  if (msg.length > 120) return 'An error occurred';
  return msg;
}

void toast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
