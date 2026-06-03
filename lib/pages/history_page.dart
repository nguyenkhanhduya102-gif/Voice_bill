import 'package:flutter/material.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/pages/bill_detail_page.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedTab = 0;
  bool _animateIn = false;
  final BillService _billService = BillService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tìm kiếm hóa đơn'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Nhập từ khóa'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Tìm'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }
    setState(() => _searchQuery = result.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Lịch sử hóa đơn',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: _openSearch, icon: const Icon(Icons.search)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: AnimatedOpacity(
                opacity: _animateIn ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: _animateIn ? Offset.zero : const Offset(0, 0.06),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: Wrap(
                    spacing: 10,
                    children: [
                      _HistoryChip(
                        label: 'Tất cả',
                        selected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      _HistoryChip(
                        label: 'Đã thanh toán',
                        selected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                      _HistoryChip(
                        label: 'Ghi nợ',
                        selected: _selectedTab == 2,
                        onTap: () => setState(() => _selectedTab = 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<BillRecord>>(
                stream: _billService.streamBills(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Không đọc được hóa đơn: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final allItems = snapshot.data ?? [];
                  final filtered = allItems
                      .where((bill) {
                        if (_selectedTab == 1) {
                          return bill.status == 'paid';
                        }
                        if (_selectedTab == 2) {
                          return bill.status == 'debt';
                        }
                        return true;
                      })
                      .where((bill) {
                        if (_searchQuery.isEmpty) {
                          return true;
                        }
                        final query = _searchQuery.toLowerCase();
                        final idMatch = bill.id.toLowerCase().contains(query);
                        final itemMatch = bill.items.any(
                          (item) => item.name.toLowerCase().contains(query),
                        );
                        return idMatch || itemMatch;
                      })
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có hóa đơn nào',
                        style: TextStyle(color: Colors.black45),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _HistoryCard(
                        item: item,
                        dateText: formatDate(item.createdAt),
                        amountText: formatCurrency(item.total),
                        statusText: item.status == 'debt'
                            ? 'Ghi nợ'
                            : 'Đã thanh toán',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BillDetailPage(bill: item),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateBillPage())),
        backgroundColor: Colors.black87,
        child: const Icon(Icons.mic, color: Colors.white),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFF2F2F2),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE5E5E5)),
      labelStyle: TextStyle(
        color: selected ? Colors.black87 : Colors.black54,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final BillRecord item;
  final String dateText;
  final String amountText;
  final String statusText;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.dateText,
    required this.amountText,
    required this.statusText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEFEFEF)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'HĐ ${shortId(item.id).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(dateText, style: const TextStyle(color: Colors.black45)),
                  const Spacer(),
                  Text(
                    amountText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${item.items.length} mặt hàng',
                style: const TextStyle(color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
