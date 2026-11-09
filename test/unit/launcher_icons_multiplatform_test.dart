import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-Platform Launcher Icon Verification (Five Platforms)', () {
    test('Master SVG exists and contains WALL-E vector paths', () {
      final svgFile = File('assets/images/logo/logo.svg');
      expect(svgFile.existsSync(), isTrue, reason: 'assets/images/logo/logo.svg must exist');
      final content = svgFile.readAsStringSync();
      expect(content, contains('viewBox="315 180 395 452"'));
      expect(content, contains('<svg'));
    });

    test('Android: colors.xml background is black #000000 and adaptive xml is valid', () {
      final colorsFile = File('android/app/src/main/res/values/colors.xml');
      expect(colorsFile.existsSync(), isTrue);
      final colorsContent = colorsFile.readAsStringSync();
      expect(colorsContent, contains('<color name="ic_launcher_background">#000000</color>'));

      final v26File = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(v26File.existsSync(), isTrue);
      final v26Content = v26File.readAsStringSync();
      expect(v26Content, contains('@color/ic_launcher_background'));
      expect(v26Content, contains('@drawable/ic_launcher_foreground'));

      // Check all 5 legacy mipmap tiers
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final f = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(f.existsSync(), isTrue, reason: 'mipmap-$density/ic_launcher.png must exist');
        expect(f.lengthSync(), greaterThan(500));
      }

      // Check all 5 adaptive foreground tiers
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final f = File('android/app/src/main/res/drawable-$density/ic_launcher_foreground.png');
        expect(f.existsSync(), isTrue, reason: 'drawable-$density/ic_launcher_foreground.png must exist');
        expect(f.lengthSync(), greaterThan(500));
      }
    });

    test('iOS: AppIcon.appiconset exists with 1024x1024 master and Contents.json', () {
      final master = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
      expect(master.existsSync(), isTrue);
      expect(master.lengthSync(), greaterThan(10000));

      final contents = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
      expect(contents.existsSync(), isTrue);
    });

    test('macOS: AppIcon.appiconset and AppIcon.icns exist with high-res assets', () {
      final master = File('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png');
      expect(master.existsSync(), isTrue);
      expect(master.lengthSync(), greaterThan(10000));

      final icns = File('macos/Runner/AppIcon.icns');
      expect(icns.existsSync(), isTrue, reason: 'macos/Runner/AppIcon.icns must exist');
      expect(icns.lengthSync(), greaterThan(10000));
    });

    test('Windows: app_icon.ico and assets logo_windows.ico exist', () {
      final winIco = File('windows/runner/resources/app_icon.ico');
      expect(winIco.existsSync(), isTrue);
      expect(winIco.lengthSync(), greaterThan(5000));

      final assetIco = File('assets/images/logo/logo_windows.ico');
      expect(assetIco.existsSync(), isTrue);
      expect(assetIco.lengthSync(), greaterThan(5000));
    });

    test('Linux: logo_linux.png exists with high resolution', () {
      final linuxPng = File('assets/images/logo/logo_linux.png');
      expect(linuxPng.existsSync(), isTrue);
      expect(linuxPng.lengthSync(), greaterThan(10000));
    });

    test('pubspec.yaml specifies black adaptive background and splash color', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('adaptive_icon_background: "#000000"'));
      expect(pubspec, contains('color_ios: "#000000"'));
      expect(pubspec, contains('color_dark_ios: "#000000"'));
    });
  });
}
