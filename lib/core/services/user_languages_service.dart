import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

class UserLanguagesService extends GetxService {
  static UserLanguagesService get to {
    if (!Get.isRegistered<UserLanguagesService>()) {
      Get.put(UserLanguagesService(), permanent: true);
    }
    return Get.find<UserLanguagesService>();
  }

  final _box = GetStorage();

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

  void loadLanguages() {
    final uid = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    final keyPrefix = uid.isNotEmpty ? '${uid}_' : 'guest_';

    primaryLanguage.value = _box.read('${keyPrefix}primary_lang') ?? 'English';

    final savedSecondaries = _box.read('${keyPrefix}secondary_langs');
    if (savedSecondaries != null) {
      secondaryLanguages.assignAll(List<String>.from(savedSecondaries));
    } else {
      secondaryLanguages.clear();
    }

    final savedKnown = _box.read('${keyPrefix}known_langs');
    if (savedKnown != null) {
      knownLanguages.assignAll(List<String>.from(savedKnown));
    } else {
      knownLanguages.assignAll(['English']);
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
            _box.write('${uid}_primary_lang', primary);
            changed = true;
          }
          if (secondaries != null) {
            final list = List<String>.from(secondaries);
            if (!_areListsEqual(list, secondaryLanguages)) {
              secondaryLanguages.assignAll(list);
              _box.write('${uid}_secondary_langs', list);
              changed = true;
            }
          }
          if (known != null) {
            final list = List<String>.from(known);
            if (!_areListsEqual(list, knownLanguages)) {
              knownLanguages.assignAll(list);
              _box.write('${uid}_known_langs', list);
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

    await _box.write('${keyPrefix}primary_lang', primary);
    await _box.write('${keyPrefix}secondary_langs', secondaries);
    await _box.write('${keyPrefix}known_langs', known);

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

    if (cleanLabel == cleanTarget) return true;
    if (cleanLangCode == cleanTarget) return true;

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
      if (cleanLangCode == code || cleanLabel == name) {
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
