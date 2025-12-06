class ErrorHandler {
  static String getFirebaseAuthError(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'invalid-credential':
        return 'Invalid login credentials';
      default:
        return 'An error occurred. Please try again';
    }
  }

  static String getFirebaseFirestoreError(String errorCode) {
    switch (errorCode) {
      case 'permission-denied':
        return 'You don\'t have permission to access this data';
      case 'not-found':
        return 'Requested data not found';
      case 'already-exists':
        return 'This data already exists';
      case 'resource-exhausted':
        return 'Request limit exceeded. Try again later';
      default:
        return 'Database error occurred';
    }
  }
}
