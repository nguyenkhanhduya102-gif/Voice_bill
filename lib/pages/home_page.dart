import 'package:flutter/material.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/pages/stock_entry_page.dart';

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
      if (mounted) {
        setState(() => _animateIn = true);
      }
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
      backgroundColor: Colors.white,
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
                        const SizedBox(height: 32),
                        const SizedBox(height: 12),
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
                            child: const Center(
                              child: Column(
                                children: [
                                  Text(
                                    'VoiceBill',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 32,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Hóa đơn nhanh từ giọng nói',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: constraints.maxHeight * 0.12),
                        const _WavePulse(),
                        const SizedBox(height: 32),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FeatureTile(
                                  icon: Icons.receipt_long,
                                  title: 'Bán hàng bằng giọng nói',
                                  description:
                                      'Đọc tên mặt hàng để hệ thống tự tính và lên hóa đơn.',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CreateBillPage(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _FeatureTile(
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
                                const SizedBox(height: 10),
                              ],
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
        overlayColor: MaterialStateProperty.all(Colors.transparent),
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
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

class _WavePulse extends StatefulWidget {
  const _WavePulse();

  @override
  State<_WavePulse> createState() => _WavePulseState();
}

class _WavePulseState extends State<_WavePulse> {
  bool _scaleUp = true;

  @override
  Widget build(BuildContext context) {
    const double baseSize = 160;
    const double iconSize = 90;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _scaleUp ? 0.95 : 1.05,
        end: _scaleUp ? 1.05 : 0.95,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _scaleUp = !_scaleUp),
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.mic, size: iconSize, color: Color(0xFFB7A7E5)),
        ),
      ),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
