import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
      highlightColor: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFFAFAFA),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class BillCardSkeleton extends StatelessWidget {
  const BillCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 100, height: 18),
          SizedBox(height: 10),
          SkeletonBox(width: 140, height: 20),
          SizedBox(height: 8),
          Row(
            children: [
              SkeletonBox(width: 80, height: 14),
              Spacer(),
              SkeletonBox(width: 80, height: 18),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: 80, height: 14),
        ],
      ),
    );
  }
}

class ProductTileSkeleton extends StatelessWidget {
  const ProductTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 44, height: 44, borderRadius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 18),
                SizedBox(height: 6),
                SkeletonBox(width: 60, height: 14),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 70, height: 18),
              SizedBox(height: 6),
              SkeletonBox(width: 30, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: itemBuilder(i),
      )),
    );
  }
}
