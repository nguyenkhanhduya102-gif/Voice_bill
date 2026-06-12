import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/pages/create_bill_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/invoice_pdf_service.dart';
import 'package:voice_bill/services/profile_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';

class QrPaymentPage extends StatefulWidget {
  final BillRecord bill;

  const QrPaymentPage({super.key, required this.bill});

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  bool _animateIn = false;
  final ProfileService _profileService = ProfileService();
  final InvoicePdfService _pdfService = InvoicePdfService();
  final BillService _billService = BillService();
  UserProfile? _latestProfile;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sharePdf() async {
    final profile = _latestProfile;
    if (profile == null) {
      _showSnack('Chưa có thông tin hồ sơ');
      return;
    }
    try {
      final pdf = await _pdfService.buildPdf(bill: widget.bill, profile: profile);
      await Printing.sharePdf(bytes: pdf, filename: 'voicebill.pdf');
    } catch (e) {
      _showSnack('Lỗi chia sẻ PDF: $e');
    }
  }

  Future<void> _savePdf() async {
    final profile = _latestProfile;
    if (profile == null) {
      _showSnack('Chưa có thông tin hồ sơ');
      return;
    }
    try {
      final Uint8List pdf = await _pdfService.buildPdf(
        bill: widget.bill,
        profile: profile,
      );
      final dir = await getApplicationDocumentsDirectory();
      final label = widget.bill.invoiceNumber > 0
          ? 'HD-${widget.bill.invoiceNumber.toString().padLeft(6, '0')}'
          : shortId(widget.bill.id);
      final file = File('${dir.path}/hoa_don_$label.pdf');
      await file.writeAsBytes(pdf);
      _showSnack('Đã lưu: ${file.path}');
    } catch (e) {
      _showSnack('Lỗi lưu PDF: $e');
    }
  }

  void _showInvoiceDetail() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _billIdLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...widget.bill.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name)),
                      Text('${item.quantity} x ${formatCurrency(item.unitPrice)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tổng: ${formatCurrency(widget.bill.total)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLargeQr(Widget qrWidget) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mã QR'),
          content: SizedBox(width: 240, height: 240, child: qrWidget),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  String get _billIdLabel {
    if (widget.bill.invoiceNumber > 0) {
      return 'Hóa đơn ${_billService.formatInvoiceNumber(widget.bill.invoiceNumber)}';
    }
    return 'Hóa đơn ${shortId(widget.bill.id).toUpperCase()}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _buildVietQrPayload({
    required String bankBin,
    required String accountNumber,
    required String accountName,
    required int amount,
  }) {
    final name = _normalizeName(accountName.isNotEmpty ? accountName : 'VOICE');

    final merchantInfo =
        _tag('00', 'A000000727') +
        _tag('01', bankBin) +
        _tag('02', accountNumber) +
        _tag('08', 'QRIBFTTA');

    final payload = StringBuffer()
      ..write(_tag('00', '01'))
      ..write(_tag('01', '12'))
      ..write(_tag('38', merchantInfo))
      ..write(_tag('53', '704'))
      ..write(_tag('54', amount.toString()))
      ..write(_tag('58', 'VN'))
      ..write(_tag('59', name))
      ..write(_tag('60', 'HCM'))
      ..write('6304');

    final crc = _crc16(payload.toString());
    return '${payload.toString()}$crc';
  }

  String _normalizeName(String input) {
    final cleaned = input.trim().toUpperCase();
    if (cleaned.isEmpty) return 'VOICEBILL';
    return cleaned.length > 25 ? cleaned.substring(0, 25) : cleaned;
  }

  String _tag(String id, String value) {
    final length = value.length.toString().padLeft(2, '0');
    return '$id$length$value';
  }

  String _crc16(String input) {
    int crc = 0xFFFF;
    for (final codeUnit in input.codeUnits) {
      crc ^= (codeUnit << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
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
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(onPressed: _sharePdf, icon: const Icon(Icons.share)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            AnimatedOpacity(
              opacity: _animateIn ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: _animateIn ? Offset.zero : const Offset(0, 0.06),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.brand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hóa đơn đã sẵn sàng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InvoiceCard(
              bill: widget.bill,
              dateText: _formatDate(widget.bill.createdAt),
              amountText: formatCurrency(widget.bill.total),
              billIdLabel: _billIdLabel,
              onTap: _showInvoiceDetail,
            ),
            const SizedBox(height: 20),
            StreamBuilder<UserProfile>(
              stream: _profileService.streamProfile(),
              builder: (context, snapshot) {
                final profile =
                    snapshot.data ??
                    const UserProfile(
                      displayName: '',
                      storeName: '',
                      phone: '',
                      address: '',
                      photoUrl: '',
                      bankName: '',
                      bankShortName: '',
                      bankBin: '',
                      accountNumber: '',
                      accountName: '',
                      qrImageUrl: '',
                      qrMode: 'auto',
                    );

                _latestProfile = profile;
                final useImage =
                    profile.qrMode == 'image' && profile.qrImageUrl.isNotEmpty;
                final hasBank =
                    profile.bankBin.isNotEmpty &&
                    profile.accountNumber.isNotEmpty;
                final payload = (!useImage && hasBank)
                    ? _buildVietQrPayload(
                        bankBin: profile.bankBin,
                        accountNumber: profile.accountNumber,
                        accountName: profile.accountName.isNotEmpty
                            ? profile.accountName
                            : profile.storeName,
                        amount: widget.bill.total,
                      )
                    : null;

                final qrWidget = useImage
                    ? Image.network(
                        profile.qrImageUrl,
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                      )
                    : payload != null
                    ? QrImageView(
                        data: payload,
                        size: 180,
                        backgroundColor: Colors.white,
                      )
                    : const Icon(Icons.qr_code_2, size: 120, color: Color(0xFFBDBDBD));

                final bankLabel = profile.bankName.isNotEmpty
                    ? profile.bankName
                    : (profile.bankShortName.isNotEmpty ? profile.bankShortName : 'Chưa có ngân hàng');

                return _QrCard(
                  onTap: () => _showLargeQr(qrWidget),
                  qrWidget: qrWidget,
                  bankLabel: bankLabel,
                  accountNumber: profile.accountNumber,
                  accountName: profile.accountName.isNotEmpty ? profile.accountName : profile.storeName,
                  helperText: payload == null && !useImage
                      ? 'Vui lòng cập nhật ngân hàng trong Hồ sơ'
                      : 'Quét mã để thanh toán',
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _savePdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.save),
              label: const Text('Lưu PDF'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sharePdf,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: context.brand),
              ),
              icon: const Icon(Icons.share),
              label: const Text('Chia sẻ PDF'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CreateBillPage()),
              ),
              icon: Icon(Icons.add, color: context.brand),
              label: Text(
                'Tạo hóa đơn mới',
                style: TextStyle(color: context.brand, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final BillRecord bill;
  final String dateText;
  final String amountText;
  final String billIdLabel;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.bill,
    required this.dateText,
    required this.amountText,
    required this.billIdLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: context.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(billIdLabel),
                  const Spacer(),
                  Text(
                    bill.status == 'debt' ? 'Ghi nợ' : 'Đã xác nhận',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(dateText, style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              Divider(color: context.border),
              const SizedBox(height: 8),
              ...bill.items.map((item) {
                return _InvoiceLine(
                  name: item.name,
                  detail: '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                  total: formatCurrency(item.subtotal),
                );
              }),
              const SizedBox(height: 8),
              Divider(color: context.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    amountText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  final String name;
  final String detail;
  final String total;

  const _InvoiceLine({required this.name, required this.detail, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: context.textMuted)),
              ],
            ),
          ),
          Text(total, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget qrWidget;
  final String bankLabel;
  final String accountNumber;
  final String accountName;
  final String helperText;

  const _QrCard({
    required this.onTap,
    required this.qrWidget,
    required this.bankLabel,
    required this.accountNumber,
    required this.accountName,
    required this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: [
              Text(helperText, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              SizedBox(width: 180, height: 180, child: qrWidget),
              const SizedBox(height: 12),
              Text(bankLabel, style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 6),
              Text(
                accountNumber.isNotEmpty ? accountNumber : 'Chưa có STK',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                accountName.isNotEmpty ? accountName : 'Chưa có chủ TK',
                style: TextStyle(color: context.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
