import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:voice_bill/utils/app_theme.dart';

/// GlobalKey dùng chung để coach marks "rọi đèn" vào đúng nút thật.
/// Gắn ở home_page (mic) và main_tabs_page (các tab).
final coachKeyMic = GlobalKey();
final coachKeyKho = GlobalKey();
final coachKeyTao = GlobalKey();
final coachKeyLichSu = GlobalKey();
final coachKeyHoSo = GlobalKey();

/// Hiển thị chỉ dẫn từng bước trên giao diện thật (kiểu tân thủ game).
void showCoachMarks(BuildContext context, {VoidCallback? onDone}) {
  final targets = <TargetFocus>[
    _target(
      coachKeyMic,
      'Bán hàng bằng giọng nói',
      'Chạm vào đây rồi đọc tên hàng và giá — app tự lên hóa đơn.',
      shape: ShapeLightFocus.Circle,
      align: ContentAlign.bottom,
    ),
    _target(
      coachKeyKho,
      'Kho hàng',
      'Xem và quản lý hàng tồn trong kho ở đây.',
      align: ContentAlign.top,
    ),
    _target(
      coachKeyTao,
      'Bán hàng nhanh',
      'Chạm để bán hàng bằng giọng nói — chỉ một chạm.',
      align: ContentAlign.top,
    ),
    _target(
      coachKeyLichSu,
      'Lịch sử',
      'Xem lại tất cả hóa đơn bạn đã tạo.',
      align: ContentAlign.top,
    ),
    _target(
      coachKeyHoSo,
      'Hồ sơ',
      'Cài đặt cửa hàng, ngân hàng và xem lại hướng dẫn.',
      align: ContentAlign.top,
    ),
  ];

  TutorialCoachMark(
    targets: targets,
    colorShadow: Colors.black,
    opacityShadow: 0.85,
    textSkip: 'BỎ QUA',
    paddingFocus: 8,
    onFinish: () => onDone?.call(),
    onSkip: () {
      onDone?.call();
      return true;
    },
  ).show(context: context);
}

TargetFocus _target(
  GlobalKey key,
  String title,
  String body, {
  ShapeLightFocus shape = ShapeLightFocus.RRect,
  ContentAlign align = ContentAlign.bottom,
}) {
  return TargetFocus(
    identify: title,
    keyTarget: key,
    shape: shape,
    radius: 14,
    enableOverlayTab: true, // chạm bất kỳ đâu để qua bước
    contents: [
      TargetContent(
        align: align,
        builder: (context, controller) => _CoachBubble(title: title, body: body),
      ),
    ],
  );
}

class _CoachBubble extends StatelessWidget {
  final String title;
  final String body;
  const _CoachBubble({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.brand,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 18, color: context.brand),
              const SizedBox(width: 6),
              Text(
                'Chạm để tiếp tục',
                style: TextStyle(fontSize: 13, color: context.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
