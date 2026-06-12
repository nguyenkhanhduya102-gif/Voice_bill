import 'package:flutter/material.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/pages/stock_entry_page.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/widgets/wave_pulse.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        AnimatedOpacity(
                          opacity: _animateIn ? 1 : 0,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          child: AnimatedSlide(
                            offset: _animateIn
                                ? Offset.zero
                                : const Offset(0, -0.04),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Hóa Đơn Giọng Nói',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                      color: context.brand,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hóa đơn nhanh từ giọng nói',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: context.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: constraints.maxHeight * 0.08),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateBillPage(),
                            ),
                          ),
                          child: Container(
                            width: 200,
                            height: 200,
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
                              child: WavePulse(size: 110, color: context.brand),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Chạm để nói',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: context.brand,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đọc tên mặt hàng để tạo hóa đơn ngay',
                          style: TextStyle(
                            fontSize: 15,
                            color: context.textSecondary,
                          ),
                        ),
                        SizedBox(height: constraints.maxHeight * 0.06),
                        AnimatedOpacity(
                          opacity: _animateIn ? 1 : 0,
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          child: AnimatedSlide(
                            offset: _animateIn
                                ? Offset.zero
                                : const Offset(0, 0.06),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: context.brand),
            ),
            const SizedBox(width: 16),
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
                    style: TextStyle(fontSize: 14, color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
