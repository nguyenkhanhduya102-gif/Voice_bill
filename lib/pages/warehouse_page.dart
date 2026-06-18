import 'dart:async';

import 'package:flutter/material.dart';
import 'package:voice_bill/models/product_item.dart';
import 'package:voice_bill/pages/stock_entry_page.dart';
import 'package:voice_bill/services/product_service.dart';
import 'package:voice_bill/utils/app_theme.dart';
import 'package:voice_bill/utils/currency_formatter.dart';
import 'package:voice_bill/widgets/empty_state.dart';
import 'package:voice_bill/widgets/skeletons.dart';

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  bool _animateIn = false;
  bool _filterActive = false;
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  String _searchQuery = '';
  Timer? _searchDebounce;
  static const int _lowStockThreshold = 5;
  static const int _pageSize = 20;
  int _displayCount = _pageSize;

  static Widget _productSkeletonBuilder(int index) => const ProductTileSkeleton();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchController.text.trim();
            _displayCount = _pageSize;
          });
        }
      });
    });
    Future.microtask(() {
      if (mounted) {
        setState(() => _animateIn = true);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _onRefresh() async {
    setState(() => _displayCount = _pageSize);
  }

  void _showItemDetail(ProductItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _DetailRow(label: 'Đơn vị', value: item.unit),
              const SizedBox(height: 10),
              _DetailRow(label: 'Giá', value: formatCurrency(item.priceValue)),
              const SizedBox(height: 10),
              _DetailRow(label: 'Tồn kho', value: '${item.stock}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editItem(item),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Sửa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(item),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Xoá'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editItem(ProductItem item) async {
    Navigator.of(context).pop();
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

    try {
      await _productService.updateProduct(
        id: item.id,
        name: name,
        unit: unit,
        priceValue: priceValue,
        stock: stock < 0 ? 0 : stock,
      );
      _showSnack('Đã cập nhật');
    } catch (e) {
      debugPrint('Update product failed: $e');
      _showSnack('Không thể cập nhật');
    }
  }

  Future<void> _confirmDelete(ProductItem item) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá mặt hàng'),
        content: Text('Xoá "${item.name}" khỏi kho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _productService.deleteProduct(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xoá "${item.name}"'),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () => _undoDeleteProduct(item),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Delete product failed: $e');
      _showSnack('Không thể xoá mặt hàng');
    }
  }

  Future<void> _undoDeleteProduct(ProductItem item) async {
    try {
      await _productService.addProduct(
        name: item.name,
        unit: item.unit,
        priceValue: item.priceValue,
        stock: item.stock,
      );
      _showSnack('Đã hoàn tác xoá "${item.name}"');
    } catch (e) {
      debugPrint('Undo delete product failed: $e');
      _showSnack('Không thể hoàn tác');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => _searchController.text = '',
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: AnimatedOpacity(
                opacity: _animateIn ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  offset: _animateIn ? Offset.zero : const Offset(0, 0.06),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm mặt hàng',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: context.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _filterActive = !_filterActive;
                            _displayCount = _pageSize;
                          });
                          _showSnack(
                            _filterActive ? 'Đã bật lọc tồn thấp' : 'Đã tắt lọc',
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _filterActive
                                ? (context.isDark ? const Color(0xFF2E4D33) : const Color(0xFFE8F5E9))
                                : context.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.tune,
                            color: _filterActive ? context.brand : context.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ProductItem>>(
                stream: _productService.streamProducts(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const ListSkeleton(
                        itemBuilder: _productSkeletonBuilder,
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  // Kho trống hẳn (chưa có sản phẩm nào) -> màn hướng dẫn.
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      key: _refreshKey,
                      onRefresh: _onRefresh,
                      child: ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                          EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Kho còn trống',
                            message:
                                'Nhập hàng bằng giọng nói để thêm sản phẩm vào kho.',
                            actionLabel: 'Nhập hàng',
                            actionIcon: Icons.mic,
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StockEntryPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final lowStockCount = items
                      .where((item) => item.stock <= _lowStockThreshold)
                      .length;

                  final filtered = items.where((item) {
                    final matchesQuery = _searchQuery.isEmpty ||
                        item.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                    final matchesFilter =
                        !_filterActive || item.stock <= _lowStockThreshold;
                    return matchesQuery && matchesFilter;
                  }).toList();

                  final displayItems = filtered.take(_displayCount).toList();
                  final hasMore = _displayCount < filtered.length;

                  return RefreshIndicator(
                    key: _refreshKey,
                    onRefresh: _onRefresh,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: 'Tổng mặt hàng',
                                    value: '${items.length}',
                                    accentColor: context.brand,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    title: 'Sắp hết hàng',
                                    value: '$lowStockCount',
                                    accentColor: const Color(0xFFD65D1D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Danh sách mặt hàng',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${filtered.length} mặt hàng',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (displayItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.search_off,
                              title: 'Không tìm thấy mặt hàng',
                              message: _filterActive
                                  ? 'Không có mặt hàng nào sắp hết. Thử tắt bộ lọc.'
                                  : 'Thử từ khóa khác hoặc xóa ô tìm kiếm.',
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= displayItems.length) {
                                  return null;
                                }
                                final item = displayItems[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: _InventoryTile(
                                    item: item,
                                    onTap: () => _showItemDetail(item),
                                  ),
                                );
                              },
                              childCount: displayItems.length,
                            ),
                          ),
                        if (hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _displayCount += _pageSize;
                                    });
                                  },
                                  child: Text(
                                    'Xem thêm (${filtered.length - _displayCount} còn lại)',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 80),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StockEntryPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm mặt hàng'),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: TextStyle(color: context.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Nền/viền suy ra từ màu nhấn -> tự hợp cả sáng lẫn tối.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final ProductItem item;
  final VoidCallback onTap;

  const _InventoryTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEFEFEF),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: context.brand,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1D1D1D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(item.priceValue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1D1D1D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.stock}',
                      style: TextStyle(
                        color: item.stock <= 5
                            ? Colors.redAccent
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
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
