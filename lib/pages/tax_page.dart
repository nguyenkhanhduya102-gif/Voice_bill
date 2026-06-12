import 'package:flutter/material.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/services/tax_rules.dart';
import 'package:voice_bill/services/tax_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';
import 'package:voice_bill/widgets/empty_state.dart';

/// Giai đoạn 1: "Sổ doanh thu & cảnh báo ngưỡng".
/// Theo dõi doanh thu năm dương lịch, cảnh báo mốc 1 tỷ, ước tính thuế theo
/// bậc, nhắc hạn nộp Mẫu 01/TKN-CNKD và xuất Sổ S1a.
class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  final TaxService _service = TaxService();
  late int _nam;
  Future<TaxYearSummary>? _future;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _nam = DateTime.now().year;
    _load();
  }

  void _load() {
    setState(() {
      _future = _service.tongHopNam(_nam);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export(TaxYearSummary summary) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _service.xuatSoDoanhThuS1a(summary);
      _showSnack('Đã xuất Sổ S1a: $path');
    } catch (_) {
      _showSnack('Không thể xuất sổ');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        surfaceTintColor: context.surface,
        foregroundColor: context.textPrimary,
        title: const Text('Thuế & Báo cáo'),
        actions: [
          PopupMenuButton<int>(
            initialValue: _nam,
            onSelected: (value) {
              _nam = value;
              _load();
            },
            itemBuilder: (context) {
              final thisYear = DateTime.now().year;
              return [
                for (var y = thisYear; y >= thisYear - 3; y--)
                  PopupMenuItem(value: y, child: Text('Năm $y')),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('Năm $_nam',
                      style: TextStyle(color: context.textPrimary)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<TaxYearSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorRetry(onRetry: _load);
            }
            final s = snapshot.data;
            if (s == null) return _ErrorRetry(onRetry: _load);
            return _buildContent(s);
          },
        ),
      ),
    );
  }

  Widget _buildContent(TaxYearSummary s) {
    // Năm chưa phát sinh hóa đơn -> màn hướng dẫn thay vì "0đ" cụt lủn.
    if (s.soHoaDon == 0) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          EmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'Năm ${s.nam} chưa có doanh thu',
            message:
                'Khi bạn bán hàng, doanh thu sẽ được ghi nhận và hiển thị ở đây.',
            actionLabel: 'Bán hàng',
            actionIcon: Icons.mic,
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateBillPage()),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _RevenueCard(summary: s),
        const SizedBox(height: 14),
        _ThresholdWarning(summary: s),
        _EstimateCard(summary: s),
        const SizedBox(height: 14),
        _ObligationCard(summary: s),
        const SizedBox(height: 14),
        _ExportButton(
          exporting: _exporting,
          onExport: () => _export(s),
        ),
        const SizedBox(height: 16),
        const _Disclaimer(),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? bg;
  const _Card({required this.child, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg ?? context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: child,
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final TaxYearSummary summary;
  const _RevenueCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.tyLe * 100).clamp(0, 999).toStringAsFixed(0);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: context.brand),
              const SizedBox(width: 8),
              Text('Doanh thu năm ${summary.nam}',
                  style: TextStyle(
                      fontSize: 14, color: context.textSecondary)),
              const Spacer(),
              _TierBadge(bac: summary.bac),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCurrency(summary.doanhThu),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          Text('${summary.soHoaDon} hóa đơn',
              style: TextStyle(fontSize: 13, color: context.textMuted)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.tyLe.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: context.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                summary.trangThai == NguongStatus.daVuot
                    ? Colors.red
                    : summary.trangThai == NguongStatus.sapVuot
                        ? Colors.orange
                        : context.brand,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$pct% của ngưỡng miễn thuế 1 tỷ',
              style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final TaxTier bac;
  const _TierBadge({required this.bac});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (bac) {
      TaxTier.mienThue => ('Miễn thuế', Colors.green),
      TaxTier.tu1Den3Ty => ('1–3 tỷ', Colors.orange),
      TaxTier.tu3Den50Ty => ('3–50 tỷ', Colors.deepOrange),
      TaxTier.tren50Ty => ('> 50 tỷ', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ThresholdWarning extends StatelessWidget {
  final TaxYearSummary summary;
  const _ThresholdWarning({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.trangThai == NguongStatus.antoan) {
      return const SizedBox.shrink();
    }
    final daVuot = summary.trangThai == NguongStatus.daVuot;
    final color = daVuot ? Colors.red : Colors.orange;
    final text = daVuot
        ? 'Doanh thu đã vượt 1 tỷ. Từ quý sau bạn bắt buộc dùng hóa đơn điện tử '
            'và chuyển sang diện kê khai (nhóm 1–3 tỷ).'
        : 'Doanh thu sắp chạm ngưỡng 1 tỷ. Khi vượt, bạn sẽ phải dùng hóa đơn '
            'điện tử và kê khai thuế. Hãy chuẩn bị trước.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Card(
        bg: color.withValues(alpha: 0.10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13.5, color: context.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  final TaxYearSummary summary;
  const _EstimateCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final est = summary.uocTinh;
    if (summary.bac == TaxTier.mienThue) {
      return _Card(
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Được MIỄN thuế GTGT & TNCN (doanh thu ≤ 1 tỷ/năm). '
                'Chỉ cần nộp thông báo doanh thu.',
                style: TextStyle(fontSize: 13.5, color: context.textPrimary),
              ),
            ),
          ],
        ),
      );
    }
    if (!est.tinhDuoc) {
      return _Card(
        child: Text(
          'Bậc này tính thuế trên thu nhập (doanh thu − chi phí được trừ). '
          'Cần nhập chi phí mua vào để ước tính — tính năng sẽ có ở bản sau.',
          style: TextStyle(fontSize: 13.5, color: context.textPrimary),
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ước tính thuế (PP1 — trên doanh thu)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
          const SizedBox(height: 4),
          Text('Ngành: ${summary.nganh.label}',
              style: TextStyle(fontSize: 12, color: context.textMuted)),
          const SizedBox(height: 12),
          _row(context, 'GTGT (${summary.nganh.gtgtPercent}% doanh thu)',
              est.gtgt),
          const SizedBox(height: 6),
          _row(context, 'TNCN (${summary.nganh.tncnPercent}% phần vượt 1 tỷ)',
              est.tncn),
          Divider(color: context.border, height: 24),
          _row(context, 'Tổng tạm tính', est.tong, bold: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value,
      {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 15 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: context.textPrimary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: style.copyWith(color: context.textSecondary))),
        Text(formatCurrency(value), style: style),
      ],
    );
  }
}

class _ObligationCard extends StatelessWidget {
  final TaxYearSummary summary;
  const _ObligationCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final han = summary.hanNopThongBao;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nghĩa vụ cần làm',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary)),
          const SizedBox(height: 12),
          if (summary.bac == TaxTier.mienThue) ...[
            _item(context, Icons.description_outlined,
                'Nộp Mẫu 01/TKN-CNKD (thông báo doanh thu)',
                'Hạn chậm nhất: ${formatDate(han)}'),
            _item(context, Icons.account_balance_outlined,
                'Đăng ký tài khoản ngân hàng/ví trên eTax Mobile',
                'Bắt buộc với hộ kinh doanh'),
            _item(context, Icons.menu_book_outlined,
                'Ghi Sổ doanh thu (Mẫu S1a)',
                'Xuất file bên dưới để lưu/nộp'),
          ] else ...[
            _item(context, Icons.receipt_long_outlined,
                'Dùng hóa đơn điện tử (HĐĐT)',
                'Bắt buộc khi doanh thu > 1 tỷ'),
            _item(context, Icons.description_outlined,
                'Nộp tờ khai 01/CNKD theo quý',
                'Hạn: cuối tháng đầu của quý sau'),
          ],
        ],
      ),
    );
  }

  Widget _item(
      BuildContext context, IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14, color: context.textPrimary)),
                Text(sub,
                    style:
                        TextStyle(fontSize: 12.5, color: context.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final bool exporting;
  final VoidCallback onExport;
  const _ExportButton({required this.exporting, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: exporting ? null : onExport,
      icon: exporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      label: const Text('Xuất Sổ doanh thu (S1a) — CSV'),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.brand,
        side: BorderSide(color: context.brand),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      '* Số liệu chỉ mang tính tham khảo, không thay thế tư vấn thuế. '
      'Ứng dụng không nộp tờ khai thay bạn. Hãy đối chiếu với cơ quan thuế/'
      'kế toán trước khi kê khai.',
      style: TextStyle(
          fontSize: 12, color: context.textMuted, fontStyle: FontStyle.italic),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: context.textMuted, size: 40),
          const SizedBox(height: 12),
          Text('Không tải được số liệu',
              style: TextStyle(color: context.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
