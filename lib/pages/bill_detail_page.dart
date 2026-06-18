import 'package:flutter/material.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';

class BillDetailPage extends StatefulWidget {
  final BillRecord bill;

  const BillDetailPage({super.key, required this.bill});

  @override
  State<BillDetailPage> createState() => _BillDetailPageState();
}

class _BillDetailPageState extends State<BillDetailPage> {
  final BillService _billService = BillService();
  bool _busy = false;

  BillRecord get bill => widget.bill;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa hóa đơn'),
        content: const Text(
          'Xóa hẳn hóa đơn này? Tồn kho đã trừ sẽ được hoàn lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _billService.deleteBill(bill);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xóa hóa đơn'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _undoDelete(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Delete bill failed: $e');
      if (mounted) {
        setState(() => _busy = false);
        _snack('Không thể xóa hóa đơn');
      }
    }
  }

  Future<void> _undoDelete() async {
    try {
      await _billService.createBill(
        items: bill.items,
        total: bill.total,
        status: bill.status,
        paymentMethod: bill.paymentMethod,
      );
      _snack('Đã hoàn tác xóa hóa đơn');
    } catch (e) {
      debugPrint('Undo delete bill failed: $e');
      _snack('Không thể hoàn tác');
    }
  }

  Future<void> _markPaid() async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Khách đã thanh toán bằng?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.payments_outlined, color: context.brand),
                title: const Text('Tiền mặt'),
                onTap: () => Navigator.of(context).pop('cash'),
              ),
              ListTile(
                leading:
                    Icon(Icons.account_balance_outlined, color: context.brand),
                title: const Text('Chuyển khoản'),
                onTap: () => Navigator.of(context).pop('transfer'),
              ),
            ],
          ),
        ),
      ),
    );
    if (method == null) return;

    setState(() => _busy = true);
    try {
      await _billService.markBillPaid(bill.id, method);
      if (!mounted) return;
      _snack('Đã cập nhật: ${paymentLabel('paid', method)}');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Mark bill paid failed: $e');
      if (mounted) {
        setState(() => _busy = false);
        _snack('Không thể cập nhật');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = formatDate(bill.createdAt);
    final billLabel = bill.invoiceNumber > 0
        ? _billService.formatInvoiceNumber(bill.invoiceNumber)
        : 'HĐ ${shortId(bill.id).toUpperCase()}';
    final isDebt = bill.status == 'debt';
    final statusLabel = paymentLabel(bill.status, bill.paymentMethod);

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
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Chi tiết hóa đơn',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Xóa hóa đơn',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Container(
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
                      Text(
                        billLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDebt
                              ? (context.isDark
                                  ? const Color(0xFF4A3320)
                                  : const Color(0xFFFFF3E0))
                              : (context.isDark
                                  ? const Color(0xFF2E4D33)
                                  : const Color(0xFFE8F5E9)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDebt
                                ? const Color(0xFFE65100)
                                : context.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: context.textMuted),
                      const SizedBox(width: 6),
                      Text(dateText,
                          style: TextStyle(color: context.textMuted)),
                    ],
                  ),
                  if (bill.sellerName.isNotEmpty ||
                      bill.sellerTaxCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(color: context.border, height: 1),
                    const SizedBox(height: 8),
                    if (bill.sellerName.isNotEmpty)
                      Text(bill.sellerName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary)),
                    if (bill.sellerTaxCode.isNotEmpty)
                      Text('MST: ${bill.sellerTaxCode}',
                          style: TextStyle(
                              fontSize: 13, color: context.textMuted)),
                    if (bill.sellerAddress.isNotEmpty)
                      Text(bill.sellerAddress,
                          style: TextStyle(
                              fontSize: 13, color: context.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Danh sách mặt hàng',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary),
            ),
            const SizedBox(height: 12),
            ...bill.items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                              style:
                                  TextStyle(color: context.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(item.subtotal),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    'Tổng cộng',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrency(bill.total),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.brand),
                  ),
                ],
              ),
            ),
            if (isDebt) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _markPaid,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Cập nhật đã thanh toán'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
