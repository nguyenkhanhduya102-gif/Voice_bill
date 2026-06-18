import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/models/product_item.dart';
import 'package:voice_bill/pages/qr_payment_page.dart';
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/product_service.dart';
import 'package:voice_bill/services/voice_controller.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/price_parser.dart';
import 'package:voice_bill/widgets/voice_recorder_overlay.dart';

class CreateBillPage extends StatefulWidget {
  /// Tự bật nghe ngay khi mở trang (cho lối "1 chạm" từ trang chủ / tab bán hàng).
  final bool autoStartListening;

  const CreateBillPage({super.key, this.autoStartListening = false});

  @override
  State<CreateBillPage> createState() => _CreateBillPageState();
}

class _CreateBillPageState extends State<CreateBillPage> {
  bool _animateIn = false;
  bool _submitting = false;
  final BillService _billService = BillService();
  final ProductService _productService = ProductService();
  final VoiceController _voiceController = VoiceController();
  final List<BillItem> _sellItems = [];
  List<ProductItem> _catalog = [];

  @override
  void initState() {
    super.initState();
    _voiceController.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _loadCatalog();
    Future.microtask(() {
      if (mounted) setState(() => _animateIn = true);
    });
    // Lối "1 chạm": vào trang là nghe luôn, không cần bấm mic lần nữa.
    if (widget.autoStartListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleListening();
      });
    }
  }

  @override
  void dispose() {
    _voiceController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final products = await _productService.fetchProducts();
      if (mounted) setState(() => _catalog = products);
    } catch (e) {
      debugPrint('Load catalog failed: $e');
    }
  }

  /// Tìm sản phẩm trùng tên (đã chuẩn hóa) trong kho.
  ProductItem? _resolveProduct(String name) {
    final key = name.trim().toLowerCase();
    for (final p in _catalog) {
      if (p.name.trim().toLowerCase() == key) return p;
    }
    return null;
  }

  String? _resolveProductId(String name) => _resolveProduct(name)?.id;

  /// Danh mục rút gọn để gửi cho Gemini (giúp khớp tên & tự điền giá).
  List<Map<String, dynamic>> get _catalogForPrompt => _catalog
      .map((p) => {'name': p.name, 'price': p.priceValue})
      .toList();

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String get _totalText => formatCurrency(_totalValue);

  int get _totalValue {
    return _sellItems
        .map((item) => item.subtotal)
        .fold<int>(0, (sum, value) => sum + value);
  }

  Future<void> _openTextEntry() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập mặt hàng'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Ví dụ: Táo, 2, 15000'),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    final parsed = _voiceController.parseSaleText(result);
    final items = _mapParsedToBillItems(parsed);

    if (items.isEmpty) {
      _showSnack('Nhập theo mẫu: Tên, số lượng, giá');
      return;
    }

    setState(() => _sellItems.addAll(items));
  }

  /// Chuyển kết quả parse (name/quantity/price) thành BillItem, đồng thời
  /// gắn productId nếu khớp được sản phẩm trong kho.
  List<BillItem> _mapParsedToBillItems(List<Map<String, dynamic>> parsed) {
    return parsed
        .map((item) {
          final name = (item['name'] ?? '').toString().trim();
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          var price = (item['price'] as num?)?.toInt() ?? 0;
          if (name.isEmpty) return null;

          // Khớp sản phẩm trong kho: gắn productId và TỰ ĐIỀN GIÁ nếu người
          // bán không đọc giá (vd "2 quả cam" -> lấy giá cam trong kho).
          final product = _resolveProduct(name);
          if (price <= 0 && product != null && product.priceValue > 0) {
            price = product.priceValue;
          }

          return BillItem(
            name: product?.name ?? name,
            quantity: quantity <= 0 ? 1 : quantity,
            unitPrice: price < 0 ? 0 : price,
            productId: product?.id,
            unit: product?.unit ?? '',
          );
        })
        .whereType<BillItem>()
        .toList();
  }

  Future<void> _toggleListening() async {
    final text = await VoiceRecorderOverlay.show(
      context,
      controller: _voiceController,
    );
    if (text == null || text.isEmpty) return;
    if (text == VoiceRecorderOverlay.manualEntrySignal) {
      await _openTextEntry();
      return;
    }
    await _handleVoiceText(text);
  }

  Future<void> _handleVoiceText(String text) async {
    if (text.isEmpty) return;

    try {
      final parsed = await _voiceController.parseSaleTextAsync(
        text,
        products: _catalogForPrompt,
      );

      final items = _mapParsedToBillItems(parsed);

      if (items.isEmpty) {
        _showSnack('Không nhận diện được mặt hàng từ giọng nói');
        return;
      }
      if (mounted) {
        setState(() => _sellItems.addAll(items));
        _showSnack('Đã thêm ${items.length} mặt hàng');
      }
    } catch (e) {
      debugPrint('Voice parse sale failed: $e');
      _showSnack('Không thể xử lý giọng nói');
    }
  }

  Future<void> _editItem(int index) async {
    final item = _sellItems[index];
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(text: '${item.quantity}');
    final priceController =
        TextEditingController(text: item.unitPrice.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chỉnh sửa mặt hàng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số lượng'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    final name = nameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? item.quantity;
    final price = parsePriceToInt(priceController.text.trim());
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();

    if (confirmed != true) return;
    if (name.isEmpty) return;
    setState(
      () => _sellItems[index] = BillItem(
        name: name,
        quantity: qty <= 0 ? 1 : qty,
        unitPrice: price,
        // Tên có thể đã đổi -> resolve lại; giữ productId cũ nếu vẫn khớp.
        productId: _resolveProductId(name) ?? item.productId,
        unit: _resolveProduct(name)?.unit ?? item.unit,
      ),
    );
  }

  /// Hiển thị bảng tóm tắt + chọn phương thức thanh toán.
  /// Trả về: 'cash' | 'transfer' | 'debt' | null (hủy).
  Future<String?> _showConfirmSheet() {
    final hasZeroPrice = _sellItems.any((i) => i.unitPrice <= 0);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xác nhận hóa đơn',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _sellItems
                        .map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.name}  (${item.quantity} x ${formatCurrency(item.unitPrice)})',
                                      style: TextStyle(
                                        color: item.unitPrice <= 0
                                            ? Colors.orange
                                            : context.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(formatCurrency(item.subtotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('Tổng cộng',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(_totalText,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (hasZeroPrice) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Có mặt hàng chưa nhập giá (0đ). Kiểm tra lại trước khi lưu.',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Chọn phương thức thanh toán',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary),
                ),
                const SizedBox(height: 10),
                _PayButton(
                  icon: Icons.payments_outlined,
                  label: 'Tiền mặt',
                  onTap: () => Navigator.of(context).pop('cash'),
                ),
                const SizedBox(height: 8),
                _PayButton(
                  icon: Icons.account_balance_outlined,
                  label: 'Chuyển khoản',
                  onTap: () => Navigator.of(context).pop('transfer'),
                ),
                const SizedBox(height: 8),
                _PayButton(
                  icon: Icons.schedule_outlined,
                  label: 'Ghi nợ',
                  outlined: true,
                  onTap: () => Navigator.of(context).pop('debt'),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Quay lại'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBill() async {
    if (_submitting) return;
    if (_sellItems.isEmpty) {
      _showSnack('Chưa có mặt hàng để xuất hóa đơn');
      return;
    }

    final method = await _showConfirmSheet();
    if (method == null) return;

    // 'debt' -> ghi nợ (chưa thu); 'cash'/'transfer' -> đã thu kèm phương thức.
    final status = method == 'debt' ? 'debt' : 'paid';
    final paymentMethod = method == 'debt' ? '' : method;

    setState(() => _submitting = true);
    _showSnack('Đang lưu hóa đơn...');
    try {
      final bill = await _billService
          .createBill(
            items: _sellItems,
            total: _totalValue,
            status: status,
            paymentMethod: paymentMethod,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      HapticFeedback.mediumImpact(); // báo đã lưu xong cho người mắt kém
      // Chỉ chuyển khoản mới cần QR; tiền mặt/ghi nợ -> màn "đã lưu" gọn.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QrPaymentPage(
            bill: bill,
            showQr: paymentMethod == 'transfer',
          ),
        ),
      );
    } on TimeoutException {
      _showSnack('Lưu hóa đơn bị timeout, thử lại');
    } catch (error) {
      debugPrint('Create bill failed: $error');
      _showSnack('Không thể lưu hóa đơn');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ đơn đang tạo?'),
        content: const Text(
            'Đơn này chưa lưu. Thoát ra sẽ mất các mặt hàng đã thêm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Bỏ đơn'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _sellItems.isEmpty || _submitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back, color: context.textPrimary),
                        tooltip: 'Quay lại',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VoiceBill',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            AnimatedOpacity(
                              opacity: _animateIn ? 1 : 0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              child: AnimatedSlide(
                                offset: _animateIn ? Offset.zero : const Offset(0, 0.05),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Bán hàng bằng giọng nói',
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: context.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfilePage()),
                        ),
                        icon: Icon(Icons.settings, color: context.brand),
                        tooltip: 'Cài đặt',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleListening(),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: context.isDark
                                      ? const Color(0xFF2A2A3A)
                                      : const Color(0xFFF3F0FF),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(Icons.mic, size: 52, color: context.brand),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Bấm để nói',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _voiceController.isOnline ? Icons.wifi : Icons.wifi_off,
                                  size: 14,
                                  color: _voiceController.isOnline ? Colors.green : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _voiceController.isOnline ? 'Đã kết nối' : 'Đang ngoại tuyến',
                                  style: TextStyle(fontSize: 12, color: _voiceController.isOnline ? Colors.green : Colors.orange),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openTextEntry,
                            icon: const Icon(Icons.keyboard),
                            label: const Text('Nhập bằng bàn phím'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.surface,
                              foregroundColor: context.brand,
                              elevation: 0,
                              side: BorderSide(color: context.brand),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Danh sách bán hàng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (_sellItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: context.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.border),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.mic_none,
                                  size: 32, color: context.brand),
                              const SizedBox(height: 8),
                              Text(
                                'Chưa có mặt hàng nào',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Chạm nút mic và đọc, ví dụ:\n“2 lon coca 15 nghìn”',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._sellItems.asMap().entries.map(
                          (entry) => _BillItemTile(
                            item: entry.value,
                            onTap: () => _editItem(entry.key),
                          ),
                        ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Tổng cộng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary),
                ),
                const Spacer(),
                Text(
                  _totalText,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _confirmBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.receipt_long),
                    label: Text(
                      _submitting ? 'Đang lưu...' : 'Xác nhận hóa đơn',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Trợ giúp nhập giọng nói'),
                          content: const Text('Bạn có thể nói: "Táo 2 15000, Cam 1 12000".'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Đã hiểu'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33FFB3B3),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.help_outline, color: Colors.redAccent),
                  ),
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

class _BillItemTile extends StatelessWidget {
  final BillItem item;
  final VoidCallback onTap;

  const _BillItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: context.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: context.textPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${item.quantity} x ${formatCurrency(item.unitPrice)}',
                              style: TextStyle(color: context.textSecondary)),
                          if (item.unitPrice <= 0) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_amber_rounded,
                                size: 14, color: Colors.orange),
                            const Text(' Chưa có giá',
                                style: TextStyle(fontSize: 12, color: Colors.orange)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(item.subtotal),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.edit, size: 15, color: context.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút chọn phương thức thanh toán (to, rõ — hợp người lớn tuổi).
class _PayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _PayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
    final padding = const EdgeInsets.symmetric(vertical: 15);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final textStyle =
        const TextStyle(fontSize: 17, fontWeight: FontWeight.w700);

    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.brand,
                side: BorderSide(color: context.brand),
                padding: padding,
                shape: shape,
                textStyle: textStyle,
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brand,
                foregroundColor: Colors.white,
                padding: padding,
                shape: shape,
                textStyle: textStyle,
              ),
              child: child,
            ),
    );
  }
}
