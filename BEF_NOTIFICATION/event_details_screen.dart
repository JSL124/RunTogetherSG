// lib/event_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'event_model.dart';
import 'event_service.dart';
import 'event_chat_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final RunningEvent event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventService _eventService = EventService();
  
  String get myUserId => _eventService.currentUserId;
  bool isJoining = false;
  bool isDeleting = false; 

  void _deleteEvent() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Run?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => isDeleting = true);
    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.event.id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run has been cancelled.')));
      Navigator.of(context).pop(); 
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  void _completeRun() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Run?'),
        content: const Text('Mark this run as completed and move to history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true); 
    try {
      await _eventService.completeEvent(widget.event.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run Completed! Great job! 🎉')));
      Navigator.of(context).pop(); 
    } catch (e) {
      print(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error completing run.')));
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  void _toggleParticipation(RunningEvent currentEvent) async {
    setState(() => isJoining = true);
    try {
      final bool isJoined = currentEvent.participants.contains(myUserId);
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUserId).get();
      final String myName = userDoc.data()?['name'] ?? 'Runner';

      await _eventService.updateParticipation(
        eventId: currentEvent.id,
        join: !isJoined, 
        userName: myName, 
      );
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  void _goToChat() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EventChatScreen(eventId: widget.event.id, eventTitle: widget.event.title)));
  }

  // 💡 [NEW] 참가자 정보를 불러올 때 '레벨'도 같이 계산해서 보여주는 함수
  Widget _buildRealUserInfo(String uid, {required bool isHostSection}) {
    // Future.wait를 써서 사용자 정보와 완료된 러닝 횟수(count)를 동시에 가져옵니다!
    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance.collection('events')
            .where('participants', arrayContains: uid)
            .where('status', isEqualTo: 'completed')
            .count() // 횟수만 세는 효율적인 쿼리
            .get()
      ]),
      builder: (context, snapshot) {
        String name = 'Unknown';
        String photoUrl = ''; 
        int runCount = 0;

        if (snapshot.hasData) {
          final userDoc = snapshot.data![0] as DocumentSnapshot;
          final countQuery = snapshot.data![1] as AggregateQuerySnapshot;
          
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            name = data['name'] ?? 'Unknown';
            photoUrl = data['photoUrl'] ?? '';
            runCount = countQuery.count ?? 0; // 러닝 횟수
          }
        }

        // 레벨 계산
        final level = getLevelInfo(runCount);

        if (isHostSection) {
          return Row(children: [
            // 프사
            CircleAvatar(radius: 20, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? const Icon(Icons.person) : null),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 💡 이름 앞에 레벨 아이콘!
              Row(
                children: [
                  Icon(level.icon, color: level.color, size: 16),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Text("Organizer", style: TextStyle(color: Colors.grey, fontSize: 12))
            ])
          ]);
        } else {
          return Container(
            width: 70, // 폭을 조금 넓힘
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                CircleAvatar(radius: 22, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null),
                const SizedBox(height: 5), 
                // 💡 이름 위에 작은 레벨 아이콘
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(level.icon, color: level.color, size: 12),
                    const SizedBox(width: 2),
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.event.id).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator())); 
        }

        RunningEvent currentEvent = RunningEvent.fromFirestore(snapshot.data!);
        final bool amIJoined = currentEvent.participants.contains(myUserId);
        final bool amIHost = currentEvent.hostUid == myUserId; 
        final LatLng spot = LatLng(currentEvent.location.latitude, currentEvent.location.longitude);
        final bool isCompleted = currentEvent.status == 'completed';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Event Details'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              if (amIHost && !isCompleted)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'complete') _completeRun();
                    if (value == 'cancel') _deleteEvent();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'complete', child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("Complete Run")])),
                    const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Cancel Run")])),
                  ],
                )
              else if (amIJoined && !isCompleted)
                TextButton.icon(onPressed: () => _toggleParticipation(currentEvent), icon: const Icon(Icons.exit_to_app, color: Colors.red), label: const Text('Leave', style: TextStyle(color: Colors.red)))
            ],
          ),
          body: isDeleting 
            ? const Center(child: CircularProgressIndicator())
            : Column(
            children: [
              SizedBox(
                height: 250,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: spot, zoom: 15),
                  markers: {Marker(markerId: const MarkerId('spot'), position: spot)},
                  zoomControlsEnabled: false,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 24),
                            const SizedBox(width: 8),
                            Expanded(child: Text(currentEvent.address.isNotEmpty ? currentEvent.address : 'Location details not provided', style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        Text(currentEvent.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(children: [_buildTag(Icons.speed, currentEvent.level, Colors.orange), const SizedBox(width: 10), _buildTag(Icons.calendar_today, DateFormat('MMM d, h:mm a').format(currentEvent.dateTime), Colors.blue)]),
                        
                        if (isCompleted)
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.all(10),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                            child: const Text("Run Completed! This event is now in history.", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),

                        const SizedBox(height: 25),
                        const Text("Host", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        // 호스트 정보 (레벨 포함)
                        _buildRealUserInfo(currentEvent.hostUid, isHostSection: true),
                        
                        const SizedBox(height: 25),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Participants", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("${currentEvent.participants.length} / ${currentEvent.maxParticipants}", style: const TextStyle(color: Colors.grey))]),
                        const SizedBox(height: 10),
                        // 참가자 목록 (레벨 포함)
                        SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: currentEvent.participants.length, itemBuilder: (context, index) => _buildRealUserInfo(currentEvent.participants[index], isHostSection: false))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                height: 55,
                child: isCompleted
                  ? ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("Event Ended", style: TextStyle(color: Colors.white)))
                  : ElevatedButton.icon(
                      onPressed: isJoining ? null : (amIJoined ? _goToChat : () => _toggleParticipation(currentEvent)),
                      style: ElevatedButton.styleFrom(backgroundColor: amIJoined ? Colors.blue[600] : Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: isJoining ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(amIJoined ? Icons.chat : Icons.directions_run, color: Colors.white),
                      label: Text(isJoining ? 'Processing...' : (amIJoined ? 'Go to Group Chat' : 'Join Run'), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}