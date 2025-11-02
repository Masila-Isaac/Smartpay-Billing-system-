import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUserReport(String uid) async {
    final doc = await _firestore.collection('reports').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    } else {
      return null;
    }
  }

  Future<void> saveReport(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('reports').doc(uid).set(data);
  }
}
