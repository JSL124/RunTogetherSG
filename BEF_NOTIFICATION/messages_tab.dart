// lib/messages_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'event_service.dart';
import 'event_model.dart';
import 'event_chat_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final EventService _eventService = EventService();

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<RunningEvent>>(
        stream: _eventService.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No chats yet. Join a run!"));
          }

          final myUserId = _eventService.currentUserId;
          List<RunningEvent> myEvents = snapshot.data!
              .where((event) => event.participants.contains(myUserId))
              .toList();

          if (myEvents.isEmpty) {
            return const Center(child: Text("No active chats."));
          }

          // 최신순 정렬
          myEvents.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

          return ListView.separated(
            itemCount: myEvents.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = myEvents[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.group, color: Colors.blue),
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // 💡 모델에서 가져온 최신 메시지를 보여주는 부분
                subtitle: Row(
                  children: [
                    if (event.lastMessageSender.isNotEmpty)
                      Text(
                        "${event.lastMessageSender}: ",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    Expanded(
                      child: Text(
                        event.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  _formatTime(event.lastMessageTime),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventChatScreen(
                        eventId: event.id,
                        eventTitle: event.title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}