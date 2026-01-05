// lib/event_chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'event_model.dart'; 

class EventChatScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventChatScreen({super.key, required this.eventId, required this.eventTitle});

  @override
  State<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends State<EventChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final EventService _eventService = EventService();
  final ScrollController _scrollController = ScrollController();

  String get myUserId => _eventService.currentUserId;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text.trim();
    _messageController.clear();
    await _eventService.sendMessage(widget.eventId, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  void _leaveChat() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Chat?'),
        content: const Text('Do you want to leave this running group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUserId).get();
      final myName = userDoc.data()?['name'] ?? 'Runner';

      await _eventService.updateParticipation(
        eventId: widget.eventId, 
        join: false, 
        userName: myName
      );
      
      if (!mounted) return;
      Navigator.pop(context); 
      Navigator.pop(context); 
    }
  }

  Widget _buildParticipantItem(String uid) {
    return FutureBuilder(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance.collection('events')
            .where('participants', arrayContains: uid)
            .where('status', isEqualTo: 'completed')
            .count()
            .get()
      ]),
      builder: (context, snapshot) {
        String name = 'Loading...';
        String photoUrl = '';
        int runCount = 0;

        if (snapshot.hasData) {
          final userDoc = snapshot.data![0] as DocumentSnapshot;
          final countQuery = snapshot.data![1] as AggregateQuerySnapshot;
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            name = data['name'] ?? 'Unknown';
            photoUrl = data['photoUrl'] ?? '';
            runCount = countQuery.count ?? 0;
          }
        }

        final level = getLevelInfo(runCount);
        final bool isMe = uid == myUserId;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: CircleAvatar(
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
          ),
          title: Row(
            children: [
              Icon(level.icon, size: 16, color: level.color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name + (isMe ? ' (Me)' : ''),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RunningEvent>(
      stream: _eventService.getEventStream(widget.eventId),
      builder: (context, eventSnapshot) {
        if (!eventSnapshot.hasData) {
          return Scaffold(appBar: AppBar(title: Text(widget.eventTitle)), body: const Center(child: CircularProgressIndicator()));
        }

        final event = eventSnapshot.data!;
        final int participantCount = event.participants.length;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Flexible(child: Text(event.title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text("($participantCount)", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0.5,
            actions: [
              Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openEndDrawer())),
            ],
          ),
          endDrawer: Drawer(
            width: 250,
            child: Column(
              children: [
                Container(
                  height: 100,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: const Text("Run Members", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(child: ListView.builder(itemCount: event.participants.length, itemBuilder: (context, index) => _buildParticipantItem(event.participants[index]))),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.exit_to_app, color: Colors.grey), title: const Text("Leave Chat", style: TextStyle(color: Colors.grey)), onTap: _leaveChat),
                const SizedBox(height: 20),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _eventService.getMessages(widget.eventId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("Say hello! 👋", style: TextStyle(color: Colors.grey)));

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool isMe = data['senderId'] == myUserId;
                        final bool isSystem = data['isSystem'] == true;

                        if (isSystem) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
                              child: Text(data['text'], style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          );
                        }

                        // 시간 텍스트 생성
                        final String timeString = data['timestamp'] != null 
                            ? DateFormat('h:mm a').format((data['timestamp'] as Timestamp).toDate()) 
                            : 'Now';

                        // 💡 시간 텍스트 위젯 (재사용)
                        final Widget timeWidget = Padding(
                          padding: const EdgeInsets.only(bottom: 2), // 바닥에서 살짝 띄움
                          child: Text(
                            timeString,
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );

                        // ✨ 채팅 Row 구성
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // 내용물만큼만 차지
                            crossAxisAlignment: CrossAxisAlignment.end, // 바닥 정렬
                            children: [
                              // 1. 내가 보낸 거면: [시간] [말풍선] 순서
                              if (isMe) Padding(padding: const EdgeInsets.only(right: 6), child: timeWidget),

                              // 2. 말풍선 (Container)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : const Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(5),
                                    bottomRight: isMe ? const Radius.circular(5) : const Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe) ...[
                                      Text(data['senderName'], style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      data['text'],
                                      style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black),
                                    ),
                                  ],
                                ),
                              ),

                              // 3. 상대가 보낸 거면: [말풍선] [시간] 순서
                              if (!isMe) Padding(padding: const EdgeInsets.only(left: 6), child: timeWidget),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                color: Colors.white,
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: "Type a message...", filled: true, fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(backgroundColor: Colors.blue, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}