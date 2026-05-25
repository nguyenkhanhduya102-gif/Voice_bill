import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:voice_bill/pages/profile_page.dart';
import 'package:voice_bill/services/gemini_service.dart';
import 'package:voice_bill/services/product_service.dart';

class StockEntryPage extends StatefulWidget {
  const StockEntryPage({super.key});

  @override
  State<StockEntryPage> createState() => _StockEntryPageState();
}

class _StockEntryPageState extends State<StockEntryPage> {
  bool _animateIn = false;
  final ProductService _productService = ProductService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();
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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
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
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
    );
  }

  Future<void> _handleVoiceText(String text) async {
    if (!_geminiService.hasKey) {
      _showSnack('Thiếu GEMINI_API_KEY, dùng nhập văn bản');
      return;
    }

    try {
      final parsed = await _geminiService.parseStockItems(text);
      if (parsed.isEmpty) {
        _showSnack('Không nhận diện được mặt hàng');
        return;
      }

      for (final item in parsed) {
        final name = (item['name'] ?? '').toString().trim();
        final unit = (item['unit'] ?? 'cai').toString().trim();
        final priceValue = (item['price'] as num?)?.toInt() ?? 0;
        if (name.isEmpty) {
          continue;
        }
        await _productService.addProduct(
          name: name,
          unit: unit.isEmpty ? 'cai' : unit,
          price: '${priceValue}d',
        );
      }
    } catch (_) {
      _showSnack('Không thể xử lý giọng nói');
    }
  }

  Future<void> _editItem(ProductItem item) async {
    final nameController = TextEditingController(text: item.name);
    final unitController = TextEditingController(text: item.unit);
    final priceController = TextEditingController(text: item.price);
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

    if (confirmed != true) {
      return;
    }

    final name = nameController.text.trim();
    final unit = unitController.text.trim();
    final price = priceController.text.trim();
    final stock = int.tryParse(stockController.text.trim()) ?? item.stock;
    if (name.isEmpty || unit.isEmpty) {
      return;
    }
    await _productService.updateProduct(
      id: item.id,
      name: name,
      unit: unit,
      price: price,
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

    if (result == null || result.trim().isEmpty) {
      return;
    }

    final parts = result.split(RegExp(r'[|,]')).map((e) => e.trim()).toList();
    if (parts.length < 3) {
      _showSnack('Nhập theo mẫu: Tên, Đơn vị, Giá');
      return;
    }

    final name = parts[0];
    final unit = parts[1];
    final price = parts[2];
    if (name.isEmpty || unit.isEmpty || price.isEmpty) {
      _showSnack('Thiếu thông tin mặt hàng');
      return;
    }

    try {
      await _productService.addProduct(name: name, unit: unit, price: price);
    } catch (_) {
      _showSnack('Chưa đăng nhập hoặc lỗi lưu dữ liệu');
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
                                    'Nhập hàng bằng giọng nói',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 24,
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _toggleListening,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: _WavePulse(size: 56),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _openTextEntry,
                          icon: const Icon(Icons.keyboard),
                          label: const Text('Nhập bằng văn bản'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Nhấn micro và đọc:\n\'Tên, số lượng, giá\'',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Danh sách nhập hàng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<List<ProductItem>>(
                        stream: _productService.streamProducts(),
                        builder: (context, snapshot) {
                          final items = snapshot.data ?? [];
                          if (items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Chưa có mặt hàng',
                                style: TextStyle(color: Colors.black38),
                              ),
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
            StreamBuilder<List<ProductItem>>(
              stream: _productService.streamProducts(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Row(
                  children: [
                    const Text(
                      'Lưu vào kho',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count mặt hàng',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
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
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: const Text(
                      'Lưu vào kho',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                            'Bạn có thể nói: "Táo 1 kg 20000".',
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE8E8),
                      borderRadius: BorderRadius.circular(22),
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

class _StockItemTile extends StatelessWidget {
  final ProductItem item;
  final VoidCallback onTap;

  const _StockItemTile({required this.item, required this.onTap});

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
                    Icons.local_grocery_store,
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
                        item.unit,
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

class _WavePulse extends StatefulWidget {
  final double size;

  const _WavePulse({required this.size});

  @override
  State<_WavePulse> createState() => _WavePulseState();
}

class _WavePulseState extends State<_WavePulse> {
  bool _scaleUp = true;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _scaleUp ? 0.95 : 1.05,
        end: _scaleUp ? 1.05 : 0.95,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _scaleUp = !_scaleUp),
      child: Icon(Icons.mic, size: widget.size, color: const Color(0xFFB7A7E5)),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
