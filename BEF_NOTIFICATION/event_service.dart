// lib/event_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'event_model.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // 1. 이벤트 목록
  Stream<List<RunningEvent>> getEvents() {
    return _db.collection('events')
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RunningEvent.fromFirestore(doc))
          .where((event) => event.status == 'scheduled') 
          .toList();
    });
  }

  // 1-1. 히스토리
  Stream<List<RunningEvent>> getHistoryEvents() {
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value([]);
    return _db.collection('events')
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RunningEvent.fromFirestore(doc))
          .where((event) => event.status == 'completed' && event.participants.contains(uid))
          .toList();
    });
  }

  // 1-2. 단일 이벤트 정보
  Stream<RunningEvent> getEventStream(String eventId) {
    return _db.collection('events').doc(eventId).snapshots().map((doc) {
      return RunningEvent.fromFirestore(doc);
    });
  }

  // 2. 이벤트 생성
  Future<void> createEvent({
    required String title,
    required DateTime dateTime,
    required LatLng location,
    required String address,
    required String level,
    required int maxParticipants,
  }) async {
    final String uid = currentUserId;
    if (uid.isEmpty) return;
    
    final newEventRef = _db.collection('events').doc();
    final eventData = {
      'id': newEventRef.id,
      'title': title,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': GeoPoint(location.latitude, location.longitude),
      'address': address,
      'level': level,
      'maxParticipants': maxParticipants,
      'hostUid': uid,
      'participants': [uid],
      'joinTimes': { uid: FieldValue.serverTimestamp() },
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Welcome to $title! 🏃‍♂️',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': 'System',
      'status': 'scheduled', 
    };
    await newEventRef.set(eventData);
    await sendMessage(newEventRef.id, 'Welcome to $title! 🏃‍♂️', isSystem: true);
  }

  // 3. 참가 / 취소
  Future<void> updateParticipation({
    required String eventId,
    required bool join,
    required String userName, 
  }) async {
    final String uid = currentUserId;
    if (uid.isEmpty) throw Exception("User not logged in");
    DocumentReference eventRef = _db.collection('events').doc(eventId);

    if (join) {
      await eventRef.update({
        'participants': FieldValue.arrayUnion([uid]),
        'joinTimes.$uid': FieldValue.serverTimestamp(),
      });
      await sendMessage(eventId, '$userName has joined the run! 🏃', isSystem: true);
    } else {
      await eventRef.update({
        'participants': FieldValue.arrayRemove([uid]),
      });
      await sendMessage(eventId, '$userName has left the run.', isSystem: true);
    }
  }

  // 4. 메시지 전송
  Future<void> sendMessage(String eventId, String text, {bool isSystem = false}) async {
    final String uid = currentUserId;
    if (uid.isEmpty) return;

    String name = 'System';
    if (!isSystem) {
      final userDoc = await _db.collection('users').doc(uid).get();
      name = userDoc.data()?['name'] ?? 'Unknown';
    }

    await _db.collection('events').doc(eventId).collection('messages').add({
      'text': text,
      'senderId': isSystem ? 'system' : uid,
      'senderName': name,
      'timestamp': FieldValue.serverTimestamp(),
      'isSystem': isSystem,
      'readBy': [uid], 
    });

    await _db.collection('events').doc(eventId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': name,
    });
  }

  // 5. 메시지 읽음 처리
  Future<void> markMessageAsRead(String eventId, String messageId) async {
    final String uid = currentUserId;
    if (uid.isEmpty) return;
    await _db.collection('events').doc(eventId).collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid])
    });
  }

  // 6. 메시지 스트림
  Stream<QuerySnapshot> getMessages(String eventId, {Timestamp? joinTime}) {
    Query query = _db
        .collection('events')
        .doc(eventId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    if (joinTime != null) {
      query = query.endAt([joinTime]); 
    }
    return query.snapshots();
  }

  // ✅ [복구] 단순 완료 처리 (이미지 X)
  Future<void> completeEvent(String eventId) async {
    final eventRef = _db.collection('events').doc(eventId);
    await eventRef.update({'status': 'completed'});
    final messages = await eventRef.collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
  }
  
  Future<void> checkAutoCompletion() async {
    final now = DateTime.now();
    final snapshot = await _db.collection('events').where('status', isEqualTo: 'scheduled').get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final DateTime eventDate = (data['dateTime'] as Timestamp).toDate();
      if (now.difference(eventDate).inHours >= 24) {
        await completeEvent(doc.id);
      }
    }
  }
}