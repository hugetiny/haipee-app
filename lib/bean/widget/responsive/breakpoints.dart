import 'package:flutter/material.dart';

/// 全局统一屏幕设备与视口类型
enum ScreenType {
  /// 紧凑型移动设备与极窄视口 (< 600dp)
  mobile,

  /// 中等平板与紧凑桌面窗口 (600dp ~ 1024dp)
  tablet,

  /// 大屏桌面与展开视口 (> 1024dp)
  desktop;

  bool get isMobile => this == ScreenType.mobile;
  bool get isTablet => this == ScreenType.tablet;
  bool get isDesktop => this == ScreenType.desktop;
}

/// 官方规范的 3 层响应式断点定义
/// - mobile: < 600dp
/// - tablet: 600dp ~ 1024dp
/// - desktop: > 1024dp
class AppBreakpoints {
  const AppBreakpoints._();

  /// 移动端最大宽度（对齐 Material 3 Compact 断点）
  static const double mobileMax = 600.0;

  /// 平板端最大宽度（对齐桌面展开断点）
  static const double tabletMax = 1024.0;

  /// 桌面端最小宽度
  static const double desktopMin = 1024.0;

  /// 超窄移动设备阈值（针对 360dp 或更小的屏幕做极端紧凑优化）
  static const double smallMobileMax = 380.0;

  /// 标准内容最大宽度约束（针对超宽桌面端，防止表单或列表无限横向拉伸）
  static const double defaultMaxContentWidth = 1000.0;

  /// 宽屏媒体与表格内容最大宽度约束
  static const double wideMaxContentWidth = 1280.0;

  /// 根据宽度获取屏幕类型
  static ScreenType getScreenType(double width) {
    if (width < mobileMax) {
      return ScreenType.mobile;
    } else if (width <= tabletMax) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  /// 从当前 BuildContext 的 MediaQuery 获取屏幕类型
  static ScreenType of(BuildContext context) {
    return getScreenType(MediaQuery.sizeOf(context).width);
  }
}

/// BuildContext 响应式便捷扩展
extension ResponsiveContext on BuildContext {
  /// 当前窗口的屏幕类型
  ScreenType get screenType => AppBreakpoints.of(this);

  /// 是否为移动端视口 (< 600dp)
  bool get isMobile => screenType == ScreenType.mobile;

  /// 是否为超窄移动端 (< 380dp)
  bool get isSmallMobile => MediaQuery.sizeOf(this).width < AppBreakpoints.smallMobileMax;

  /// 是否为平板视口 (600dp ~ 1024dp)
  bool get isTablet => screenType == ScreenType.tablet;

  /// 是否为桌面大屏视口 (> 1024dp)
  bool get isDesktop => screenType == ScreenType.desktop;

  /// 依据当前视口尺寸返回对应的值
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (screenType) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }
}
