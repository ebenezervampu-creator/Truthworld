import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';

void main() {
  group('ClaimVerdictHelper Epistemic Cons Upgrades', () {
    test('resolves novel_hypothesis to Novel Hypothesis verdict', () {
      final info = ClaimVerdictHelper.resolveVerdictString('novel_hypothesis');
      expect(info.type, ClaimVerdictType.novelHypothesis);
      expect(info.label, 'NOVEL HYPOTHESIS');
      expect(info.color, const Color(0xFF06B6D4));
      expect(info.icon, Icons.science_rounded);
      expect(info.isVerified, isTrue);
      expect(info.summaryTakeaway, contains('New idea still being studied'));
      expect(info.summaryTakeaway.toLowerCase(), isNot(contains('this claim')));
    });

    test('resolves developing_story to Developing Story verdict', () {
      final info = ClaimVerdictHelper.resolveVerdictString('developing_story');
      expect(info.type, ClaimVerdictType.developingStory);
      expect(info.label, 'DEVELOPING STORY');
      expect(info.color, const Color(0xFF3B82F6));
      expect(info.icon, Icons.bolt_rounded);
      expect(info.isCaution, isTrue);
      expect(info.summaryTakeaway, contains('Breaking news story!'));
      expect(info.summaryTakeaway.toLowerCase(), isNot(contains('this claim')));
    });

    test('resolves rhetorical_exaggeration and hyperbole to contextual verdict', () {
      final info = ClaimVerdictHelper.resolveVerdictString('rhetorical_exaggeration');
      expect(info.type, ClaimVerdictType.contextual);
      expect(info.label, 'RHETORICAL EXAGGERATION');
      expect(info.color, const Color(0xFF38BDF8));
      expect(info.isContextual, isTrue);
      expect(info.summaryTakeaway, contains('Just an exaggeration!'));
      expect(info.summaryTakeaway.toLowerCase(), isNot(contains('this claim')));

      final claimMapInfo = ClaimVerdictHelper.resolveVerdict({
        'text': 'It rained a trillion gallons',
        'nature': 'RHETORICAL_EXAGGERATION',
      });
      expect(claimMapInfo.label, 'RHETORICAL EXAGGERATION');
      expect(claimMapInfo.isContextual, isTrue);
    });
  });
}
