import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/theme/device_state.dart';
import 'package:truthworld/theme/tw_breakpoints.dart';
import 'package:truthworld/theme/tw_layout_tokens.dart';

void main() {
  group('DeviceState Classification', () {
    test('Should classify as mobile when width < 600', () {
      final state = DeviceState.fromSize(599, 800, 1);
      expect(state.isMobile, isTrue);
      expect(state.type, DeviceType.mobile);
    });

    test('Should classify as tablet when 600 <= width < 1024', () {
      final state = DeviceState.fromSize(600, 800, 1);
      expect(state.isTablet, isTrue);
      expect(state.type, DeviceType.tablet);

      final state2 = DeviceState.fromSize(1023, 800, 1);
      expect(state2.isTablet, isTrue);
    });

    test('Should classify as desktop when 1024 <= width < 1440', () {
      final state = DeviceState.fromSize(1024, 800, 1);
      expect(state.isDesktop, isTrue);
    });

    test('Should classify as largeDesktop when 1440 <= width < 1920', () {
      final state = DeviceState.fromSize(1440, 800, 1);
      expect(state.isLargeDesktop, isTrue);
    });

    test('Should classify as ultraWide when width >= 1920', () {
      final state = DeviceState.fromSize(1920, 1080, 1);
      expect(state.isUltraWide, isTrue);
    });
  });

  group('TWLayoutTokens Derivation', () {
    test('Should provide mobile tokens with zero sidebar width', () {
      final device = DeviceState.fromSize(400, 800, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 0);
      expect(tokens.contentMaxWidth, double.infinity);
    });

    test('Should provide desktop tokens with 280 sidebar width', () {
      final device = DeviceState.fromSize(1200, 800, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 280);
      expect(tokens.contentMaxWidth, 1280);
    });

    test('Should scale layout tokens for ultraWide', () {
      final device = DeviceState.fromSize(2000, 1080, 1);
      final tokens = TWLayoutTokens.fromDevice(device);
      expect(tokens.sidebarWidth, 360);
      expect(tokens.contentMaxWidth, 1920);
    });
  });
}
