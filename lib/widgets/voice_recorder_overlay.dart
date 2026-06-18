import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:voice_bill/services/voice_controller.dart';
import 'package:voice_bill/utils/app_theme.dart';

class VoiceRecorderOverlay {
  /// Giá trị trả về đặc biệt khi người dùng chọn "Nhập tay" — trang gọi sẽ
  /// mở ô nhập văn bản thay vì xử lý như kết quả giọng nói.
  static const String manualEntrySignal = '__MANUAL_ENTRY__';

  static Future<String?> show(
    BuildContext context, {
    required VoiceController controller,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _VoiceRecorderSheet(controller: controller),
    );
  }
}

class _VoiceRecorderSheet extends StatefulWidget {
  final VoiceController controller;
  const _VoiceRecorderSheet({required this.controller});

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet>
    with SingleTickerProviderStateMixin {
  // Cho người lớn tuổi thêm thời gian nói, đỡ vội.
  static const int _listenSeconds = 20;

  int _secondsLeft = _listenSeconds;
  String _transcribedText = '';
  String _livePartial = '';
  String _statusText = 'Đang nghe...';
  bool _isDone = false;
  bool _hasError = false;
  Timer? _countdown;
  late AnimationController _pulseAnim;
  bool _didListen = false;
  VoidCallback? _previousStateCallback;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Tạm chiếm callback trạng thái để hiển thị chữ trực tiếp + lỗi micro ngay
    // trên overlay, khôi phục lại khi đóng (trang cha dùng nó cho chỉ báo online).
    _previousStateCallback = widget.controller.onStateChanged;
    widget.controller.onStateChanged = _onControllerStateChanged;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    if (widget.controller.state == STTState.error && !_isDone) {
      _countdown?.cancel();
      HapticFeedback.heavyImpact(); // báo lỗi bằng rung để người mắt kém biết
      setState(() {
        _hasError = true;
        _isDone = true;
        _statusText = widget.controller.lastError ?? 'Không thể nghe, thử lại';
      });
      SemanticsService.sendAnnouncement(View.of(context), _statusText, TextDirection.ltr);
      return;
    }
    // Cập nhật chữ nghe được tạm thời để hiện trực tiếp khi đang nói.
    final partial = widget.controller.partialWords;
    if (!_isDone && partial.isNotEmpty && partial != _livePartial) {
      setState(() => _livePartial = partial);
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _pulseAnim.dispose();
    widget.controller.onStateChanged = _previousStateCallback;
    if (!_didListen) {
      widget.controller.stopListening();
    }
    super.dispose();
  }

  void _start() {
    // Phản hồi "giờ nói được rồi" cho người mắt kém: rung nhẹ + tiếng click.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    final view = View.of(context);
    SemanticsService.sendAnnouncement(view, 'Đang nghe', TextDirection.ltr);

    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
          _finalize();
        }
      });
    });

    widget.controller.startListening(
      timeout: const Duration(seconds: _listenSeconds),
      onResult: (text) {
        if (!mounted) return;
        _didListen = true;
        _countdown?.cancel();
        HapticFeedback.lightImpact(); // báo "đã nghe xong"
        setState(() {
          _transcribedText = text;
          _statusText = 'Đã nhận';
          _isDone = true;
        });
        SemanticsService.sendAnnouncement(view, 'Đã nhận giọng nói', TextDirection.ltr);
      },
    );
  }

  void _finalize() {
    if (_isDone) return;
    _didListen = true;
    widget.controller.stopListening();
    HapticFeedback.heavyImpact();
    setState(() {
      _isDone = true;
      _statusText = 'Không nghe rõ, hãy thử lại';
      _hasError = true;
    });
    SemanticsService.sendAnnouncement(View.of(context), 'Không nghe rõ, hãy thử lại', TextDirection.ltr);
  }

  /// Nghe lại từ đầu mà không phải đóng overlay.
  void _retry() {
    _countdown?.cancel();
    widget.controller.stopListening();
    setState(() {
      _secondsLeft = _listenSeconds;
      _transcribedText = '';
      _livePartial = '';
      _statusText = 'Đang nghe...';
      _isDone = false;
      _hasError = false;
      _didListen = false;
    });
    _start();
  }

  void _confirm() {
    _didListen = true;
    if (_transcribedText.isNotEmpty) {
      Navigator.of(context).pop(_transcribedText);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _manualEntry() {
    _countdown?.cancel();
    _didListen = true;
    widget.controller.stopListening();
    Navigator.of(context).pop(VoiceRecorderOverlay.manualEntrySignal);
  }

  void _dismissCancel() {
    _countdown?.cancel();
    _didListen = true;
    widget.controller.stopListening();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final brand = context.brand;
    final hasTranscript = _transcribedText.isNotEmpty;
    // Màn đang chờ kết quả nhưng không gom được chữ -> cho Thử lại / Nhập tay.
    final needsRetry = _isDone && !hasTranscript;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              final scale =
                  _isDone ? 1.0 : 1.0 + (_pulseAnim.value * 0.08);
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _hasError
                    ? Colors.red.withValues(alpha: 0.12)
                    : brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasError
                    ? Icons.mic_off
                    : (_isDone ? Icons.check_circle : Icons.mic),
                size: 36,
                color: _hasError ? Colors.red : brand,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _hasError ? Colors.red : context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isDone) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 18, color: context.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${_secondsLeft}s',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Chữ trực tiếp khi đang nói; chưa có thì hiện gợi ý mẫu câu.
            _livePartial.isNotEmpty
                ? Text(
                    _livePartial,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: brand,
                      height: 1.4,
                    ),
                  )
                : Text(
                    'Hãy đọc, ví dụ:\n“2 lon coca 15 nghìn”',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
          ],
          if (hasTranscript)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Text(
                _transcribedText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Nút hành động theo trạng thái.
          if (hasTranscript) ...[
            _primaryButton('Xác nhận', Icons.check, _confirm),
            const SizedBox(height: 8),
            _secondaryButton('Nói lại', Icons.refresh, _retry),
          ] else if (needsRetry) ...[
            _primaryButton('Thử lại', Icons.refresh, _retry),
            const SizedBox(height: 8),
            _secondaryButton('Nhập tay', Icons.keyboard, _manualEntry),
          ],
          const SizedBox(height: 8),
          _cancelButton(),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.brand,
          side: BorderSide(color: context.brand),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _dismissCancel,
        icon: const Icon(Icons.close, size: 20),
        label: Text(_isDone ? 'Bỏ qua' : 'Hủy'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
