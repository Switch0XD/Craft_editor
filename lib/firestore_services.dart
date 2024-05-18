import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final _firestore = FirebaseFirestore.instance;
  final StateProvider<List<Map>> _vesselsProvider =
      StateProvider<List<Map>>((ref) => [{}]);

  final StateProvider<List<Map>> _ranksProvider =
      StateProvider<List<Map>>((ref) => [{}]);

  streamCrewList({
    String? imo,
    String? rank,
    String? status,
  }) {
    Query query = _firestore
        .collection('cms')
        .where('status', isEqualTo: 'onboard')
        .where('type', isEqualTo: 'ship')
        .where('vessels', arrayContains: imo)
        .orderBy('rankIndex', descending: false);

    if (rank != null && rank.isNotEmpty) {
      query = query.where('rank', isEqualTo: rank);
    }

    return query.snapshots();
  }

  getFilteredResults(
      {required String path,
      String? type,
      Map<String, dynamic>? filters,
      String? tag,
      String? orderby,
      bool descending = true}) {
    Query query = FirebaseFirestore.instance
        .collection(path)
        .where('type', isEqualTo: type ?? 'ship');
    filters?.forEach((key, value) {
      if (value != null) {
        query = query.where(key, isEqualTo: value);
      }
    });
    if (tag != null && tag != '') {
      query = query.where('tags', arrayContains: tag);
    }
    if (orderby != null) query = query.orderBy(orderby, descending: descending);
    return query.limit(50).snapshots();
  }

  StateProvider<List<Map>> getRanksProvider(WidgetRef ref) {
    //call this method once to setup the provider
    if (ref.read(_ranksProvider).length <= 1) {
      FirebaseFirestore.instance
          .collection('rank_masters')
          .orderBy('sno', descending: false)
          .snapshots()
          .listen((event) {
        List<Map> ranksList = [];
        for (var element in event.docs) {
          ranksList.add(element.data());
        }
        ref.read(_ranksProvider.notifier).update((state) => ranksList);
      });
    }
    return _ranksProvider;
  }

  StateProvider<List<Map>> getVesselsProvider(WidgetRef ref) {
    //call this method once to setup the provider
    if (ref.read(_vesselsProvider).length <= 1) {
      FirebaseFirestore.instance
          .collection('vessel_masters')
          .snapshots()
          .listen((event) {
        List<Map> vesselsList = [];
        for (var element in event.docs) {
          vesselsList.add(element.data());
        }
        ref.read(_vesselsProvider.notifier).update((state) => vesselsList);
        // print(ref.read(_vesselsProvider));
      });
    }
    return _vesselsProvider;
  }

  Future<List> fetchRanks() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('rank_masters').get();
    return querySnapshot.docs.map((e) => e.data()).toList();
  }

  fetchData({required String path, String? tag}) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot;
    if (tag == '' || tag == null) {
      querySnapshot = await FirebaseFirestore.instance
          .collection(path)
          .where('status', isEqualTo: 'leave')
          .where('uid', isNull: false)
          .limit(50)
          .get();
    } else {
      querySnapshot = await FirebaseFirestore.instance
          .collection(path)
          .where('status', isEqualTo: 'leave')
          .where('tags', arrayContains: tag.toLowerCase())
          .where('uid', isNull: false)
          .limit(50)
          .get();
    }
    return querySnapshot.docs.map((e) => e.data()).toList();
  }

  fetchEmployeeList({required String path, String? tag}) async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot;
    if (tag == '' || tag == null) {
      querySnapshot =
          await FirebaseFirestore.instance.collection(path).limit(50).get();
    } else {
      querySnapshot = await FirebaseFirestore.instance
          .collection(path)
          .where('tags', arrayContains: tag.toLowerCase())
          .limit(50)
          .get();
    }
    return querySnapshot.docs.map((e) => e.data()).toList();
  }

  searchQuery({
    required String path,
    required String frequency,
    dynamic query,
  }) {
    return _firestore
        .collection(path)
        .where('frequency', isEqualTo: frequency)
        .where('tags', arrayContainsAny: query)
        .limit(20)
        .snapshots();
  }

  searchEmployee({
    required String path,
    dynamic query,
  }) {
    return _firestore
        .collection(path)
        .where('tags', arrayContainsAny: query)
        .limit(20)
        .snapshots();
  }

  getSnapshots({
    required String path,
  }) {
    return _firestore
        .collection(path)
        .orderBy('sno', descending: false)
        .snapshots();
  }

  getDocuments({
    required String path,
    required String type,
  }) {
    return _firestore
        .collection(path)
        .where('type', isEqualTo: type)
        .snapshots();
  }

  getBudget({
    required String path,
    required String department,
  }) {
    return _firestore
        .collection(path)
        .where('department', isEqualTo: department)
        .snapshots();
  }

  getJob({
    required String path,
    required String category,
  }) {
    return _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('name', isNotEqualTo: null)
        .snapshots();
  }

  get({
    required String path,
    required String parent,
    required String category,
    String? name,
  }) {
    return _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('parent', isEqualTo: parent)
        .where('name', isEqualTo: name)
        .orderBy('sno', descending: false)
        .snapshots();
  }

  getForms({
    required String path,
    required String parent,
    required String category,
    String? responsibilty,
  }) {
    Query query = _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('parent', isEqualTo: parent)
        .orderBy('sno', descending: false);
    if (responsibilty != null) {
      return query
          .where('responsibility', arrayContains: responsibilty)
          .snapshots();
    }
    return query.snapshots();
  }

  getManuals({
    required String path,
    required String parent,
    required String category,
    String? responsibilty,
  }) {
    Query query = _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('parent', isEqualTo: parent)
        .orderBy('sno', descending: false);

    if (responsibilty != null) {
      return query
          .where('responsibility', arrayContains: responsibilty)
          .snapshots();
    }
    return query.snapshots();
  }

  streamKyc({
    required String path,
    required String type,
    required String category,
    String? responsibilty,
  }) {
    Query query = _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('type', isEqualTo: type);

    if (responsibilty != null) {
      return query
          .where('responsibility', arrayContains: responsibilty)
          .limit(40)
          .orderBy('year', descending: true)
          .snapshots();
    }
    return query.limit(40).orderBy('year', descending: true).snapshots();
  }

  streamApplications({
    required String status,
    String? rank,
    String? vesselType,
  }) {
    Query query = _firestore
        .collection('applications')
        .where('status', isEqualTo: status);
    if (rank != null && rank != '') {
      query = query.where('rank', isEqualTo: rank);
    }
    if (vesselType != null && vesselType != '') {
      query = query.where('vesselTypes', arrayContains: vesselType);
    }
    return query.orderBy('appliedOn', descending: true).snapshots();
  }

  getCertificates({
    required String path,
    String? parent,
    String? category,
    String? type,
    String? responsibility,
  }) {
    Query query = _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('parent', isEqualTo: parent)
        .where('type', isEqualTo: type)
        .orderBy('sno', descending: false);

    if (responsibility != null) {
      return query
          .where('responsibility', arrayContains: responsibility)
          .snapshots();
    }
    return query.snapshots();
  }

  getSMS({
    required String path,
  }) {
    return _firestore.doc(path).snapshots();
  }

//
  streamPermissions({
    required String path,
    String? module,
    String? tag,
    String? rank,
  }) {
    Query query = _firestore.collection(path);
    if (module != '') {
      query = query.where('modules', arrayContains: module);
    }
    if (rank != '') {
      query = query.where('rank', isEqualTo: rank);
    }
    if (tag != null && tag != '') {
      query = query.where('tags', arrayContains: tag);
    }
    return query.orderBy('firstName', descending: false).snapshots();
  }

  streamEmployee({
    required String path,
    String? module,
    String? rank,
  }) {
    Query query = _firestore.collection(path);
    if (module != '') {
      query = query.where('modules', arrayContains: module);
    }
    if (rank != '') {
      query = query.where('rank', isEqualTo: rank);
    }
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  getVesselDetails({
    required String path,
  }) {
    return _firestore
        .collection(path)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  getReportMaster({
    required String path,
    required String category,
    required String frequency,
    String? responsibility,
  }) {
    Query query = _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('frequency', isEqualTo: frequency)
        .orderBy('timestamp', descending: true);

    if (responsibility != null) {
      return query
          .where('responsibility', arrayContains: responsibility)
          .limit(30)
          .snapshots();
    }
    return query.limit(30).snapshots();
  }

  getReports({
    required String path,
    required String category,
    required String frequency,
    required String formId,
  }) {
    return _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('frequency', isEqualTo: frequency)
        .where('formId', isEqualTo: formId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  getHsseq({
    required String path,
    required String category,
    required String type,
  }) {
    return _firestore
        .collection(path)
        .where('category', isEqualTo: category)
        .where('type', isEqualTo: type)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  getDocument({required String path}) {
    return _firestore.doc(path).get();
  }

  getCollection({required String path}) {
    return _firestore.collection(path).snapshots();
  }

  streamGrn({required String path}) {
    return _firestore.collection(path).where('type', isEqualTo: 'grn').get();
  }

  streamRevision({required String path, String? responsibility}) {
    Query query = _firestore.collection(path);
    if (responsibility != null) {
      return query
          .where('responsibility', arrayContains: responsibility)
          .limit(20)
          .orderBy("timestamp", descending: true)
          .get();
    }
    return query.limit(20).orderBy("timestamp", descending: true).snapshots();
  }

  streamRequisition({required String path}) {
    return _firestore
        .collection(path)
        .where('type', isEqualTo: 'requisition')
        .get();
  }

  addData({required String path, required Map<String, dynamic> model}) async {
    model['timestamp'] = FieldValue.serverTimestamp();
    return await _firestore.collection(path).add(model);
  }

  setData(
      {required String path,
      required Map<String, dynamic> model,
      bool merge = true}) async {
    model['timestamp'] = FieldValue.serverTimestamp();
    return await _firestore.doc(path).set(model, SetOptions(merge: true));
  }

  getVessels({required vessels}) {
    return _firestore
        .collection('vessel_masters')
        .where('tags', arrayContainsAny: vessels)
        .snapshots();
  }

  setEditData(
      {required String path,
      required Map<String, dynamic> model,
      bool merge = true}) async {
    model['revisionDate'] = FieldValue.serverTimestamp();
    return await _firestore.doc(path).set(model, SetOptions(merge: true));
  }

  deleteData({required String path}) async {
    final reference = _firestore.doc(path);
    return await reference.delete();
  }
}

final firestoreProvider =
    Provider<FirestoreService>((ref) => FirestoreService._());
