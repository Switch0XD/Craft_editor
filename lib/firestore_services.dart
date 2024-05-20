import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final _firestore = FirebaseFirestore.instance;
  setData(
      {required String path,
      required Map<String, dynamic> model,
      bool merge = true}) async {
    model['timestamp'] = FieldValue.serverTimestamp();
    return await _firestore.doc(path).set(model, SetOptions(merge: true));
  }
}

final firestoreProvider =
    Provider<FirestoreService>((ref) => FirestoreService._());
