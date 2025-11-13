// lib/repositories/payment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/payment_model.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all payments in real-time
  Stream<List<Payment>> getPayments() {
    return _firestore
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList());
  }

  // Get payments by phone number
  Stream<List<Payment>> getPaymentsByPhone(String phone) {
    return _firestore
        .collection('payments')
        .where('phone', isEqualTo: phone)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList());
  }

  // Get payments by status
  Stream<List<Payment>> getPaymentsByStatus(String status) {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: status)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList());
  }

  // Get single payment by ID
  Future<Payment?> getPaymentById(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      return doc.exists ? Payment.fromFirestore(doc) : null;
    } catch (e) {
      print('Error getting payment: $e');
      return null;
    }
  }

  // Test function to check if we can read data
  Future<void> testReadPayments() async {
    try {
      final snapshot = await _firestore.collection('payments').limit(5).get();

      print('📊 Found ${snapshot.docs.length} payments in Firestore');

      for (final doc in snapshot.docs) {
        print('Payment ID: ${doc.id}');
        print('Data: ${doc.data()}');
        print('---');
      }
    } catch (e) {
      print('❌ Error reading from Firestore: $e');
    }
  }
}
