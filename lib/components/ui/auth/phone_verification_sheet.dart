import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/auth/country_dial_codes.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Controller managing phone number verification and account linking.
class PhoneVerificationController extends BaseController {
  final RxInt currentStep = 0.obs; // 0 = phoneInput, 1 = otpInput
  final RxBool isBusy = false.obs;

  late final TextEditingController phoneController =
      trackTextController(TextEditingController());
  late final TextEditingController otpController =
      trackTextController(TextEditingController());
  late final TextEditingController countrySearchController =
      trackTextController(TextEditingController());

  final Rx<CountryDialCode> selectedCountry =
      CountryDialCodes.defaultCountry.obs;
  final RxString countrySearchQuery = ''.obs;
  final RxString verificationId = ''.obs;
  final RxnInt resendToken = RxnInt();
  final RxString targetPhoneNumber = ''.obs;

  final RxInt resendCountdown = 60.obs;
  final RxBool canResend = false.obs;
  Timer? _countdownTimer;

  static const List<CountryDialCode> allCountries = CountryDialCodes.all;

  List<CountryDialCode> get filteredCountries {
    final query = countrySearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return allCountries;
    final cleanDial = query.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    return allCountries.where((c) {
      final nameLower = c.name.toLowerCase();
      final isoLower = c.isoCode.toLowerCase();
      final dialDigits = c.dialCode.replaceAll('+', '');
      return nameLower.contains(query) ||
          isoLower.contains(query) ||
          (cleanDial.isNotEmpty && dialDigits.contains(cleanDial));
    }).toList();
  }

  void updateCountrySearch(String query) {
    countrySearchQuery.value = query;
  }

  void clearCountrySearch() {
    countrySearchController.clear();
    countrySearchQuery.value = '';
  }

  void goToPhoneInput() {
    currentStep.value = 0;
    otpController.clear();
  }

  void selectCountry(CountryDialCode country) {
    selectedCountry.value = country;
    clearCountrySearch();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    resendCountdown.value = 60;
    canResend.value = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown.value > 1) {
        resendCountdown.value--;
      } else {
        canResend.value = true;
        timer.cancel();
      }
    });
  }

  Future<void> sendVerificationCode() async {
    final rawPhone = phoneController.text.trim();
    if (rawPhone.isEmpty) {
      AppSnackbar.info('Please enter your phone number.');
      return;
    }

    final fullNumber = AuthPhoneSignInProvider.normalizePhoneNumber(
      rawPhone,
      countryCode: selectedCountry.value.dialCode,
    );

    if (fullNumber.length < 8) {
      AppSnackbar.info('Please enter a valid phone number.');
      return;
    }

    try {
      isBusy.value = true;
      targetPhoneNumber.value = fullNumber;

      await AuthService.to.verifyPhoneNumber(
        phoneNumber: fullNumber,
        resendToken: resendToken.value,
        onCodeSent: (id, token) {
          verificationId.value = id;
          resendToken.value = token;
          isBusy.value = false;
          currentStep.value = 1;
          _startCountdown();
          AppSnackbar.success('Verification code sent to $fullNumber');
        },
        onVerificationCompleted: (credential) async {
          isBusy.value = false;
          final sms = credential.smsCode;
          if (sms != null && sms.isNotEmpty) {
            otpController.text = sms;
            await verifyAndLinkPhone();
          }
        },
        onVerificationFailed: (error) {
          isBusy.value = false;
          AppSnackbar.error(error.displayMessage);
        },
        onCodeAutoRetrievalTimeout: (id) {
          verificationId.value = id;
        },
      );
    } catch (e, st) {
      isBusy.value = false;
      ErrorHandler.log(e, stackTrace: st, tag: 'PhoneVerification.sendCode');
      AppSnackbar.error(
        'Unable to send verification code. Please check the number and try again.',
      );
    }
  }

  Future<void> resendVerificationCode() async {
    if (!canResend.value || isBusy.value) return;
    await sendVerificationCode();
  }

  Future<void> verifyAndLinkPhone() async {
    final code = otpController.text.trim();
    if (code.length < 6) {
      AppSnackbar.info('Please enter the 6-digit verification code.');
      return;
    }

    try {
      isBusy.value = true;
      await AuthService.to.linkPhoneNumber(
        verificationId: verificationId.value,
        smsCode: code,
        phoneNumber: targetPhoneNumber.value,
      );

      isBusy.value = false;
      _countdownTimer?.cancel();
      if (Get.isBottomSheetOpen == true) {
        Get.back();
      }
      AppSnackbar.success('Phone number verified successfully!');
    } on PhoneAuthException catch (e) {
      isBusy.value = false;
      AppSnackbar.error(e.displayMessage);
    } catch (e, st) {
      isBusy.value = false;
      ErrorHandler.log(e, stackTrace: st, tag: 'PhoneVerification.verify');
      AppSnackbar.error(
        'Unable to verify phone number. Please check the code and try again.',
      );
    }
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }
}

/// Bottom sheet dialog for verifying and linking a phone number.
class PhoneVerificationSheet extends StatelessWidget {
  const PhoneVerificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PhoneVerificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PhoneVerificationController());
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: bottomInset > 0 ? bottomInset + 20 : 36,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Obx(() {
              if (controller.currentStep.value == 0) {
                return _buildPhoneInputStep(context, controller);
              } else {
                return _buildOtpStep(context, controller);
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputStep(
    BuildContext context,
    PhoneVerificationController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verify Phone Number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: Get.back,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your mobile number to receive a 6-digit verification code.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Phone input row with Country code selector
        Row(
          children: [
            Obx(() {
              final country = controller.selectedCountry.value;
              return InkWell(
                onTap: controller.isBusy.value
                    ? null
                    : () => _showCountryPicker(context, controller),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        country.dialCode,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Send Code Button (White background, Black foreground)
        Obx(() {
          final isBusy = controller.isBusy.value;
          return ElevatedButton(
            onPressed: isBusy ? null : controller.sendVerificationCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Send Verification Code',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildOtpStep(
    BuildContext context,
    PhoneVerificationController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed:
                  controller.isBusy.value ? null : controller.goToPhoneInput,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: Get.back,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Obx(() => Text(
              'Code sent to ${controller.targetPhoneNumber.value}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )),
        const SizedBox(height: 20),

        // 6-digit OTP Input
        TextField(
          controller: controller.otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: TextStyle(
              color: AppColors.textDisabled,
              fontSize: 24,
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: AppColors.bgInput,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.bgDivider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend countdown
        Obx(() {
          if (controller.canResend.value) {
            return Center(
              child: TextButton(
                onPressed: controller.isBusy.value
                    ? null
                    : controller.resendVerificationCode,
                child: Text(
                  'Resend SMS Code',
                  style: TextStyle(
                    color: AppColors.textLink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          } else {
            return Center(
              child: Text(
                'Resend code in ${controller.resendCountdown.value}s',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            );
          }
        }),
        const SizedBox(height: 20),

        // Verify Button (White background, Black foreground)
        Obx(() {
          final isBusy = controller.isBusy.value;
          return ElevatedButton(
            onPressed: isBusy ? null : controller.verifyAndLinkPhone,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    'Verify & Link Phone',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          );
        }),
      ],
    );
  }

  void _showCountryPicker(
    BuildContext context,
    PhoneVerificationController controller,
  ) {
    controller.clearCountrySearch();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pickerCtx) {
        return Material(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: MediaQuery.of(pickerCtx).size.height * 0.75,
            child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Select Country',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(pickerCtx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller.countrySearchController,
                  maxLength: defaultMaxSearchLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
                  onChanged: controller.updateCountrySearch,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search country or dial code...',
                    hintStyle: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  final list = controller.filteredCountries;
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: AppColors.bgDivider, height: 1),
                    itemBuilder: (_, index) {
                      final item = list[index];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Text(
                            item.flagEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Text(
                            item.dialCode,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            controller.selectCountry(item);
                            Navigator.pop(pickerCtx);
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}
