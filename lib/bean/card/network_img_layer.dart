import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:logger/logger.dart';

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    this.quality,
    this.origAspectRatio,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final int? quality;
  final double? origAspectRatio;

  int _getStableCacheSize(BuildContext context, double size) {
    final px = size * MediaQuery.of(context).devicePixelRatio;
    // Use 150px buckets to minimize re-decoding during resize
    const bucket = 150;
    return ((px / bucket).ceil() * bucket).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = src ?? '';

    //// We need this to shink memory usage
    int? memCacheWidth, memCacheHeight;
    double aspectRatio = (width / height).toDouble();

    void setMemCacheSizes() {
      if (aspectRatio > 1) {
        memCacheHeight = _getStableCacheSize(context, height);
      } else if (aspectRatio < 1) {
        memCacheWidth = _getStableCacheSize(context, width);
      } else {
        if (origAspectRatio != null && origAspectRatio! > 1) {
          memCacheWidth = _getStableCacheSize(context, width);
        } else if (origAspectRatio != null && origAspectRatio! < 1) {
          memCacheHeight = _getStableCacheSize(context, height);
        } else {
          memCacheWidth = _getStableCacheSize(context, width);
          memCacheHeight = _getStableCacheSize(context, height);
        }
      }
    }

    setMemCacheSizes();

    if (memCacheWidth == null && memCacheHeight == null) {
      memCacheWidth = width.toInt();
    }

    return src != '' && src != null
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              type == 'avatar'
                  ? 50
                  : type == 'emote'
                      ? 0
                      : StyleString.imgRadius.x,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,
              fit: BoxFit.cover,
              fadeOutDuration:
                  fadeOutDuration ?? const Duration(milliseconds: 120),
              fadeInDuration:
                  fadeInDuration ?? const Duration(milliseconds: 120),
              filterQuality: FilterQuality.high,
              errorListener: (e) {
                KazumiLogger().log(Level.warning, "网络图片加载错误 ${e.toString()}");
              },
              errorWidget: (BuildContext context, String url, Object error) =>
                  placeholder(context),
              placeholder: (BuildContext context, String url) =>
                  placeholder(context),
            ))
        : placeholder(context);
  }

  Widget placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(type == 'avatar'
            ? 50
            : type == 'emote'
                ? 0
                : StyleString.imgRadius.x),
      ),
      child: type == 'bg'
          ? const SizedBox()
          : Center(
              child: Image.asset(
                type == 'avatar'
                    ? 'assets/images/noface.jpeg'
                    : 'assets/images/loading.png',
                width: width,
                height: height,
                cacheWidth: _getStableCacheSize(context, width),
                cacheHeight: _getStableCacheSize(context, height),
              ),
            ),
    );
  }
}
