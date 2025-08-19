// lib/features/shell/view/main_screen.dart
import 'package:flutter/material.dart';
// 경로 수정
import 'package:video_saver/features/browser/view/browser_screen.dart';
import 'package:video_saver/features/downloads/view/downloads_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    BrowserScreen(),
    DownloadsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        // IndexedStack을 사용해 화면 상태를 유지합니다.
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.public), label: '웹 검색'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_done),
            label: '다운로드',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
