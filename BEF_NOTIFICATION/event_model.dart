// lib/event_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// 1. 기존 RunningEvent 클래스 (그대로 유지)
class RunningEvent {
  final String id;
  final String title;
  final DateTime dateTime;
  final LatLng location;
  final String address; 
  final String level;
  final int maxParticipants;
  final String hostUid;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSender;
  final DateTime lastMessageTime;
  final String status;

  RunningEvent({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.location,
    required this.address, 
    required this.level,
    required this.maxParticipants,
    required this.hostUid,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageSender,
    required this.lastMessageTime,
    required this.status,
  });

  factory RunningEvent.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint geoPoint = data['location'] ?? const GeoPoint(0, 0);
    LatLng latLng = LatLng(geoPoint.latitude, geoPoint.longitude);

    return RunningEvent(
      id: doc.id,
      title: data['title'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      location: latLng,
      address: data['address'] ?? 'Location details not provided', 
      level: data['level'] ?? 'Beginner',
      maxParticipants: data['maxParticipants'] ?? 8,
      hostUid: data['hostUid'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? 'No messages yet',
      lastMessageSender: data['lastMessageSender'] ?? '',
      lastMessageTime: data['lastMessageTime'] != null ? (data['lastMessageTime'] as Timestamp).toDate() : DateTime.now(),
      status: data['status'] ?? 'scheduled',
    );
  }

  Marker toMarker({required Function(RunningEvent) onTap}) {
    return Marker(
      markerId: MarkerId(id),
      position: location,
      infoWindow: InfoWindow(title: title, snippet: level),
      onTap: () => onTap(this),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }
}

// 🏆 2. [NEW] 레벨 시스템 공통 데이터 (추가됨!)
class RunLevel {
  final int minRuns;
  final String title;
  final Color color;
  final IconData icon;

  const RunLevel(this.minRuns, this.title, this.color, this.icon);
}

// 30단계 레벨 리스트 (프로필 탭에서 가져옴)
const List<RunLevel> appLevels = [
  const RunLevel(0, "Baby Runner", Colors.green, Icons.egg),
  const RunLevel(3, "First Step", Colors.green, Icons.directions_walk),
  const RunLevel(5, "Jogger", Colors.lightGreen, Icons.hiking),
  const RunLevel(8, "Park Stroller", Colors.lightGreen, Icons.park),
  const RunLevel(10, "5K Rookie", Colors.teal, Icons.looks_5),
  const RunLevel(15, "Fun Runner", Colors.teal, Icons.mood),
  const RunLevel(20, "Running Crew", Colors.cyan, Icons.groups),
  const RunLevel(25, "Habit Maker", Colors.cyan, Icons.event_available),
  const RunLevel(30, "City Runner", Colors.blue, Icons.location_city),
  const RunLevel(40, "Night Runner", Colors.blue, Icons.nights_stay),
  const RunLevel(50, "10K Finisher", Colors.indigo, Icons.looks_one),
  const RunLevel(60, "Half Marathoner", Colors.indigo, Icons.hourglass_bottom),
  const RunLevel(70, "Sprinter", Colors.indigo, Icons.flash_on),
  const RunLevel(80, "Pacer", Colors.deepPurple, Icons.timer),
  const RunLevel(90, "Trail Runner", Colors.deepPurple, Icons.landscape),
  const RunLevel(100, "Century Club", Colors.deepPurple, Icons.workspace_premium),
  const RunLevel(120, "Iron Legs", Colors.purple, Icons.fitness_center),
  const RunLevel(140, "Heart of Steel", Colors.purple, Icons.favorite),
  const RunLevel(160, "Wind Breaker", Colors.purple, Icons.air),
  const RunLevel(180, "Road Master", Colors.purple, Icons.add_road),
  const RunLevel(200, "Pro Marathoner", Colors.deepOrange, Icons.local_fire_department),
  const RunLevel(250, "Elite Runner", Colors.deepOrange, Icons.military_tech),
  const RunLevel(300, "Ultra Runner", Colors.deepOrange, Icons.terrain),
  const RunLevel(350, "Legend", Colors.red, Icons.auto_awesome),
  const RunLevel(400, "Hero", Colors.red, Icons.star),
  const RunLevel(450, "Champion", Colors.red, Icons.emoji_events),
  const RunLevel(500, "Grand Master", Colors.brown, Icons.psychology),
  const RunLevel(600, "Time Traveler", Colors.brown, Icons.history_edu),
  const RunLevel(700, "World Class", Colors.brown, Icons.public),
  const RunLevel(800, "Universe Class", Colors.black87, Icons.rocket_launch),
  const RunLevel(900, "God of Running", Colors.black, Icons.bolt),
  const RunLevel(1000, "Marathon Master", const Color(0xFFFFD700), Icons.workspace_premium),
];

// 레벨 계산 함수
RunLevel getLevelInfo(int runCount) {
  return appLevels.lastWhere((level) => runCount >= level.minRuns, orElse: () => appLevels[0]);
}