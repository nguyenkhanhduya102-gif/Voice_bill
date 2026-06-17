import 'package:flutter/material.dart';
import 'package:voice_bill/utils/app_theme.dart';

/// Hướng dẫn ban đầu — thiết kế cho người lớn tuổi: ít màn, chữ to, ví dụ rõ,
/// nút lớn. Hiện lần đầu mở app; có thể mở lại từ Hồ sơ.
class OnboardingPage extends StatefulWidget {
  /// true: chạy lần đầu (xong sẽ đánh dấu đã xem). false: mở lại để xem (xong pop).
  final bool isFirstRun;

  const OnboardingPage({super.key, this.isFirstRun = true});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      icon: Icons.storefront_rounded,
      title: 'Hóa Đơn Giọng Nói',
      body: 'Bán hàng và ghi hóa đơn chỉ bằng giọng nói — không cần gõ chữ.',
    ),
    _SlideData(
      icon: Icons.mic_rounded,
      title: 'Chỉ cần nói',
      body: 'Chạm nút mic, rồi đọc tên hàng và giá. App tự tính tiền và lên '
          'hóa đơn cho bạn.',
      example: '2 lon coca 15 nghìn',
    ),
    _SlideData(
      icon: Icons.verified_rounded,
      title: 'Luôn được xem lại',
      body: 'Trước khi lưu luôn có bước kiểm tra. Đọc chưa đúng? Chạm '
          '“Thử lại” hoặc “Nhập tay”.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  void _finish() {
    if (widget.isFirstRun) {
      onboardingController.markSeen(); // root rebuild -> sang AuthGate
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Nút bỏ qua / đóng ở góc.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    widget.isFirstRun ? 'Bỏ qua' : 'Đóng',
                    style: TextStyle(
                        fontSize: 15, color: context.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _Slide(data: _slides[i]),
              ),
            ),
            // Chấm chỉ trang.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? context.brand : context.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  child: Text(_isLast ? 'Bắt đầu dùng' : 'Tiếp'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String body;
  final String? example;
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
    this.example,
  });
}

class _Slide extends StatelessWidget {
  final _SlideData data;
  const _Slide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: context.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 68, color: context.brand),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.45,
              color: context.textSecondary,
            ),
          ),
          if (data.example != null) ...[
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.record_voice_over,
                      size: 22, color: context.brand),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '“${data.example}”',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
