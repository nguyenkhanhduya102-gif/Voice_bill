import 'package:flutter/material.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/pages/history_page.dart';
import 'package:voice_bill/pages/home_page.dart';
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/pages/stock_entry_page.dart';
import 'package:voice_bill/pages/warehouse_page.dart';

class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    WarehousePage(),
    HistoryPage(),
    ProfilePage(),
  ];

  int get _navIndex => _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;

  void _openQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: Colors.black87,
                  ),
                  title: const Text('Bán hàng bằng giọng nói'),
                  subtitle: const Text('Đọc tên mặt hàng để lên hóa đơn nhanh'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(builder: (_) => const CreateBillPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.black87,
                  ),
                  title: const Text('Nhập hàng bằng giọng nói'),
                  subtitle: const Text('Đọc tên, số lượng, giá để lưu vào kho'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(builder: (_) => const StockEntryPage()),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 2) {
            _openQuickActions();
            return;
          }

          final int pageIndex = index > 2 ? index - 1 : index;
          setState(() => _currentIndex = pageIndex);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.black45,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Kho',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Tạo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
