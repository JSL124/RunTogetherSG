// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'map_tab.dart'; 
import 'profile_tab.dart'; // 💡 [중요] 방금 만든 프로필 파일 임포트!
import 'my_runs_tab.dart';
import 'messages_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; 

  // 하단 탭 목록에 따라 보여줄 위젯 리스트
  final List<Widget> _widgetOptions = <Widget>[
    const MapTab(),
    const MyRunsTab(),
    const ProfileTab(),
    const MessagesTab(), // 💡 4번: 이제 진짜 메시지 탭으로 교체!
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        // 선택된 탭 위젯 표시
        child: _widgetOptions.elementAt(_selectedIndex), 
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map), 
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run), 
            label: 'My Runs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // 프로필 아이콘
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat), 
            label: 'Messages',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800], 
        unselectedItemColor: Colors.grey, 
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, 
      ),
    );
  }
}