import 'package:flutter/material.dart';
import 'package:voice_bill/models/product_item.dart';
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/services/product_service.dart';
import 'package:voice_bill/services/voice_controller.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/widgets/voice_recorder_overlay.dart';

class StockEntryPage extends StatefulWidget {
  const StockEntryPage({super.key});

  @override
  State<StockEntryPage> createState() => _StockEntryPageState();
}

class _StockEntryPageState extends State<StockEntryPage> {
  bool _animateIn = false;
  final ProductService _productService = ProductService();
  final VoiceController _voiceController = VoiceController();
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
  }

  Future<void> _loadCatalog() async {
    try {
      final products = await _productService.fetchProducts();
      if (mounted) setState(() => _catalog = products);
    } catch (_) {
      // Không nạp được danh mục thì vẫn nhập bình thường (Gemini không gợi ý khớp tên).
    }
  }

  // Danh mục rút gọn gửi cho Gemini để khớp tên/giá.
  List<Map<String, dynamic>> get _catalogForPrompt =>
      _catalog.map((p) => {'name': p.name, 'price': p.priceValue}).toList();

  @override
  void dispose() {
    _voiceController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
      final parsed = await _voiceController.parseStockTextAsync(
        text,
        products: _catalogForPrompt,
      );
      if (parsed.isEmpty) {
        _showSnack('Không nhận diện được mặt hàng');
        return;
      }
      await _reviewAndSave(parsed);
    } catch (_) {
      _showSnack('Không thể xử lý giọng nói');
    }
  }

  /// Chuyển kết quả parse thành draft và mở màn xác nhận trước khi lưu.
  Future<void> _reviewAndSave(List<Map<String, dynamic>> parsed) async {
    final drafts = parsed
        .map((m) => _StockDraft.fromMap(m))
        .where((d) => d.name.isNotEmpty)
        .toList();
    if (drafts.isEmpty) {
      _showSnack('Không nhận diện được mặt hàng');
      return;
    }

    final confirmed = await _showStockConfirmSheet(drafts);
    if (confirmed != true) return;

    try {
      final result = await _productService.upsertProducts(
        drafts.map((d) => d.toMap()).toList(),
      );
      await _loadCatalog();
      if (!mounted) return;
      final parts = <String>[];
      if (result.added > 0) parts.add('${result.added} mặt hàng mới');
      if (result.merged > 0) parts.add('${result.merged} mặt hàng cộng dồn');
      _showSnack('Đã lưu: ${parts.isEmpty ? '0 mặt hàng' : parts.join(', ')}');
    } catch (_) {
      if (mounted) _showSnack('Không thể lưu vào kho');
    }
  }

  /// Tên đã tồn tại trong kho? (khớp lowercase+trim — Phase 2 sẽ nâng bỏ dấu).
  bool _existsInCatalog(String name) {
    final key = name.trim().toLowerCase();
    return _catalog.any((p) => p.name.trim().toLowerCase() == key);
  }

  /// Bottom sheet duyệt lại danh sách nhập: sửa số lượng/giá, badge Mới/Đã có,
  /// cảnh báo giá 0. Trả true nếu người dùng bấm "Lưu vào kho".
  Future<bool?> _showStockConfirmSheet(List<_StockDraft> drafts) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final hasZeroPrice = drafts.any((d) => d.price <= 0);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xác nhận nhập kho',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Soát lại và sửa trước khi lưu',
                        style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: drafts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _draftRow(
                          drafts[i],
                          onChanged: () => setSheet(() {}),
                          onEdit: () async {
                            await _editDraft(drafts[i]);
                            setSheet(() {});
                          },
                        ),
                      ),
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
                              'Có mặt hàng chưa nhập giá (0đ). Bấm vào dòng để sửa.',
                              style:
                                  TextStyle(color: Colors.orange, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            child: const Text('Lưu vào kho'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _draftRow(_StockDraft d,
      {required VoidCallback onChanged, required VoidCallback onEdit}) {
    final exists = _existsInCatalog(d.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(d.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      _badge(exists ? 'Đã có' : 'Mới', exists),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.unit} · ${formatCurrency(d.price)}'
                    '${d.price <= 0 ? '  ⚠ chưa có giá' : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        color: d.price <= 0 ? Colors.orange : context.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          // Bộ tăng/giảm số lượng.
          _qtyStepper(d, onChanged),
        ],
      ),
    );
  }

  Widget _qtyStepper(_StockDraft d, VoidCallback onChanged) {
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            if (d.quantity > 1) {
              d.quantity--;
              onChanged();
            }
          },
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('${d.quantity}',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: context.textPrimary)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            d.quantity++;
            onChanged();
          },
          icon: Icon(Icons.add_circle_outline, color: context.brand),
        ),
      ],
    );
  }

  Widget _badge(String text, bool exists) {
    final color = exists ? Colors.orange : context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  /// Sửa tên/đơn vị/giá của một draft (số lượng dùng stepper ở dòng).
  Future<void> _editDraft(_StockDraft d) async {
    final nameController = TextEditingController(text: d.name);
    final unitController = TextEditingController(text: d.unit);
    final priceController = TextEditingController(text: d.price.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa mặt hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên')),
            const SizedBox(height: 8),
            TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Đơn vị')),
            const SizedBox(height: 8),
            TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lưu')),
        ],
      ),
    );

    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final price = ProductItem.parsePriceToInt(priceController.text.trim());
    nameController.dispose();
    unitController.dispose();
    priceController.dispose();

    if (ok != true) return;
    if (name.isNotEmpty) d.name = name;
    if (unit.isNotEmpty) d.unit = unit;
    d.price = price;
  }

  Future<void> _editItem(ProductItem item) async {
    final nameController = TextEditingController(text: item.name);
    final unitController = TextEditingController(text: item.unit);
    final priceController =
        TextEditingController(text: item.priceValue.toString());
    final stockController = TextEditingController(text: '${item.stock}');

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
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Đơn vị'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Giá'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tồn kho'),
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
    final unit = unitController.text.trim();
    final priceValue = ProductItem.parsePriceToInt(priceController.text.trim());
    final stock = int.tryParse(stockController.text.trim()) ?? item.stock;
    nameController.dispose();
    unitController.dispose();
    priceController.dispose();
    stockController.dispose();

    if (confirmed != true) return;
    if (name.isEmpty || unit.isEmpty) return;
    await _productService.updateProduct(
      id: item.id,
      name: name,
      unit: unit,
      priceValue: priceValue,
      stock: stock < 0 ? 0 : stock,
    );
  }

  Future<void> _openTextEntry() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập hàng'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Táo | 1 cân | 50.000đ',
            ),
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

    final parsed = _voiceController.parseStockText(result);
    if (parsed.isEmpty) {
      _showSnack('Nhập theo mẫu: Tên, Đơn vị, Giá');
      return;
    }

    await _reviewAndSave(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                    'Nhập hàng bằng giọng nói',
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
                            const SizedBox(height: 6),
                            Text(
                              'Ví dụ: "Táo, 1 kg, 20000"',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: context.textSecondary, height: 1.3),
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
                        'Danh sách nhập hàng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<ProductItem>>(
                        stream: _productService.streamProducts(),
                        builder: (context, snapshot) {
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Chưa có mặt hàng', style: TextStyle(color: context.textMuted)),
                            );
                          }

                          return Column(
                            children: items
                                .map(
                                  (item) => _StockItemTile(
                                    item: item,
                                    onTap: () => _editItem(item),
                                  ),
                                )
                                .toList(),
                          );
                        },
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
            StreamBuilder<List<ProductItem>>(
              stream: _productService.streamProducts(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Row(
                  children: [
                    Text(
                      'Lưu vào kho',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                    const Spacer(),
                    Text(
                      '$count mặt hàng',
                      style: TextStyle(fontSize: 16, color: context.textSecondary),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openTextEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text(
                      'Lưu vào kho',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
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
                          content: const Text('Bạn có thể nói: "Táo 1 kg 20000".'),
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
    );
  }
}

class _StockItemTile extends StatelessWidget {
  final ProductItem item;
  final VoidCallback onTap;

  const _StockItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: context.surfaceAlt,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF332D4D)
                      : const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF7C4DFF),
                  size: 22,
                ),
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
                    Text(item.unit, style: TextStyle(color: context.textSecondary)),
                  ],
                ),
              ),
              Text(
                formatCurrency(item.priceValue),
                style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mặt hàng nhập đang chờ xác nhận (có thể sửa trước khi lưu).
class _StockDraft {
  String name;
  String unit;
  int price;
  int quantity;

  _StockDraft({
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  factory _StockDraft.fromMap(Map<String, dynamic> m) {
    return _StockDraft(
      name: (m['name'] ?? '').toString().trim(),
      unit: (m['unit'] ?? 'cái').toString().trim(),
      price: (m['price'] as num?)?.toInt() ?? 0,
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit.isEmpty ? 'cái' : unit,
        'priceValue': price < 0 ? 0 : price,
        'quantity': quantity <= 0 ? 1 : quantity,
      };
}
