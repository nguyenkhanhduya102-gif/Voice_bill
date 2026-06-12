import 'package:flutter/material.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/date_formatter.dart';
import 'package:voice_bill/utils/short_id.dart';

class BillDetailPage extends StatelessWidget {
  final BillRecord bill;

  const BillDetailPage({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final dateText = formatDate(bill.createdAt);
    final billService = BillService();
    final billLabel = bill.invoiceNumber > 0
        ? billService.formatInvoiceNumber(bill.invoiceNumber)
        : 'HĐ ${shortId(bill.id).toUpperCase()}';
    final isDebt = bill.status == 'debt';

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
        title: const Text(
          'Chi tiết hóa đơn',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDebt
                              ? (context.isDark ? const Color(0xFF4A3320) : const Color(0xFFFFF3E0))
                              : (context.isDark ? const Color(0xFF2E4D33) : const Color(0xFFE8F5E9)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isDebt ? 'Ghi nợ' : 'Đã thanh toán',
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
                      Icon(Icons.calendar_today, size: 14, color: context.textMuted),
                      const SizedBox(width: 6),
                      Text(dateText, style: TextStyle(color: context.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Danh sách mặt hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
            ),
            const SizedBox(height: 12),
            ...bill.items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text('${item.quantity} x ${formatCurrency(item.unitPrice)}', style: TextStyle(color: context.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(item.subtotal),
                      style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(
                    'Tổng cộng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    formatCurrency(bill.total),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.brand),
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
