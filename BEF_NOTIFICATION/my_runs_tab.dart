// lib/my_runs_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'event_model.dart';
import 'event_details_screen.dart';

class MyRunsTab extends StatefulWidget {
  const MyRunsTab({super.key});

  @override
  State<MyRunsTab> createState() => _MyRunsTabState();
}

class _MyRunsTabState extends State<MyRunsTab> with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 탭 2개: Upcoming(예정), History(완료)
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Runs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. 예정된 러닝 (Upcoming)
          _buildUpcomingList(),
          
          // 2. 완료된 러닝 (History)
          _buildHistoryList(),
        ],
      ),
    );
  }

  // 🏃‍♂️ 예정된 러닝 목록
  Widget _buildUpcomingList() {
    return StreamBuilder<List<RunningEvent>>(
      // EventService.getEvents()는 이미 'scheduled' 상태만 가져옵니다.
      stream: _eventService.getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No upcoming runs.", Icons.directions_run);
        }

        final myUserId = _eventService.currentUserId;
        
        // 💡 내가 참가한 것만 필터링
        final myRuns = snapshot.data!
            .where((event) => event.participants.contains(myUserId))
            .toList();

        if (myRuns.isEmpty) {
          return _buildEmptyState("You haven't joined any runs yet.", Icons.directions_run);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: myRuns.length,
          itemBuilder: (context, index) {
            return _buildRunCard(myRuns[index], isHistory: false);
          },
        );
      },
    );
  }

  // 🏅 완료된 러닝 목록
  Widget _buildHistoryList() {
    return StreamBuilder<List<RunningEvent>>(
      // EventService.getHistoryEvents()는 'completed' 상태만 가져옵니다.
      stream: _eventService.getHistoryEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No run history yet.", Icons.history);
        }

        final historyRuns = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: historyRuns.length,
          itemBuilder: (context, index) {
            return _buildRunCard(historyRuns[index], isHistory: true);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRunCard(RunningEvent event, {required bool isHistory}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onTap: () {
          // 히스토리는 클릭해도 상세화면으로 갈 필요 없거나, 가더라도 읽기 전용이어야 함
          // 여기서는 예정된 러닝만 이동하도록 설정
          if (!isHistory) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventDetailsScreen(event: event)),
            );
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHistory ? Colors.grey[200] : Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isHistory ? Icons.check : Icons.directions_run,
            color: isHistory ? Colors.grey : Colors.blue,
          ),
        ),
        title: Text(
          event.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: isHistory ? TextDecoration.lineThrough : null,
            color: isHistory ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 5),
                Text(
                  DateFormat('MMM d, h:mm a').format(event.dateTime),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (isHistory)
              const Text("Completed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
            else
              Text("${event.participants.length}/${event.maxParticipants} Runners", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        trailing: isHistory 
            ? null 
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}