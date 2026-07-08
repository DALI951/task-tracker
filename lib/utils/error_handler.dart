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
      case 'invalid-credential': return 'Invalid email or password';
      case 'too-many-requests': return 'Too many attempts. Try again later';
      case 'network-request-failed': return 'Network error. Check connection';
      case 'operation-not-allowed': return 'This sign-in method is disabled';
      case 'user-disabled': return 'Account has been disabled';
      case 'requires-recent-login': return 'Please sign out and sign in again';
      case 'user-mismatch': return 'Account does not match';
      case 'account-exists-with-different-credential': return 'An account already exists with a different sign-in method';
    }
  }
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied': return 'Permission denied';
      case 'unavailable': return 'Service unavailable. Try again';
      case 'not-found': return 'Resource not found';
      case 'invalid-argument': return 'Invalid data format';
      case 'deadline-exceeded': return 'Request timed out. Check your connection';
      case 'already-exists': return 'This item already exists';
      case 'failed-precondition': return 'Cannot perform this action right now';
      case 'aborted': return 'Operation aborted. Try again';
      case 'resource-exhausted': return 'Too many requests. Slow down';
      case 'internal': return 'Something went wrong on our end';
      case 'data-loss': return 'Data integrity error';
      case 'unauthenticated': return 'Please sign in again';
    }
  }
  final msg = e.toString();
  if (msg.startsWith('Exception: ')) return msg.substring(11);
  return 'An error occurred';
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
