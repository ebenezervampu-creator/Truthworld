import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/auth_sheet_controller.dart';
import 'package:truthworld/components/ui/auth/phone_verification_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put(AuthService());
  });

  tearDown(Get.reset);

  group('CountryDialCodes Dataset & Logic Tests', () {
    test('1. Provides extensive list of world countries (>240 entries)', () {
      expect(CountryDialCodes.all.length, greaterThan(240));
      expect(AuthSheetController.supportedCountries.length, equals(CountryDialCodes.all.length));
      expect(AuthSheetController.allCountries.length, equals(CountryDialCodes.all.length));
    });

    test('2. Every country has valid ISO code, dial code, and name', () {
      for (final country in CountryDialCodes.all) {
        expect(country.name.trim(), isNotEmpty, reason: 'Country name should not be empty');
        expect(country.isoCode.length, equals(2), reason: 'ISO code should be 2 characters: ${country.name}');
        expect(country.isoCode, equals(country.isoCode.toUpperCase()), reason: 'ISO code should be uppercase');
        expect(country.dialCode.startsWith('+'), isTrue, reason: 'Dial code should start with +: ${country.name}');
        expect(int.tryParse(country.dialCode.substring(1)), isNotNull, reason: 'Dial code digits should be numeric: ${country.name}');
        expect(country.flagEmoji, isNotEmpty);
      }
    });

    test('3. Key global countries are present with accurate calling codes', () {
      final map = {for (final c in CountryDialCodes.all) c.isoCode: c};

      expect(map['US']?.dialCode, equals('+1'));
      expect(map['CA']?.dialCode, equals('+1'));
      expect(map['IN']?.dialCode, equals('+91'));
      expect(map['GB']?.dialCode, equals('+44'));
      expect(map['AU']?.dialCode, equals('+61'));
      expect(map['DE']?.dialCode, equals('+49'));
      expect(map['FR']?.dialCode, equals('+33'));
      expect(map['JP']?.dialCode, equals('+81'));
      expect(map['AE']?.dialCode, equals('+971'));
      expect(map['SG']?.dialCode, equals('+65'));
      expect(map['BR']?.dialCode, equals('+55'));
      expect(map['NG']?.dialCode, equals('+234'));
      expect(map['ZA']?.dialCode, equals('+27'));
      expect(map['SA']?.dialCode, equals('+966'));
      expect(map['PK']?.dialCode, equals('+92'));
      expect(map['BD']?.dialCode, equals('+880'));
      expect(map['PH']?.dialCode, equals('+63'));
      expect(map['EG']?.dialCode, equals('+20'));
      expect(map['KE']?.dialCode, equals('+254'));
      expect(map['MX']?.dialCode, equals('+52'));
      expect(map['ID']?.dialCode, equals('+62'));
      expect(map['KR']?.dialCode, equals('+82'));
    });

    test('4. Flag emoji computes correctly from 2-letter ISO code', () {
      const us = CountryDialCode(name: 'United States', dialCode: '+1', isoCode: 'US');
      expect(us.flagEmoji, equals('🇺🇸'));

      const india = CountryDialCode(name: 'India', dialCode: '+91', isoCode: 'IN');
      expect(india.flagEmoji, equals('🇮🇳'));

      const gb = CountryDialCode(name: 'United Kingdom', dialCode: '+44', isoCode: 'GB');
      expect(gb.flagEmoji, equals('🇬🇧'));
    });
  });

  group('AuthSheetController Country Search & Selection Tests', () {
    test('1. Initial country defaults to United States', () {
      final controller = AuthSheetController();
      expect(controller.selectedCountry.value.dialCode, equals('+1'));
      expect(controller.selectedCountry.value.isoCode, equals('US'));
    });

    test('2. Searching filters countries by name, dial code, and ISO code', () {
      final controller = AuthSheetController();

      // Search by name
      controller.updateCountrySearch('Brazil');
      expect(controller.filteredCountries.any((c) => c.isoCode == 'BR'), isTrue);
      expect(controller.filteredCountries.length, lessThan(5));

      // Search by dial code with plus
      controller.updateCountrySearch('+91');
      expect(controller.filteredCountries.any((c) => c.isoCode == 'IN'), isTrue);

      // Search by dial code digits without plus
      controller.updateCountrySearch('234');
      expect(controller.filteredCountries.any((c) => c.isoCode == 'NG'), isTrue);

      // Search by ISO code
      controller.updateCountrySearch('ae');
      expect(controller.filteredCountries.any((c) => c.isoCode == 'AE'), isTrue);

      // Clear search
      controller.clearCountrySearch();
      expect(controller.filteredCountries.length, equals(CountryDialCodes.all.length));
    });

    test('3. Selecting a country updates selectedCountry and resets search query', () {
      final controller = AuthSheetController();
      controller.updateCountrySearch('Japan');
      final japan = controller.filteredCountries.firstWhere((c) => c.isoCode == 'JP');

      controller.selectCountry(japan);
      expect(controller.selectedCountry.value.isoCode, equals('JP'));
      expect(controller.selectedCountry.value.dialCode, equals('+81'));
      expect(controller.countrySearchQuery.value, isEmpty);
    });
  });

  group('Phone Verification Country Picker Widget Tests', () {
    testWidgets('Opens country picker, searches country, and selects it', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: PhoneVerificationSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify default dial code and flag are visible
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('🇺🇸'), findsOneWidget);

      // Tap country code trigger button to open picker
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();

      // Verify modal sheet is shown
      expect(find.text('Select Country'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Find search field in modal and type "India"
      final searchFields = find.widgetWithText(TextField, 'Search country or dial code...');
      expect(searchFields, findsOneWidget);

      await tester.enterText(searchFields, 'India');
      await tester.pumpAndSettle();

      // Tap on India ListTile
      final indiaTile = find.widgetWithText(ListTile, 'India');
      expect(indiaTile, findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      await tester.tap(indiaTile);
      await tester.pumpAndSettle();

      // Verify country is now updated to India in phone input view
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('🇮🇳'), findsOneWidget);
    });
  });
}
