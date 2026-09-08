import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';

void main() {
  group('ContentValidator Multi-layer Profanity & Offensive Content Tests', () {
    test('passes clean, valid text', () {
      final res = ContentValidator.validate('This is a great educational video on quantum physics!');
      expect(res.isValid, isTrue);
      expect(res.message, equals('Valid'));
    });

    test('rejects empty or whitespace content', () {
      final res = ContentValidator.validate('   ', fieldName: 'Title');
      expect(res.isValid, isFalse);
      expect(res.message, contains('cannot be empty'));
    });

    test('enforces min and max length', () {
      final minRes = ContentValidator.validate('abc', fieldName: 'Description', minLength: 5);
      expect(minRes.isValid, isFalse);
      expect(minRes.message, contains('at least 5 characters'));

      final maxRes = ContentValidator.validate('abcdefghijk', fieldName: 'Title', maxLength: 10);
      expect(maxRes.isValid, isFalse);
      expect(maxRes.message, contains('cannot exceed 10 characters'));
    });

    test('detects core English profanity', () {
      final res = ContentValidator.validate('This is complete bullshit and shit', fieldName: 'Comment');
      expect(res.isValid, isFalse);
      expect(res.message, contains('inappropriate language'));
    });

    test('detects multi-language profanity', () {
      // German profane word "scheiße"
      final resDe = ContentValidator.validate('Das ist eine scheiße', fieldName: 'Post');
      expect(resDe.isValid, isFalse);

      // French profane word "merde"
      final resFr = ContentValidator.validate("C'est de la merde", fieldName: 'Post');
      expect(resFr.isValid, isFalse);
    });

    test('detects leetspeak and symbol-obfuscated profanity', () {
      // p0rn
      final resPorn = ContentValidator.validate('check out this p0rn video', fieldName: 'Title');
      expect(resPorn.isValid, isFalse);

      // b!tch
      final resBitch = ContentValidator.validate('you are a b!tch', fieldName: 'Comment');
      expect(resBitch.isValid, isFalse);

      // a$$
      final resAss = ContentValidator.validate(r'look at that a$$', fieldName: 'Comment');
      expect(resAss.isValid, isFalse);

      // f.u.c.k
      final resFuckDots = ContentValidator.validate('what the f.u.c.k is this', fieldName: 'Comment');
      expect(resFuckDots.isValid, isFalse);

      // s-h-i-t
      final resShitDashes = ContentValidator.validate('this is total s-h-i-t', fieldName: 'Title');
      expect(resShitDashes.isValid, isFalse);
    });

    test('detects repeated character runs inside profane words', () {
      final res = ContentValidator.validate('what the fuuuuuck', fieldName: 'Comment');
      expect(res.isValid, isFalse);

      final res2 = ContentValidator.validate('this is shiiiiit', fieldName: 'Title');
      expect(res2.isValid, isFalse);
    });

    test('detects Cyrillic homoglyph substitutions', () {
      // "nazi" with Cyrillic 'а' (U+0430)
      final res = ContentValidator.validate('n\u0430zi propaganda', fieldName: 'Topic');
      expect(res.isValid, isFalse);
    });

    test('detects inappropriate emojis', () {
      final resEggplant = ContentValidator.validate('Check this 🍆', fieldName: 'Comment');
      expect(resEggplant.isValid, isFalse);
      expect(resEggplant.message, contains('inappropriate emojis'));

      final resMiddleFinger = ContentValidator.validate('You 🖕', fieldName: 'Comment');
      expect(resMiddleFinger.isValid, isFalse);

      final resPeach = ContentValidator.validate('Nice 🍑', fieldName: 'Comment');
      expect(resPeach.isValid, isFalse);
    });

    test('detects prohibited domain and scam patterns', () {
      final resPornhub = ContentValidator.validate('visit pornhub today', fieldName: 'Description');
      expect(resPornhub.isValid, isFalse);

      final resBitly = ContentValidator.validate('click on bit.ly/freecash now', fieldName: 'Post');
      expect(resBitly.isValid, isFalse);

      final resScam = ContentValidator.validate('get free money right here', fieldName: 'Title');
      expect(resScam.isValid, isFalse);
    });

    test('detects phone numbers when enabled', () {
      final resPhone = ContentValidator.validate(
        'Call me at +1 800-555-0199 for info',
        fieldName: 'Channel Name',
        checkPhoneNumbers: true,
      );
      expect(resPhone.isValid, isFalse);
      expect(resPhone.message, contains('phone number'));
    });

    test('validates tag lists properly', () {
      final validTagsRes = ContentValidator.validateTags(['Science', 'Tech', 'Education']);
      expect(validTagsRes.isValid, isTrue);

      final emptyTagsRes = ContentValidator.validateTags([]);
      expect(emptyTagsRes.isValid, isFalse);

      final tooManyTagsRes = ContentValidator.validateTags(['1', '2', '3', '4', '5', '6']);
      expect(tooManyTagsRes.isValid, isFalse);
      expect(tooManyTagsRes.message, contains('Maximum 5 tags allowed'));

      final profaneTagRes = ContentValidator.validateTags(['Tech', 'porn', 'Science']);
      expect(profaneTagRes.isValid, isFalse);
      expect(profaneTagRes.message, contains('Tag "porn" is invalid'));
    });

    test('validates membership tier names and standard perks cleanly without false positives', () {
      final tierName = ContentValidator.validate('Silver VIP', fieldName: 'Tier Name');
      expect(tierName.isValid, isTrue);

      final shortName = ContentValidator.validate('hi', fieldName: 'Tier Name');
      expect(shortName.isValid, isTrue);

      final perk1 = ContentValidator.validate('Loyalty badge, Early access to videos', fieldName: 'Perk');
      expect(perk1.isValid, isTrue);

      final perk2 = ContentValidator.validate('Custom channel emojis in live chat & comments', fieldName: 'Perk');
      expect(perk2.isValid, isTrue);

      final perk3 = ContentValidator.validate('Behind-the-scenes clips & bloopers', fieldName: 'Perk');
      expect(perk3.isValid, isTrue);
    });
  });
}
