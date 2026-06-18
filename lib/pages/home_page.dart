import 'package:flutter/material.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/pages/stock_entry_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/coach_marks.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/widgets/wave_pulse.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BillService _billService = BillService();
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Tên app gọn ở trên.
                    Text(
                      'Hóa Đơn Giọng Nói',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: context.brand,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Bảng tin: doanh thu hôm nay.
                    _TodayCard(billService: _billService),
                    const SizedBox(height: 28),
                    // Nút bán hàng bằng giọng nói (hành động chính).
                    Semantics(
                      label: 'Bán hàng bằng giọng nói',
                      hint: 'Chạm hai lần để tạo hóa đơn',
                      button: true,
                      child: GestureDetector(
                      key: coachKeyMic,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const CreateBillPage(autoStartListening: true),
                        ),
                      ),
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: context.isDark
                                ? [
                                    context.brand.withValues(alpha: 0.18),
                                    context.brand.withValues(alpha: 0.08),
                                  ]
                                : const [
                                    Color(0xFFE8F5E9),
                                    Color(0xFFC8E6C9),
                                  ],
                            center: Alignment.center,
                            radius: 0.9,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.brand.withValues(alpha: 0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: WavePulse(size: 104, color: context.brand),
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Chạm để bán hàng',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: context.brand,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đọc tên mặt hàng để tạo hóa đơn ngay',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedOpacity(
                      opacity: _animateIn ? 1 : 0,
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      child: _FeatureTile(
                        icon: Icons.inventory_2_rounded,
                        title: 'Nhập hàng bằng giọng nói',
                        description:
                            'Đọc tên, số lượng, giá để lưu nhanh vào kho.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StockEntryPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ "doanh thu hôm nay" — giá trị thực dụng khi mở app mỗi ngày.
class _TodayCard extends StatelessWidget {
  final BillService billService;
  const _TodayCard({required this.billService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BillRecord>>(
      stream: billService.streamBills(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final bills = (snapshot.data ?? []).where((b) {
          final d = b.createdAt;
          return d != null &&
              d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        }).toList();
        final total = bills.fold<int>(0, (acc, b) => acc + b.total);
        final count = bills.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.today, size: 18, color: context.brand),
                  const SizedBox(width: 8),
                  Text(
                    'Doanh thu hôm nay',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCurrency(total),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count hóa đơn',
                style: TextStyle(fontSize: 14, color: context.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: context.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                          fontSize: 14, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
