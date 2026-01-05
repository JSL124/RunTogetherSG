// lib/profile_tab.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'event_model.dart'; 

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final EventService _eventService = EventService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // 🗓️ 캘린더 상태 변수
  int _displayYear = DateTime.now().year; // 현재 보여주는 연도
  int? _selectedMonth; // 선택된 월 (null이면 해당 연도 전체 보기)

  String get myUserId => _eventService.currentUserId;

  // 영어 월 이름 리스트
  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  RunLevel? _getNextLevel(int count) {
    try {
      return appLevels.firstWhere((level) => count < level.minRuns);
    } catch (e) {
      return null;
    }
  }

  void _showAvatarPicker() {
    final List<String> avatarSeeds = List.generate(30, (index) => 'runner_avatar_${index + 1}');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SizedBox(height: 600, child: Column(children: [
          const SizedBox(height: 20), const Text("Choose your style", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Divider(),
          Expanded(child: GridView.builder(padding: const EdgeInsets.all(20), itemCount: avatarSeeds.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 15, mainAxisSpacing: 15), itemBuilder: (context, index) {
            final String url = 'https://api.dicebear.com/9.x/adventurer/png?seed=${avatarSeeds[index]}';
            return GestureDetector(onTap: () { _updateAvatar(url); Navigator.pop(context); }, child: CircleAvatar(backgroundImage: NetworkImage(url)));
          }))
        ]));
      },
    );
  }

  Future<void> _updateAvatar(String newUrl) async {
    await FirebaseFirestore.instance.collection('users').doc(myUserId).update({'photoUrl': newUrl});
  }

  void _showEditProfileDialog(String currentName, String currentBio) {
    _nameController.text = currentName;
    _bioController.text = currentBio;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Edit Profile'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nickname')), TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(myUserId).set({'name': _nameController.text.trim(), 'bio': _bioController.text.trim()}, SetOptions(merge: true)); if(!mounted) return; Navigator.pop(context); }, child: const Text('Save'))],
    ));
  }

  void _logOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context, builder: (context) => AlertDialog(
        title: const Text('Log Out?'), content: const Text('Are you sure you want to log out?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out', style: TextStyle(color: Colors.red)))],
      ),
    );
    if (confirm == true) await FirebaseAuth.instance.signOut();
  }

  void _showLevelGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Runner Levels 🏆"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: appLevels.length,
            itemBuilder: (context, index) {
              final level = appLevels[index];
              final isLast = index == appLevels.length - 1;
              String range = isLast ? "${level.minRuns}+ runs" : "${level.minRuns} ~ ${appLevels[index+1].minRuns - 1} runs";
              return ListTile(
                dense: true,
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: level.color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(level.icon, color: level.color, size: 20)),
                title: Text(level.title, style: TextStyle(fontWeight: FontWeight.bold, color: level.color)),
                trailing: Text(range, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildLevelBadge(int runCount) {
    final current = getLevelInfo(runCount);
    final next = _getNextLevel(runCount);
    String nextGoalText = next != null ? "Next: ${next.title} (${next.minRuns - runCount} runs left)" : "Max Level Reached! 👑";

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: current.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), 
                border: Border.all(color: current.color.withOpacity(0.5), width: 1.5),
                boxShadow: current.minRuns >= 500 ? [BoxShadow(color: current.color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(current.icon, size: 20, color: current.color), const SizedBox(width: 8), Text("${current.title} (Lv.${appLevels.indexOf(current) + 1})", style: TextStyle(color: current.color, fontWeight: FontWeight.bold, fontSize: 16))]),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.help_outline, color: Colors.grey), onPressed: _showLevelGuide)
          ],
        ),
        const SizedBox(height: 5),
        Text(nextGoalText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (myUserId.isEmpty) return const Center(child: Text("Please log in first."));
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(myUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'New Runner';
        final bio = data['bio'] ?? 'No bio yet.';
        final photoUrl = data['photoUrl'] ?? 'https://api.dicebear.com/9.x/adventurer/png?seed=$myUserId';
        
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(title: const Text('My Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditProfileDialog(name, bio))]),
          body: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 20),
              GestureDetector(onTap: _showAvatarPicker, child: CircleAvatar(radius: 60, backgroundImage: NetworkImage(photoUrl))),
              const SizedBox(height: 15),
              
              StreamBuilder<List<RunningEvent>>(
                stream: _eventService.getHistoryEvents(),
                builder: (context, historySnapshot) {
                  if (!historySnapshot.hasData) return Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                  final count = historySnapshot.data!.length;
                  final level = getLevelInfo(count);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(level.icon, color: level.color, size: 28),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
              
              Text(bio, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              StreamBuilder<List<RunningEvent>>(
                stream: _eventService.getHistoryEvents(),
                builder: (context, historySnapshot) {
                  if (!historySnapshot.hasData) return const SizedBox();
                  return _buildLevelBadge(historySnapshot.data!.length);
                },
              ),
              const SizedBox(height: 30), const Divider(),
              
              // 🗓️ 새로운 캘린더 스타일 히스토리
              _buildCalendarHistorySection(),
              
              const SizedBox(height: 30),
              TextButton.icon(onPressed: _logOut, icon: const Icon(Icons.logout, color: Colors.red), label: const Text("Log Out", style: TextStyle(color: Colors.red, fontSize: 16))),
              const SizedBox(height: 40),
            ]),
          ),
        );
      },
    );
  }

  // 🗓️ 연도/월 선택 UI + 리스트
  Widget _buildCalendarHistorySection() {
    return StreamBuilder<List<RunningEvent>>(
      stream: _eventService.getHistoryEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final allEvents = snapshot.data ?? [];
        
        // 1. 현재 연도의 데이터만 필터링 (캘린더 표시용)
        final eventsInYear = allEvents.where((e) => e.dateTime.year == _displayYear).toList();
        
        // 2. 데이터가 있는 월(Month) 찾기 (1~12)
        final Set<int> activeMonths = eventsInYear.map((e) => e.dateTime.month).toSet();

        // 3. 리스트에 보여줄 데이터 필터링
        List<RunningEvent> displayList;
        if (_selectedMonth == null) {
          // 월 선택 안 했으면 해당 연도 전체
          displayList = eventsInYear;
        } else {
          // 월 선택 했으면 해당 월만
          displayList = eventsInYear.where((e) => e.dateTime.month == _selectedMonth).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text("Run History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            
            // 🗓️ [1] 연도 선택기 (< 2025 >)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _displayYear--;
                      _selectedMonth = null; // 연도 바꾸면 월 선택 초기화
                    });
                  },
                ),
                Text(
                  "$_displayYear", 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _displayYear++;
                      _selectedMonth = null;
                    });
                  },
                ),
              ],
            ),

            // 🗓️ [2] 월 선택 그리드 (Jan ~ Dec)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6, // 한 줄에 6개 (2줄로 나옴)
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final int month = index + 1;
                  final bool hasRun = activeMonths.contains(month);
                  final bool isSelected = _selectedMonth == month;

                  return GestureDetector(
                    onTap: hasRun ? () {
                      setState(() {
                        // 이미 선택된 거 누르면 해제(전체보기), 아니면 선택
                        _selectedMonth = isSelected ? null : month;
                      });
                    } : null, // 안 뛴 달은 클릭 불가
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.transparent, // 선택되면 파란 배경
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? null : Border.all(
                          color: hasRun ? Colors.grey[300]! : Colors.transparent
                        ),
                      ),
                      child: Text(
                        _monthNames[index], // Jan, Feb...
                        style: TextStyle(
                          color: isSelected ? Colors.white : (hasRun ? Colors.black87 : Colors.grey[300]),
                          fontWeight: (hasRun || isSelected) ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 30),

            // 📋 [3] 결과 리스트
            if (displayList.isEmpty)
               Padding(
                 padding: const EdgeInsets.all(30), 
                 child: Center(
                   child: Text(
                     activeMonths.isEmpty 
                       ? "No runs in $_displayYear." // 연도에 기록 없음
                       : "Select a highlighted month.", // 기록은 있는데 선택을 안 함 (혹은 빈 달 선택)
                     style: const TextStyle(color: Colors.grey)
                   )
                 )
               )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final event = displayList[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${DateFormat('MMM d').format(event.dateTime)} • ${event.level}"),
                    trailing: const Text("Completed", style: TextStyle(color: Colors.green, fontSize: 12)),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}