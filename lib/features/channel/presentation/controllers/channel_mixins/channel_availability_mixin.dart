import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/channel/data/models/channel_availability_status.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_mixins/channel_controller_base.dart';

mixin ChannelAvailabilityMixin on ChannelControllerBase {
  static const Set<String> reservedHandles = {
    'admin',
    'administrator',
    'truthworld',
    'truth',
    'support',
    'official',
    'api',
    'help',
    'root',
    'moderator',
    'moderation',
    'terms',
    'privacy',
    'channel',
    'system',
    'studio',
    'verify',
    'verified',
    'auth',
    'null',
    'undefined',
    'security',
    'billing',
  };

  Timer? _channelNameDebounceTimer;
  Timer? _customUrlDebounceTimer;
  int _channelNameRequestId = 0;
  int _customUrlRequestId = 0;
  bool _listenersAttached = false;

  final Map<String, AvailabilityStatus> _channelNameCache = {};
  final Map<String, AvailabilityStatus> _customUrlCache = {};

  @override
  void applyHandleSuggestion(String handle) {
    var clean = handle.trim();
    if (clean.startsWith('@')) clean = clean.substring(1).trim();
    customUrl.text = clean;

    // X-platform instant selection pattern: pre-seed available status and clear suggestions
    final lower = clean.toLowerCase();
    _customUrlCache[lower] = AvailabilityStatus.available;
    customUrlAvailability.value = AvailabilityStatus.available;
    customUrlAvailabilityMessage.value = 'Handle @$clean is available!';
    handleSuggestions.clear();
  }

  void _updateHandleSuggestions(String baseSlug) {
    var base = baseSlug.trim().toLowerCase();
    if (base.startsWith('@')) base = base.substring(1);
    if (base.isEmpty) {
      handleSuggestions.clear();
      return;
    }
    final normalized = base.length > 20 ? base.substring(0, 20) : base;
    final candidates = <String>[
      '${normalized}_official',
      '${normalized}_channel',
      '${normalized}_hub',
      '${normalized}101',
      '${normalized}77',
      'real_$normalized',
    ];
    final validSuggestions = candidates
        .where((s) => s.length <= ChannelControllerBase.maxCustomUrlLength)
        .where((s) => _customUrlCache[s] != AvailabilityStatus.taken)
        .take(4)
        .toList();

    handleSuggestions.value = validSuggestions;
  }

  @override
  void setupTextFieldListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    channelName.addListener(() {
      final nameText = channelName.text;
      checkChannelNameAvailability(nameText);

      // Auto-fill custom URL if it's empty or was previously auto-filled
      final slug = nameText
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
        } else {
          customUrlAvailability.value = AvailabilityStatus.unknown;
          customUrlAvailabilityMessage.value = '';
          handleSuggestions.clear();
        }
      }
      formChangeTrigger.value++;
    });

    customUrl.addListener(() {
      final text = customUrl.text;
      if (text.isNotEmpty) {
        checkCustomUrlAvailability(text);
      } else {
        customUrlAvailability.value = AvailabilityStatus.unknown;
        customUrlAvailabilityMessage.value = '';
        handleSuggestions.clear();
      }
    });

    description.addListener(() {
      formChangeTrigger.value++;
    });
  }

  @override
  void setupFormValidationListeners() {
    // Already handled in setupTextFieldListeners
  }

  @override
  void checkChannelNameAvailability(String rawName, {bool forceRefresh = false}) {
    _channelNameDebounceTimer?.cancel();
    final name = rawName.trim();

    if (name.isEmpty) {
      channelNameAvailability.value = AvailabilityStatus.unknown;
      channelNameAvailabilityMessage.value = '';
      return;
    }

    // Instant local validation (0ms, $0 cost)
    if (name.length < ChannelControllerBase.minChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Channel name must be at least ${ChannelControllerBase.minChannelNameLength} characters.';
      return;
    }

    if (name.length > ChannelControllerBase.maxChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Channel name cannot exceed ${ChannelControllerBase.maxChannelNameLength} characters.';
      return;
    }

    if (profanityFilter.hasProfanity(name)) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Please choose an appropriate channel name.';
      return;
    }

    // In-memory cache check (0ms, $0 cost)
    final lowerName = name.toLowerCase();
    if (!forceRefresh && _channelNameCache.containsKey(lowerName)) {
      final cached = _channelNameCache[lowerName]!;
      channelNameAvailability.value = cached;
      channelNameAvailabilityMessage.value = cached == AvailabilityStatus.available
          ? 'Channel name is available!'
          : 'This channel name is already taken.';
      return;
    }

    // Set checking state
    channelNameAvailability.value = AvailabilityStatus.checking;
    channelNameAvailabilityMessage.value = 'Checking availability...';

    // Industry standard debounce
    final requestId = ++_channelNameRequestId;
    _channelNameDebounceTimer = Timer(
      const Duration(milliseconds: ChannelControllerBase.debounceDurationMs),
      () => _performChannelNameAvailabilityCheck(name, requestId),
    );
  }

  @override
  Future<AvailabilityStatus> verifyChannelNameAvailabilityDirect(
      String rawName) async {
    _channelNameDebounceTimer?.cancel();
    final name = rawName.trim();

    if (name.isEmpty) {
      channelNameAvailability.value = AvailabilityStatus.unknown;
      channelNameAvailabilityMessage.value = '';
      return AvailabilityStatus.unknown;
    }

    // Instant local validation (0ms, $0 cost)
    if (name.length < ChannelControllerBase.minChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Channel name must be at least ${ChannelControllerBase.minChannelNameLength} characters.';
      return AvailabilityStatus.invalid;
    }

    if (name.length > ChannelControllerBase.maxChannelNameLength) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Channel name cannot exceed ${ChannelControllerBase.maxChannelNameLength} characters.';
      return AvailabilityStatus.invalid;
    }

    if (profanityFilter.hasProfanity(name)) {
      channelNameAvailability.value = AvailabilityStatus.invalid;
      channelNameAvailabilityMessage.value =
          'Please choose an appropriate channel name.';
      return AvailabilityStatus.invalid;
    }

    final lowerName = name.toLowerCase();

    // In-memory cache check (0ms, $0 cost)
    if (_channelNameCache.containsKey(lowerName)) {
      final cached = _channelNameCache[lowerName]!;
      channelNameAvailability.value = cached;
      channelNameAvailabilityMessage.value = cached == AvailabilityStatus.available
          ? 'Channel name is available!'
          : 'This channel name is already taken.';
      return cached;
    }

    channelNameAvailability.value = AvailabilityStatus.checking;
    channelNameAvailabilityMessage.value = 'Checking availability...';
    final requestId = ++_channelNameRequestId;

    try {
      final status = await _executeResilientNameCheck(name);
      if (requestId != _channelNameRequestId) return status;

      _channelNameCache[lowerName] = status;
      channelNameAvailability.value = status;
      channelNameAvailabilityMessage.value = status == AvailabilityStatus.taken
          ? 'This channel name is already taken.'
          : 'Channel name is available!';
      return status;
    } catch (e, stackTrace) {
      if (requestId != _channelNameRequestId) return AvailabilityStatus.error;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.verifyChannelNameAvailabilityDirect',
      );
      channelNameAvailability.value = AvailabilityStatus.error;
      channelNameAvailabilityMessage.value = _getFriendlyErrorMessage(e, 'channel name');
      return AvailabilityStatus.error;
    }
  }

  Future<void> _performChannelNameAvailabilityCheck(
      String name, int requestId) async {
    final lowerName = name.trim().toLowerCase();
    try {
      final status = await _executeResilientNameCheck(name);

      // Discard stale responses
      if (requestId != _channelNameRequestId) return;

      _channelNameCache[lowerName] = status;
      channelNameAvailability.value = status;
      channelNameAvailabilityMessage.value = status == AvailabilityStatus.taken
          ? 'This channel name is already taken.'
          : 'Channel name is available!';
    } catch (e, stackTrace) {
      if (requestId != _channelNameRequestId) return;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.checkNameAvailability',
      );
      channelNameAvailability.value = AvailabilityStatus.error;
      channelNameAvailabilityMessage.value = _getFriendlyErrorMessage(e, 'channel name');
    }
  }

  Future<AvailabilityStatus> _executeResilientNameCheck(String name) async {
    final lowerName = name.trim().toLowerCase();
    const maxAttempts = 3;
    Exception? lastException;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final snapshot = await firestore
            .collection(ChannelControllerBase.channelsCol)
            .where('nameLowercase', isEqualTo: lowerName)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        var isTaken = false;
        if (snapshot.docs.isNotEmpty) {
          final docData = snapshot.docs.first.data();
          final status = (docData['status'] as String? ?? 'active').toLowerCase();
          if (status != 'deleted') {
            isTaken = true;
          }
        }
        return isTaken ? AvailabilityStatus.taken : AvailabilityStatus.available;
      } catch (e, stackTrace) {
        lastException = e is Exception ? e : Exception(e.toString());
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelAvailabilityMixin._executeResilientNameCheck.attempt_$attempt',
        );
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    }
    throw lastException ?? Exception('Failed to check channel name after retries');
  }

  @override
  void checkCustomUrlAvailability(String rawCustomUrl, {bool forceRefresh = false}) {
    _customUrlDebounceTimer?.cancel();
    var cleanHandle = rawCustomUrl.trim();
    if (cleanHandle.startsWith('@')) {
      cleanHandle = cleanHandle.substring(1).trim();
    }

    if (cleanHandle.isEmpty) {
      customUrlAvailability.value = AvailabilityStatus.unknown;
      customUrlAvailabilityMessage.value = '';
      handleSuggestions.clear();
      return;
    }

    // Instant local validation (0ms, $0 cost)
    if (cleanHandle.length < ChannelControllerBase.minCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle must be at least ${ChannelControllerBase.minCustomUrlLength} characters.';
      _updateHandleSuggestions(cleanHandle);
      return;
    }

    if (cleanHandle.length > ChannelControllerBase.maxCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle cannot exceed ${ChannelControllerBase.maxCustomUrlLength} characters.';
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cleanHandle)) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle can only contain letters, numbers, underscores, and hyphens.';
      return;
    }

    final lowerHandle = cleanHandle.toLowerCase();

    // Reserved handles check (Instant, 0ms, $0 cost)
    if (reservedHandles.contains(lowerHandle)) {
      customUrlAvailability.value = AvailabilityStatus.taken;
      customUrlAvailabilityMessage.value = 'Handle "@$cleanHandle" is reserved.';
      _updateHandleSuggestions(cleanHandle);
      return;
    }

    if (profanityFilter.hasProfanity(cleanHandle)) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value = 'Please choose an appropriate handle.';
      return;
    }

    // In-memory cache check (0ms, $0 cost)
    if (!forceRefresh && _customUrlCache.containsKey(lowerHandle)) {
      final cached = _customUrlCache[lowerHandle]!;
      customUrlAvailability.value = cached;
      customUrlAvailabilityMessage.value = cached == AvailabilityStatus.available
          ? 'Handle @$cleanHandle is available!'
          : 'Handle @$cleanHandle is already taken.';
      if (cached == AvailabilityStatus.taken) {
        _updateHandleSuggestions(cleanHandle);
      } else {
        handleSuggestions.clear();
      }
      return;
    }

    // Set checking state
    customUrlAvailability.value = AvailabilityStatus.checking;
    customUrlAvailabilityMessage.value = 'Checking availability...';

    // Industry standard debounce
    final requestId = ++_customUrlRequestId;
    _customUrlDebounceTimer = Timer(
      const Duration(milliseconds: ChannelControllerBase.debounceDurationMs),
      () => _performCustomUrlAvailabilityCheck(cleanHandle, requestId),
    );
  }

  @override
  Future<AvailabilityStatus> verifyCustomUrlAvailabilityDirect(
      String rawCustomUrl) async {
    _customUrlDebounceTimer?.cancel();
    var cleanHandle = rawCustomUrl.trim();
    if (cleanHandle.startsWith('@')) {
      cleanHandle = cleanHandle.substring(1).trim();
    }

    if (cleanHandle.isEmpty) {
      customUrlAvailability.value = AvailabilityStatus.unknown;
      customUrlAvailabilityMessage.value = '';
      handleSuggestions.clear();
      return AvailabilityStatus.unknown;
    }

    // Instant local validation (0ms, $0 cost)
    if (cleanHandle.length < ChannelControllerBase.minCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle must be at least ${ChannelControllerBase.minCustomUrlLength} characters.';
      _updateHandleSuggestions(cleanHandle);
      return AvailabilityStatus.invalid;
    }

    if (cleanHandle.length > ChannelControllerBase.maxCustomUrlLength) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle cannot exceed ${ChannelControllerBase.maxCustomUrlLength} characters.';
      return AvailabilityStatus.invalid;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cleanHandle)) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value =
          'Handle can only contain letters, numbers, underscores, and hyphens.';
      return AvailabilityStatus.invalid;
    }

    final lowerHandle = cleanHandle.toLowerCase();

    // Reserved handles check (Instant, 0ms, $0 cost)
    if (reservedHandles.contains(lowerHandle)) {
      customUrlAvailability.value = AvailabilityStatus.taken;
      customUrlAvailabilityMessage.value = 'Handle "@$cleanHandle" is reserved.';
      _updateHandleSuggestions(cleanHandle);
      return AvailabilityStatus.taken;
    }

    if (profanityFilter.hasProfanity(cleanHandle)) {
      customUrlAvailability.value = AvailabilityStatus.invalid;
      customUrlAvailabilityMessage.value = 'Please choose an appropriate handle.';
      return AvailabilityStatus.invalid;
    }

    // In-memory cache check
    if (_customUrlCache.containsKey(lowerHandle)) {
      final cached = _customUrlCache[lowerHandle]!;
      customUrlAvailability.value = cached;
      customUrlAvailabilityMessage.value = cached == AvailabilityStatus.available
          ? 'Handle @$cleanHandle is available!'
          : 'Handle @$cleanHandle is already taken.';
      if (cached == AvailabilityStatus.taken) {
        _updateHandleSuggestions(cleanHandle);
      } else {
        handleSuggestions.clear();
      }
      return cached;
    }

    customUrlAvailability.value = AvailabilityStatus.checking;
    customUrlAvailabilityMessage.value = 'Checking availability...';
    final requestId = ++_customUrlRequestId;

    try {
      final status = await _executeResilientHandleCheck(cleanHandle);
      if (requestId != _customUrlRequestId) return status;

      _customUrlCache[lowerHandle] = status;
      customUrlAvailability.value = status;
      final isTaken = status == AvailabilityStatus.taken;
      customUrlAvailabilityMessage.value = isTaken
          ? 'Handle @$cleanHandle is already taken.'
          : 'Handle @$cleanHandle is available!';

      if (isTaken) {
        _updateHandleSuggestions(cleanHandle);
      } else {
        handleSuggestions.clear();
      }
      return status;
    } catch (e, stackTrace) {
      if (requestId != _customUrlRequestId) return AvailabilityStatus.error;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.verifyCustomUrlAvailabilityDirect',
      );
      customUrlAvailability.value = AvailabilityStatus.error;
      customUrlAvailabilityMessage.value = _getFriendlyErrorMessage(e, 'handle');
      return AvailabilityStatus.error;
    }
  }

  Future<void> _performCustomUrlAvailabilityCheck(
      String cleanHandle, int requestId) async {
    final lowerHandle = cleanHandle.toLowerCase();
    try {
      final status = await _executeResilientHandleCheck(cleanHandle);

      // Discard stale responses
      if (requestId != _customUrlRequestId) return;

      _customUrlCache[lowerHandle] = status;
      customUrlAvailability.value = status;
      final isTaken = status == AvailabilityStatus.taken;
      customUrlAvailabilityMessage.value = isTaken
          ? 'Handle @$cleanHandle is already taken.'
          : 'Handle @$cleanHandle is available!';

      if (isTaken) {
        _updateHandleSuggestions(cleanHandle);
      } else {
        handleSuggestions.clear();
      }
    } catch (e, stackTrace) {
      if (requestId != _customUrlRequestId) return;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelAvailabilityMixin.checkCustomUrlAvailability',
      );
      customUrlAvailability.value = AvailabilityStatus.error;
      customUrlAvailabilityMessage.value = _getFriendlyErrorMessage(e, 'handle');
    }
  }

  String _getFriendlyErrorMessage(Object e, String field) {
    final str = e.toString().toLowerCase();
    if (str.contains('network') ||
        str.contains('socket') ||
        str.contains('unavailable') ||
        str.contains('timeout') ||
        str.contains('connection') ||
        str.contains('offline')) {
      return 'No internet connection. Tap retry when back online.';
    }
    return 'Unable to check $field availability. Tap retry to check again.';
  }

  Future<AvailabilityStatus> _executeResilientHandleCheck(String cleanHandle) async {
    final lowerHandle = cleanHandle.toLowerCase();
    final currentUid = auth.currentUser?.uid;
    const maxAttempts = 3;
    Exception? lastException;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        var isTaken = false;

        // 1. Point-read on channel_handles collection: O(1) document ID lookup.
        try {
          final handleDoc = await firestore
              .collection('channel_handles')
              .doc(lowerHandle)
              .get()
              .timeout(const Duration(seconds: 10));

          if (handleDoc.exists) {
            final data = handleDoc.data();
            final ownerId = data?['ownerId'] as String?;
            if (ownerId != null && currentUid != null && ownerId == currentUid) {
              isTaken = false;
            } else {
              isTaken = true;
            }
            return isTaken ? AvailabilityStatus.taken : AvailabilityStatus.available;
          }
        } catch (e, stackTrace) {
          // If channel_handles point-read fails (e.g. permission or transient network glitch), log and fallback to channels query
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'ChannelAvailabilityMixin._executeResilientHandleCheck.channel_handles_fallback',
          );
        }

        // 2. Query channels collection with limit(1) to check legacy/existing channels
        final snapshot = await firestore
            .collection(ChannelControllerBase.channelsCol)
            .where('handleLowercase', isEqualTo: lowerHandle)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (snapshot.docs.isNotEmpty) {
          final docData = snapshot.docs.first.data();
          final ownerId = (docData['ownerId'] ?? docData['userId']) as String?;
          final status = (docData['status'] as String? ?? 'active').toLowerCase();
          if (status != 'deleted' && (currentUid == null || ownerId != currentUid)) {
            isTaken = true;
          }
        }

        return isTaken ? AvailabilityStatus.taken : AvailabilityStatus.available;
      } catch (e, stackTrace) {
        lastException = e is Exception ? e : Exception(e.toString());
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelAvailabilityMixin._executeResilientHandleCheck.attempt_$attempt',
        );

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    }

    throw lastException ?? Exception('Failed to check handle availability after retries');
  }

  void resetAvailabilityStatus() {
    channelNameAvailability.value = AvailabilityStatus.unknown;
    customUrlAvailability.value = AvailabilityStatus.unknown;
    channelNameAvailabilityMessage.value = '';
    customUrlAvailabilityMessage.value = '';
    handleSuggestions.clear();
  }

  @visibleForTesting
  void setCachedHandleStatus(String handle, AvailabilityStatus status) {
    var clean = handle.trim().toLowerCase();
    if (clean.startsWith('@')) clean = clean.substring(1);
    _customUrlCache[clean] = status;
  }

  @visibleForTesting
  void setCachedNameStatus(String name, AvailabilityStatus status) {
    _channelNameCache[name.trim().toLowerCase()] = status;
  }

  @override
  void disposeAvailabilityTimers() {
    _channelNameDebounceTimer?.cancel();
    _customUrlDebounceTimer?.cancel();
    _channelNameDebounceTimer = null;
    _customUrlDebounceTimer = null;
    _customUrlRequestId++;
    _channelNameRequestId++;
  }
}
