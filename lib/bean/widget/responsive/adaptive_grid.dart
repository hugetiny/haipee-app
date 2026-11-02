import 'package:flutter/material.dart';
import 'package:haipee/bean/widget/responsive/breakpoints.dart';

/// 统一响应式自适应网格组件
/// 自动根据可用容器宽度计算最适宜的列数与卡片高度，消除手动计算与视口像素溢出
class AdaptiveGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int? smallMobileColumns;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double? minItemWidth;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final double Function(double columnWidth)? extentBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final ScrollController? controller;

  const AdaptiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.smallMobileColumns,
    this.mobileColumns = 3,
    this.tabletColumns = 5,
    this.desktopColumns = 6,
    this.minItemWidth,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.childAspectRatio,
    this.mainAxisExtent,
    this.extentBuilder,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.shrinkWrap = false,
    this.controller,
  });

  /// 依据宽度计算最适宜列数
  static int calculateColumns(
    double width, {
    int? smallMobile,
    int mobile = 3,
    int tablet = 5,
    int desktop = 6,
    double? minItemWidth,
  }) {
    if (minItemWidth != null && minItemWidth > 0) {
      final calculated = (width / minItemWidth).floor();
      return calculated.clamp(1, 24);
    }
    if (width < AppBreakpoints.smallMobileMax) {
      return smallMobile ?? (mobile > 2 ? 2 : mobile);
    }
    if (width < AppBreakpoints.mobileMax) {
      return mobile;
    }
    if (width <= AppBreakpoints.tabletMax) {
      return tablet;
    }
    if (width <= AppBreakpoints.wideMaxContentWidth) {
      return desktop;
    }
    // 宽屏与超宽屏动态扩展列数，避免大屏卡片过度拉伸与空白留黑
    final double baseWidth = AppBreakpoints.wideMaxContentWidth / desktop;
    final int dynamicColumns = (width / baseWidth).floor();
    return dynamicColumns.clamp(desktop, 24);
  }

  /// 依据可用宽度与配置创建 SliverGridDelegate
  static SliverGridDelegateWithFixedCrossAxisCount createDelegate({
    required double availableWidth,
    int? smallMobileColumns,
    int mobileColumns = 3,
    int tabletColumns = 5,
    int desktopColumns = 6,
    double? minItemWidth,
    double mainAxisSpacing = 8.0,
    double crossAxisSpacing = 8.0,
    double? childAspectRatio,
    double? mainAxisExtent,
    double Function(double columnWidth)? extentBuilder,
  }) {
    final int crossCount = calculateColumns(
      availableWidth,
      smallMobile: smallMobileColumns,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
      minItemWidth: minItemWidth,
    );

    final double effectiveColumnWidth =
        (availableWidth - (crossCount - 1) * crossAxisSpacing) / crossCount;

    double? effectiveExtent = mainAxisExtent;
    if (effectiveExtent == null && extentBuilder != null) {
      effectiveExtent = extentBuilder(effectiveColumnWidth);
    }

    if (effectiveExtent != null) {
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisExtent: effectiveExtent,
      );
    }

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio ?? 0.7,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final double horizontalPadding = padding
            .resolve(Directionality.maybeOf(context) ?? TextDirection.ltr)
            .horizontal;
        final double innerWidth =
            (width - horizontalPadding).clamp(0.0, double.infinity);

        final delegate = createDelegate(
          availableWidth: innerWidth > 0 ? innerWidth : width,
          smallMobileColumns: smallMobileColumns,
          mobileColumns: mobileColumns,
          tabletColumns: tabletColumns,
          desktopColumns: desktopColumns,
          minItemWidth: minItemWidth,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
          mainAxisExtent: mainAxisExtent,
          extentBuilder: extentBuilder,
        );

        return GridView.builder(
          controller: controller,
          padding: padding,
          physics: physics,
          shrinkWrap: shrinkWrap,
          gridDelegate: delegate,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
