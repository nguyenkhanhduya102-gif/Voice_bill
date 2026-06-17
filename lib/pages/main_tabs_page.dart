import 'package:flutter/material.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/pages/history_page.dart';
import 'package:voice_bill/pages/home_page.dart';
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/pages/warehouse_page.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/coach_marks.dart';

class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Lần đầu vào màn chính -> chạy chỉ dẫn từng bước (coach marks) một lần.
    if (!coachController.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Chờ animation màn chủ ổn định rồi mới rọi đèn.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _currentIndex == 0) {
            showCoachMarks(context, onDone: coachController.markSeen);
          }
        });
      });
    }
  }

  final List<Widget> _pages = const [
    HomePage(),
    WarehousePage(),
    HistoryPage(),
    ProfilePage(),
  ];

  int get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

  // Hành động số 1 (bán hàng) chỉ một chạm — đi thẳng, không qua bảng chọn.
  void _openSell() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateBillPage(autoStartListening: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        iconSize: 26,
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 2) {
            _openSell();
            return;
          }

          final int pageIndex = index > 2 ? index - 1 : index;
          setState(() => _currentIndex = pageIndex);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: context.surface,
        selectedItemColor: context.brand,
        unselectedItemColor: context.textMuted,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded, key: coachKeyKho),
            label: 'Kho',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_rounded, key: coachKeyTao),
            label: 'Bán hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long, key: coachKeyLichSu),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded, key: coachKeyHoSo),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
