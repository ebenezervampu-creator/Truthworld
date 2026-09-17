import 'dart:async';

import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/channel/data/models/channel_availability_status.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';

mixin ChannelAvailabilityMixin on ChannelControllerBase {
  Timer? _channelNameDebounceTimer;
  Timer? _customUrlDebounceTimer;

  void _updateHandleSuggestions(String baseSlug) {
    if (baseSlug.trim().isEmpty) {
      handleSuggestions.clear();
      return;
    }
    final base = baseSlug.length > 25 ? baseSlug.substring(0, 25) : baseSlug;
    handleSuggestions.value = [
      base,
      '${base}123',
      '${base}_vsp',
      '${base}777',
    ];
  }

  @override
  void setupTextFieldListeners() {
    channelName.addListener(() {
      checkChannelNameAvailability(channelName.text);
      // Auto-fill custom URL if it's empty or was previously auto-filled
      final slug = channelName.text
          .toLowerCase()
          .trim()
          .replaceAll(RegExp('[^a-z0-9_-]'), '-')
          .replaceAll(RegExp('-+'), '-')
          .replaceAll(RegExp('_+'), '_');
      var cleanSlug = slug;
      if (cleanSlug.startsWith('-') || cleanSlug.startsWith('_')) {
        cleanSlug = cleanSlug.substring(1);
      }
      if (cleanSlug.endsWith('-') || cleanSlug.endsWith('_')) {
        cleanSlug = cleanSlug.substring(0, cleanSlug.length - 1);
      }
      if (customUrl.text.isEmpty || customUrl.text == lastAutoSlug) {
        customUrl.text = cleanSlug;
        lastAutoSlug = cleanSlug;
        if (cleanSlug.isNotEmpty) {
          checkCustomUrlAvailability(cleanSlug);
        }
      }
      _updateHandleSuggestions(cleanSlug);
      formChangeTrigger.value++;
    });
    customUrl.addListener(() {
      if (customUrl.text.isNotEmpty) {
        checkCustomUrlAvailability(customUrl.text);
      } else {
        customUrlAvailability.value = AvailabilityStatus.unknown;
      }
    });
    description.addListener(() {
      formChangeTrigger.value++;
    });
  }

  @override
  void setupFormValidationListeners() {
    // Already handled in _setupTextFieldListeners
  }

  void checkChannelNameAvailability(String channelName) {
    _channelNameDebounceTimer?.cancel();

    if (channelName.trim().isEmpty) {
      channelNameAvailability.value = AvailabilityStatus.unknown;
      return;
    }

    if (channelName.length < ChannelControllerBase.minChannelNameLength ||
        channelName.length > ChannelControllerBase.maxChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      return;
    }

    channelNameAvailability.value = AvailabilityStatus.checking;

    _channelNameDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _performChannelNameAvailabilityCheck(channelName),
    );
  }

  Future<void> _performChannelNameAvailabilityCheck(String channelName) async {
    try {
      final snapshot = await firestore
          .collection(ChannelControllerBase.channelsCol)
          .where('nameLowercase', isEqualTo: channelName.trim().toLowerCase())
          .limit(1)
          .get();

      channelNameAvailability.value = snapshot.docs.isEmpty
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.checkNameAvailability',
      );
      channelNameAvailability.value = AvailabilityStatus.error;
    }
  }

  void checkCustomUrlAvailability(String customUrl) {
    _customUrlDebounceTimer?.cancel();

    if (customUrl.trim().isEmpty) {
      customUrlAvailability.value = AvailabilityStatus.unknown;
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(customUrl) ||
        customUrl.length < ChannelControllerBase.minCustomUrlLength ||
        customUrl.length > ChannelControllerBase.maxCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      return;
    }

    customUrlAvailability.value = AvailabilityStatus.checking;

    _customUrlDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _performCustomUrlAvailabilityCheck(customUrl),
    );
  }

  Future<void> _performCustomUrlAvailabilityCheck(String customUrl) async {
    try {
      final snapshot = await firestore
          .collection(ChannelControllerBase.channelsCol)
          .where('handleLowercase', isEqualTo: customUrl.trim().toLowerCase())
          .limit(1)
          .get();

      customUrlAvailability.value = snapshot.docs.isEmpty
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.checkCustomUrlAvailability',
      );
      customUrlAvailability.value = AvailabilityStatus.error;
    }
  }

  void resetAvailabilityStatus() {
    channelNameAvailability.value = AvailabilityStatus.unknown;
    customUrlAvailability.value = AvailabilityStatus.unknown;
  }


  void _setupTextFieldListeners() => setupTextFieldListeners();
  void _setupFormValidationListeners() => setupFormValidationListeners();
}
