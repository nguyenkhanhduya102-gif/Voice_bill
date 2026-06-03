import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/pages/qr_payment_page.dart';
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/services/bill_service.dart';
import 'package:voice_bill/services/gemini_service.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/utils/price_parser.dart';
import 'package:voice_bill/widgets/wave_pulse.dart';

class CreateBillPage extends StatefulWidget {
  const CreateBillPage({super.key});

  @override
  State<CreateBillPage> createState() => _CreateBillPageState();
}

class _CreateBillPageState extends State<CreateBillPage> {
  bool _animateIn = false;
  bool _submitting = false;
  final BillService _billService = BillService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  final List<BillItem> _sellItems = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String get _totalText {
    final total = _sellItems
        .map((item) => parsePriceToInt(item.price) * item.quantity)
        .fold<int>(0, (sum, value) => sum + value);
    return formatCurrency(total);
  }

  int get _totalValue {
    return _sellItems
      .map((item) => parsePriceToInt(item.price) * item.quantity)
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

    if (result == null || result.trim().isEmpty) {
      return;
    }

    final itemsToAdd = _parseTextItems(result);

    if (itemsToAdd.isEmpty) {
      _showSnack('Nhập theo mẫu: Tên, số lượng, giá');
      return;
    }

    setState(() => _sellItems.addAll(itemsToAdd));
  }

  List<BillItem> _parseTextItems(String rawText) {
    final List<BillItem> itemsToAdd = [];
    final entries = rawText.split(RegExp(r'[\n;]'));
    for (final raw in entries) {
      final value = raw.trim();
      if (value.isEmpty) {
        continue;
      }

      final parts = value.split(',');
      if (parts.length < 3) {
        continue;
      }

      final name = parts[0].trim();
      final quantityText = parts[1].trim();
      final priceText = parts[2].trim();
      if (name.isEmpty) {
        continue;
      }

      final quantity = int.tryParse(quantityText) ?? 1;
      final priceValue = parsePriceToInt(priceText);
      if (quantity <= 0 || priceValue < 0) {
        continue;
      }
      itemsToAdd.add(
        BillItem(
          name: name,
          quantity: quantity,
          price: formatCurrency(priceValue),
        ),
      );
    }

    return itemsToAdd;
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) async {
        if (status == 'done' && _isListening) {
          setState(() => _isListening = false);
        }
      },
    );
    if (!available) {
      _showSnack('Không thể khởi tạo micro');
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: 'vi_VN',
      onResult: (result) async {
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            await _handleVoiceText(text);
          }
        }
      },
    );
  }

  Future<void> _handleVoiceText(String text) async {
    if (!_geminiService.hasKey) {
      _showSnack('Thiếu GEMINI_API_KEY, dùng nhập văn bản');
      final fallback = _parseTextItems(text);
      if (fallback.isNotEmpty) {
        setState(() => _sellItems.addAll(fallback));
      }
      return;
    }

    try {
      final parsed = await _geminiService.parseSaleItems(text);
      final items = parsed
          .map((item) {
            final name = (item['name'] ?? '').toString().trim();
            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toInt() ?? 0;
            if (name.isEmpty) {
              return null;
            }
            return BillItem(
              name: name,
              quantity: quantity <= 0 ? 1 : quantity,
              price: formatCurrency(price < 0 ? 0 : price),
            );
          })
          .whereType<BillItem>()
          .toList();

      if (items.isEmpty) {
        _showSnack('Không nhận diện được mặt hàng từ giọng nói');
        return;
      }
      setState(() => _sellItems.addAll(items));
    } catch (_) {
      _showSnack('Không thể xử lý giọng nói');
    }
  }

  Future<void> _editItem(int index) async {
    final item = _sellItems[index];
    final nameController = TextEditingController(text: item.name);
    final qtyController = TextEditingController(text: '${item.quantity}');
    final priceController = TextEditingController(text: item.price);

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

    if (confirmed != true) {
      return;
    }

    final name = nameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? item.quantity;
    final price = parsePriceToInt(priceController.text.trim());
    if (name.isEmpty) {
      return;
    }
    setState(
      () => _sellItems[index] = BillItem(
        name: name,
        quantity: qty <= 0 ? 1 : qty,
        price: formatCurrency(price),
      ),
    );
  }

  Future<void> _confirmBill() async {
    if (_submitting) {
      return;
    }
    if (_sellItems.isEmpty) {
      _showSnack('Chưa có mặt hàng để xuất hóa đơn');
      return;
    }

    setState(() => _submitting = true);
    _showSnack('Đang lưu hóa đơn...');
    try {
      final bill = await _billService
          .createBill(items: _sellItems, total: _totalValue)
          .timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => QrPaymentPage(bill: bill)));
    } on TimeoutException {
      _showSnack('Lưu hóa đơn bị timeout, thử lại');
    } catch (error) {
      debugPrint('Create bill failed: $error');
      _showSnack('Không thể lưu hóa đơn');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VoiceBill',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedOpacity(
                              opacity: _animateIn ? 1 : 0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              child: AnimatedSlide(
                                offset: _animateIn
                                    ? Offset.zero
                                    : const Offset(0, 0.05),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Bán hàng bằng giọng nói',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        ),
                        icon: const Icon(Icons.settings, color: Colors.black87),
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
                            InkWell(
                              borderRadius: BorderRadius.circular(80),
                              onTap: _toggleListening,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? const Color(0xFFE8E1FF)
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
                                child: const Center(
                                  child: WavePulse(size: 90),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isListening ? 'Đang nghe...' : 'Bấm để nói',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ví dụ: "Táo, 2, 15000"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                height: 1.3,
                              ),
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
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFE5E5E5)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Danh sách bán hàng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_sellItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có mặt hàng',
                            style: TextStyle(color: Colors.black38),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
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
                const Text(
                  'Tổng cộng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  _totalText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
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
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text(
                      'Xác nhận hóa đơn',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
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
                          content: const Text(
                            'Bạn có thể nói: "Táo 2 15000, Cam 1 12000".',
                          ),
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
                    child: const Icon(
                      Icons.help_outline,
                      color: Colors.redAccent,
                    ),
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

class _BillItemTile extends StatelessWidget {
  final BillItem item;
  final VoidCallback onTap;

  const _BillItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEDEDED)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity} x',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
