import 'package:flutter/material.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/pages/bill_detail_page.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/export_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';
import 'package:voice_bill/widgets/empty_state.dart';
import 'package:voice_bill/widgets/skeletons.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedTab = 0;
  bool _animateIn = false;
  final BillService _billService = BillService();
  final ExportService _exportService = ExportService();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  String _searchQuery = '';
  static const int _pageSize = 20;
  int _displayCount = _pageSize;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  static Widget _skeletonBuilder(int index) => const BillCardSkeleton();

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

    if (result == null) return;
    setState(() {
      _searchQuery = result.trim();
      _displayCount = _pageSize;
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _displayCount = _pageSize);
  }

  Future<void> _exportCsv() async {
    try {
      final path = await _exportService.exportBillsToCsv();
      _showSnack('Đã xuất: $path');
    } catch (_) {
      _showSnack('Không thể xuất dữ liệu');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Lịch sử hóa đơn'),
        actions: [
          IconButton(onPressed: _exportCsv, icon: const Icon(Icons.file_download)),
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
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                            _displayCount = _pageSize;
                          });
                        },
                      ),
                      _HistoryChip(
                        label: 'Đã thanh toán',
                        selected: _selectedTab == 1,
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                            _displayCount = _pageSize;
                          });
                        },
                      ),
                      _HistoryChip(
                        label: 'Ghi nợ',
                        selected: _selectedTab == 2,
                        onTap: () {
                          setState(() {
                            _selectedTab = 2;
                            _displayCount = _pageSize;
                          });
                        },
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const ListSkeleton(
                        itemBuilder: _skeletonBuilder,
                      ),
                    );
                  }

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
                        if (_selectedTab == 1) return bill.status == 'paid';
                        if (_selectedTab == 2) return bill.status == 'debt';
                        return true;
                      })
                      .where((bill) {
                        if (_searchQuery.isEmpty) return true;
                        final query = _searchQuery.toLowerCase();
                        final idMatch = bill.id.toLowerCase().contains(query);
                        final itemMatch = bill.items.any(
                          (item) => item.name.toLowerCase().contains(query),
                        );
                        return idMatch || itemMatch;
                      })
                      .toList();

                  final displayItems = filtered.take(_displayCount).toList();
                  final hasMore = _displayCount < filtered.length;

                  if (filtered.isEmpty) {
                    // Trống hẳn (chưa có hóa đơn) khác với lọc/tìm không ra.
                    final noInvoicesAtAll =
                        allItems.isEmpty && _searchQuery.isEmpty;
                    return RefreshIndicator(
                      key: _refreshKey,
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.1),
                          noInvoicesAtAll
                              ? EmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Chưa có hóa đơn nào',
                                  message:
                                      'Tạo hóa đơn đầu tiên bằng giọng nói — nhanh và dễ.',
                                  actionLabel: 'Tạo hóa đơn',
                                  actionIcon: Icons.mic,
                                  onAction: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CreateBillPage(),
                                    ),
                                  ),
                                )
                              : const EmptyState(
                                  icon: Icons.search_off,
                                  title: 'Không có hóa đơn phù hợp',
                                  message:
                                      'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
                                ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    key: _refreshKey,
                    onRefresh: _onRefresh,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        ...displayItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _HistoryCard(
                            item: item,
                            dateText: formatDate(item.createdAt),
                            amountText: formatCurrency(item.total),
                            statusText:
                                paymentLabel(item.status, item.paymentMethod),
                            isDark: isDark,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BillDetailPage(bill: item),
                              ),
                            ),
                          ),
                        )),
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _displayCount += _pageSize;
                                  });
                                },
                                child: Text(
                                  'Xem thêm (${filtered.length - _displayCount} còn lại)',
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateBillPage()),
        ),
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
      selectedColor: context.isDark
          ? const Color(0xFF2E4D33)
          : const Color(0xFFE8F5E9),
      backgroundColor: context.surface,
      side: BorderSide(
        color: selected ? context.brand : context.border,
      ),
      labelStyle: TextStyle(
        color: selected ? context.brand : context.textSecondary,
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
  final bool isDark;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.item,
    required this.dateText,
    required this.amountText,
    required this.statusText,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEFEFEF),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HĐ ${shortId(item.id).toUpperCase()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF1D1D1D),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: item.status == 'debt'
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateText,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amountText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1D1D1D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${item.items.length} mặt hàng',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
