import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

class UserLanguagesService extends GetxService {
  UserLanguagesService({GetStorage? storage}) : _injectedStorage = storage;

  static UserLanguagesService get to {
    if (!Get.isRegistered<UserLanguagesService>()) {
      Get.put(UserLanguagesService(), permanent: true);
    }
    return Get.find<UserLanguagesService>();
  }

  static bool get isRegistered => Get.isRegistered<UserLanguagesService>();

  static String normalizeCode(String? raw) => normalizeLanguageCode(raw);

  final GetStorage? _injectedStorage;
  GetStorage? _storageInstance;
  final Map<String, dynamic> _memoryCache = <String, dynamic>{};

  GetStorage? get _box {
    if (_injectedStorage != null) return _injectedStorage;
    if (_storageInstance != null) return _storageInstance;
    try {
      return _storageInstance = GetStorage();
    } catch (_) {
      return null;
    }
  }

  dynamic _readStorage(String key) {
    try {
      final box = _box;
      if (box != null) {
        final val = box.read(key);
        if (val != null) return val;
      }
    } catch (_) {}
    return _memoryCache[key];
  }

  Future<void> _writeStorage(String key, dynamic value) async {
    _memoryCache[key] = value;
    try {
      final box = _box;
      if (box != null) {
        await box.write(key, value);
      }
    } catch (_) {}
  }

  @visibleForTesting
  void setStorageForTesting(GetStorage? storage) {
    _storageInstance = storage;
  }

  final RxString primaryLanguage = 'English'.obs;
  final RxList<String> secondaryLanguages = <String>[].obs;
  final RxList<String> knownLanguages = <String>['English'].obs;

  Future<UserLanguagesService> init() async {
    loadLanguages();

    // Listen to authentication changes to reload user-specific preferences
    if (Get.isRegistered<AuthService>()) {
      ever(AuthService.to.currentUser, (_) => loadLanguages());
    }
    return this;
  }

  String get primaryLanguageCode => normalizeLanguageCode(primaryLanguage.value);
  List<String> get secondaryLanguageCodes =>
      secondaryLanguages.map(normalizeLanguageCode).toList();
  List<String> get knownLanguageCodes =>
      knownLanguages.map(normalizeLanguageCode).toList();

  /// Check whether a language code or name matches the user's primary language.
  bool isPrimaryLanguage(String? lang) {
    if (lang == null || lang.trim().isEmpty) return false;
    return normalizeLanguageCode(lang) == primaryLanguageCode;
  }

  /// Check whether a language matches any of user's active languages (primary, secondary, or known).
  bool isUserLanguage(String? lang) {
    if (lang == null || lang.trim().isEmpty) return false;
    final code = normalizeLanguageCode(lang);
    if (code == primaryLanguageCode) return true;
    if (secondaryLanguageCodes.contains(code)) return true;
    if (knownLanguageCodes.contains(code)) return true;
    return false;
  }

  /// Resolve default language by detecting device/system locale when no preference is saved.
  static String _resolveDefaultSystemLanguage() {
    try {
      final locale = PlatformDispatcher.instance.locale;
      final langCode = locale.languageCode.toLowerCase();
      final match = supportedLanguages.firstWhereOrNull(
        (l) => l.code.toLowerCase() == langCode,
      );
      if (match != null) {
        return match.name;
      }
    } catch (_) {}
    return 'English';
  }

  void loadLanguages() {
    final uid = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    final keyPrefix = uid.isNotEmpty ? '${uid}_' : 'guest_';

    final savedPrimary = _readStorage('${keyPrefix}primary_lang') as String?;
    if (savedPrimary != null && savedPrimary.trim().isNotEmpty) {
      primaryLanguage.value = savedPrimary.trim();
    } else {
      primaryLanguage.value = _resolveDefaultSystemLanguage();
    }

    final savedSecondaries = _readStorage('${keyPrefix}secondary_langs');
    if (savedSecondaries != null) {
      secondaryLanguages.assignAll(List<String>.from(savedSecondaries));
    } else {
      secondaryLanguages.clear();
    }

    final savedKnown = _readStorage('${keyPrefix}known_langs');
    if (savedKnown != null) {
      knownLanguages.assignAll(List<String>.from(savedKnown));
    } else {
      knownLanguages.assignAll([primaryLanguage.value]);
    }

    // Sync from Firestore in the background if authenticated
    if (uid.isNotEmpty) {
      _fetchFromFirestore(uid);
    }
  }

  Future<void> _fetchFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final primary = data['primaryLanguage'] as String?;
          final secondaries = data['secondaryLanguages'] as List?;
          final known = data['knownLanguages'] as List?;

          var changed = false;
          if (primary != null && primary != primaryLanguage.value) {
            primaryLanguage.value = primary;
            await _writeStorage('${uid}_primary_lang', primary);
            changed = true;
          }
          if (secondaries != null) {
            final list = List<String>.from(secondaries);
            if (!_areListsEqual(list, secondaryLanguages)) {
              secondaryLanguages.assignAll(list);
              await _writeStorage('${uid}_secondary_langs', list);
              changed = true;
            }
          }
          if (known != null) {
            final list = List<String>.from(known);
            if (!_areListsEqual(list, knownLanguages)) {
              knownLanguages.assignAll(list);
              await _writeStorage('${uid}_known_langs', list);
              changed = true;
            }
          }

          if (changed) {
            debugPrint(
              '[UserLanguagesService] Synced languages from Firestore: $primaryLanguage, $secondaryLanguages, $knownLanguages',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserLanguagesService.loadLanguages',
      );
    }
  }

  Future<void> setPrimaryLanguage(String primary) async {
    primaryLanguage.value = primary;
    final uid = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    final keyPrefix = uid.isNotEmpty ? '${uid}_' : 'guest_';
    await _writeStorage('${keyPrefix}primary_lang', primary);

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .set({
              'primaryLanguage': primary,
            }, SetOptions(merge: true));
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserLanguagesService.setPrimaryLanguage',
        );
      }
    }
  }

  Future<void> saveLanguages({
    required String primary,
    required List<String> secondaries,
    required List<String> known,
  }) async {
    primaryLanguage.value = primary;
    secondaryLanguages.assignAll(secondaries);
    knownLanguages.assignAll(known);

    final uid = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    final keyPrefix = uid.isNotEmpty ? '${uid}_' : 'guest_';

    await _writeStorage('${keyPrefix}primary_lang', primary);
    await _writeStorage('${keyPrefix}secondary_langs', secondaries);
    await _writeStorage('${keyPrefix}known_langs', known);

    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .set({
              'primaryLanguage': primary,
              'secondaryLanguages': secondaries,
              'knownLanguages': known,
            }, SetOptions(merge: true));
        debugPrint('[UserLanguagesService] Saved languages to Firestore');
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'UserLanguagesService.saveLanguages',
        );
      }
    }
  }

  /// Check if a track matches the target language (compares target name/code with track label/code)
  bool isLanguageMatch(
    String trackLabel,
    String trackLangCode,
    String targetLangName,
  ) {
    final cleanLabel = trackLabel.trim().toLowerCase();
    final cleanLangCode = trackLangCode.trim().toLowerCase();
    final cleanTarget = targetLangName.trim().toLowerCase();

    if (cleanLabel.isEmpty && cleanLangCode.isEmpty) return false;
    if (cleanTarget.isEmpty) return false;

    if (cleanLabel == cleanTarget) return true;
    if (cleanLangCode == cleanTarget) return true;

    final targetCode = normalizeLanguageCode(targetLangName);
    if (cleanLangCode.isNotEmpty && normalizeLanguageCode(cleanLangCode) == targetCode) {
      return true;
    }

    // Strip common track qualifiers: "(audio)", "(video)", "(original)", "original (...)"
    final strippedLabel = cleanLabel
        .replaceAll(RegExp(r'\((audio|video|original|subs?|dubbed?)\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'original\s*\(?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\(\)]'), '')
        .trim();

    if (strippedLabel.isNotEmpty) {
      if (strippedLabel == cleanTarget) return true;
      if (normalizeLanguageCode(strippedLabel) == targetCode) return true;
    }

    // Search target language in our global supportedLanguages ladder
    final targetMatch = supportedLanguages.firstWhereOrNull(
      (l) =>
          l.name.toLowerCase() == cleanTarget ||
          l.code.toLowerCase() == cleanTarget,
    );

    if (targetMatch != null) {
      final code = targetMatch.code.toLowerCase();
      final name = targetMatch.name.toLowerCase();

      // Match track code or label against target's code or name
      if (cleanLangCode == code || cleanLabel == name || strippedLabel == name) {
        return true;
      }
      if (cleanLabel.contains(name) || cleanLabel.contains(code) || strippedLabel.contains(name)) {
        return true;
      }
    }

    return false;
  }

  bool _areListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
