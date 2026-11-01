import 'package:flutter/material.dart';
import 'package:dpos/core/theme/app_theme.dart';

/// Shimmer effect dasar berbasis Flutter Animation Controller (tanpa package eksternal)
class SyupeoShimmer extends StatefulWidget {
  const SyupeoShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  @override
  State<SyupeoShimmer> createState() => _SyupeoShimmerState();
}

class _SyupeoShimmerState extends State<SyupeoShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              colors: [
                widget.baseColor,
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
                widget.baseColor,
              ],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2.5 - 1.25), 0.0, 0.0);
  }
}

/// Kotak/tulang shimmer tunggal
class ShimmerBone extends StatelessWidget {
  const ShimmerBone({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// ── Skeleton Card Khusus Paket Usaha (Starter Kit Carousel) ──
/// Meniru layout kartu Carousel: notch badge pojok kanan atas, title, harga besar, checklist item
class StarterKitCardSkeleton extends StatelessWidget {
  const StarterKitCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 560,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SyupeoShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top notch & Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerBone(width: 170, height: 22, borderRadius: 6),
                Container(
                  width: 90,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Price row
            const Row(
              children: [
                ShimmerBone(width: 60, height: 14),
                SizedBox(width: 8),
                ShimmerBone(width: 140, height: 28),
              ],
            ),
            const SizedBox(height: 10),

            // Subtitle
            const ShimmerBone(width: double.infinity, height: 12),
            const SizedBox(height: 6),
            const ShimmerBone(width: 200, height: 12),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x0F000000)),
            const SizedBox(height: 16),

            // Checklist section
            const ShimmerBone(width: 130, height: 11),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(
                  6,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShimmerBone(
                            width: double.infinity,
                            height: 13,
                            borderRadius: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Bottom action button bone
            const ShimmerBone(width: double.infinity, height: 48, borderRadius: 100),
          ],
        ),
      ),
    );
  }
}

/// ── Skeleton Tile Khusus Wilayah Selector ──
class WilayahTileSkeleton extends StatelessWidget {
  const WilayahTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SyupeoShimmer(
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBone(width: 140, height: 14),
                  SizedBox(height: 4),
                  ShimmerBone(width: 80, height: 10),
                ],
              ),
            ),
            const ShimmerBone(width: 14, height: 14, borderRadius: 100),
          ],
        ),
      ),
    );
  }
}

/// ── Skeleton Card Khusus Produk Kasir (Grid) ──
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image box placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBone(width: 110, height: 13, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBone(width: 70, height: 10, borderRadius: 4),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBone(width: 65, height: 14, borderRadius: 4),
                      ShimmerBone(width: 24, height: 24, borderRadius: 8),
                    ],
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

/// ── Grid Shimmer Khusus Kasir POS (Responsif) ──
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.itemCount = 8});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth >= 1200
        ? 5
        : screenWidth >= 850
            ? 4
            : screenWidth >= 550
                ? 3
                : 2;

    final childAspectRatio = crossAxisCount >= 4
        ? 0.78
        : crossAxisCount >= 3
            ? 0.76
            : 0.74;

    return SyupeoShimmer(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ProductCardSkeleton(),
                childCount: itemCount,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
}

/// ── List Row Skeleton Khusus Produk Kasir List Mode ──
class ProductListItemSkeleton extends StatelessWidget {
  const ProductListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          ShimmerBone(width: 48, height: 48, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBone(width: 80, height: 11, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerBone(width: 70, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}

/// ── List View Shimmer Khusus Produk Kasir (List Mode) ──
class ProductListSkeleton extends StatelessWidget {
  const ProductListSkeleton({super.key, this.itemCount = 8});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SyupeoShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) => const ProductListItemSkeleton(),
      ),
    );
  }
}

/// ── List Shimmer Khusus Outlet/Transaksi/Daftar Kartu Umum ──
/// ── List Shimmer Khusus Outlet / Transaksi / Daftar Kartu Umum ──
class OutletCardSkeleton extends StatelessWidget {
  const OutletCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: const SyupeoShimmer(
        child: Row(
          children: [
            ShimmerBone(width: 56, height: 56, borderRadius: 16),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBone(width: 150, height: 16, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBone(width: 100, height: 12, borderRadius: 4),
                ],
              ),
            ),
            ShimmerBone(width: 24, height: 24, borderRadius: 100),
          ],
        ),
      ),
    );
  }
}

class GeneralCardSkeleton extends StatelessWidget {
  const GeneralCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: const SyupeoShimmer(
        child: Row(
          children: [
            ShimmerBone(width: 40, height: 40, borderRadius: 10),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBone(width: 160, height: 16),
                  SizedBox(height: 6),
                  ShimmerBone(width: 100, height: 12),
                ],
              ),
            ),
            ShimmerBone(width: 20, height: 20, borderRadius: 100),
          ],
        ),
      ),
    );
  }
}
