import 'dart:async';

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
    checkCustomUrlAvailability(clean);
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
      '${normalized}101',
      '${normalized}_vsp',
      '${normalized}777',
      'real_${normalized}',
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

  void checkChannelNameAvailability(String rawName) {
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
    if (_channelNameCache.containsKey(lowerName)) {
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

  Future<void> _performChannelNameAvailabilityCheck(
      String name, int requestId) async {
    final lowerName = name.trim().toLowerCase();
    try {
      final snapshot = await firestore
          .collection(ChannelControllerBase.channelsCol)
          .where('nameLowercase', isEqualTo: lowerName)
          .limit(1)
          .get();

      // Discard stale responses
      if (requestId != _channelNameRequestId) return;

      bool isTaken = false;
      if (snapshot.docs.isNotEmpty) {
        final docData = snapshot.docs.first.data();
        final status = (docData['status'] as String? ?? 'active').toLowerCase();
        if (status != 'deleted') {
          isTaken = true;
        }
      }

      final status =
          isTaken ? AvailabilityStatus.taken : AvailabilityStatus.available;
      _channelNameCache[lowerName] = status;
      channelNameAvailability.value = status;
      channelNameAvailabilityMessage.value = isTaken
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
      channelNameAvailabilityMessage.value =
          'Unable to check name availability right now.';
    }
  }

  void checkCustomUrlAvailability(String rawCustomUrl) {
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

  Future<void> _performCustomUrlAvailabilityCheck(
      String cleanHandle, int requestId) async {
    final lowerHandle = cleanHandle.toLowerCase();
    try {
      final currentUid = auth.currentUser?.uid;

      // 1. Point-read on channel_handles collection: O(1) document ID lookup.
      // Fastest possible read in Firestore (< 40ms) and costs only 1 document read.
      final handleDoc = await firestore
          .collection('channel_handles')
          .doc(lowerHandle)
          .get();

      // Discard stale responses
      if (requestId != _customUrlRequestId) return;

      bool isTaken = false;

      if (handleDoc.exists) {
        final data = handleDoc.data();
        final ownerId = data?['ownerId'] as String?;
        if (ownerId != null && currentUid != null && ownerId == currentUid) {
          isTaken = false;
        } else {
          isTaken = true;
        }
      } else {
        // 2. Query channels collection with limit(1) to check legacy/existing channels
        final snapshot = await firestore
            .collection(ChannelControllerBase.channelsCol)
            .where('handleLowercase', isEqualTo: lowerHandle)
            .limit(1)
            .get();

        if (requestId != _customUrlRequestId) return;

        if (snapshot.docs.isNotEmpty) {
          final docData = snapshot.docs.first.data();
          final ownerId = (docData['ownerId'] ?? docData['userId']) as String?;
          final status = (docData['status'] as String? ?? 'active').toLowerCase();
          if (status != 'deleted' && (currentUid == null || ownerId != currentUid)) {
            isTaken = true;
          }
        }
      }

      final status =
          isTaken ? AvailabilityStatus.taken : AvailabilityStatus.available;
      _customUrlCache[lowerHandle] = status;
      customUrlAvailability.value = status;
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
      customUrlAvailabilityMessage.value =
          'Unable to check handle availability right now.';
    }
  }

  void resetAvailabilityStatus() {
    channelNameAvailability.value = AvailabilityStatus.unknown;
    customUrlAvailability.value = AvailabilityStatus.unknown;
    channelNameAvailabilityMessage.value = '';
    customUrlAvailabilityMessage.value = '';
    handleSuggestions.clear();
  }

  @override
  void disposeAvailabilityTimers() {
    _channelNameDebounceTimer?.cancel();
    _customUrlDebounceTimer?.cancel();
    _channelNameDebounceTimer = null;
    _customUrlDebounceTimer = null;
  }
}
