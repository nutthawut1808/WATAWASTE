import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Standard network image with a shimmer placeholder.
class TheNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const TheNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    // คำนวณ memCache อัตโนมัติจากขนาด Pixel Device เพื่อไม่ให้ภาพแตกแต่ประหยัด RAM มหาศาล
    final density = MediaQuery.of(context).devicePixelRatio;
    final calculatedMemWidth = memCacheWidth ??
        (width != null && width != double.infinity
            ? (width! * density).round()
            : 800);
    final calculatedMemHeight = memCacheHeight ??
        (height != null && height != double.infinity
            ? (height! * density).round()
            : 600);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: calculatedMemWidth,
        memCacheHeight: calculatedMemHeight,
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(width: width, height: height, color: Colors.white),
        ),
        errorWidget: (context, _, __) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}