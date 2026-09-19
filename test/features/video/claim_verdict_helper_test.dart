import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  group('ClaimVerdictHelper', () {
    group('All verdict string variants', () {
      test('Verified True variants', () {
        final variants = [
          'verified_true',
          'verified',
          'true',
          'correct',
          'verified true'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.verifiedTrue,
              reason: 'Failed on $v');
          expect(info.color, AppColors.success, reason: 'Failed on $v');
          expect(info.isVerified, isTrue, reason: 'Failed on $v');
          expect(info.isFalse, isFalse, reason: 'Failed on $v');
          expect(info.isCaution, isFalse, reason: 'Failed on $v');
          expect(info.isContextual, isFalse, reason: 'Failed on $v');
        }
      });

      test('Mostly True variants', () {
        final variants = [
          'mostly_true',
          'mostly_correct',
          'partially_true',
          'mostly true',
          'mostly correct'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.mostlyTrue,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFF10B981), reason: 'Failed on $v');
          expect(info.isVerified, isTrue, reason: 'Failed on $v');
          expect(info.isFalse, isFalse, reason: 'Failed on $v');
        }
      });

      test('False Claim variants', () {
        final variants = [
          'false_claim',
          'false',
          'incorrect',
          'verified_false',
          'historical_consensus_denial',
          'false claim'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.falseClaim,
              reason: 'Failed on $v');
          expect(info.color, AppColors.error, reason: 'Failed on $v');
          expect(info.isFalse, isTrue, reason: 'Failed on $v');
          expect(info.isVerified, isFalse, reason: 'Failed on $v');
        }
      });

      test('Misleading variants', () {
        final variants = ['misleading', 'distorted', 'deceptive', 'mostly_false'];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.misleading,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFFF97316), reason: 'Failed on $v');
          expect(info.isFalse, isTrue, reason: 'Failed on $v');
        }
      });

      test('Disputed variants', () {
        final variants = ['disputed', 'contested', 'contested_interpretation'];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.disputed, reason: 'Failed on $v');
          expect(info.color, AppColors.warning, reason: 'Failed on $v');
          expect(info.isCaution, isTrue, reason: 'Failed on $v');
        }
      });

      test('Satire / Hyperbole variants', () {
        final variants = [
          'satire',
          'satire_claim',
          'humor',
          'parody',
          'hyperbole'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.contextual,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFF38BDF8), reason: 'Failed on $v');
          expect(info.isContextual, isTrue, reason: 'Failed on $v');
        }
      });

      test('Faith / Tradition variants', () {
        final variants = [
          'faith_based_claim',
          'religious_belief',
          'not_historically_verifiable',
          'historical_tradition',
          'doctrinal_unverifiable'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.contextual,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFFA78BFA), reason: 'Failed on $v');
          expect(info.isContextual, isTrue, reason: 'Failed on $v');
        }
      });

      test('Opinion variants', () {
        final variants = [
          'opinion',
          'opinion_claim',
          'anecdotal_experience',
          'value_judgment',
          'preference_statement'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.contextual,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFF60A5FA), reason: 'Failed on $v');
          expect(info.isContextual, isTrue, reason: 'Failed on $v');
        }
      });

      test('Inconclusive and related variants', () {
        final variants = [
          'needs_context',
          'outdated',
          'inconclusive',
          'unsupported',
          'unproven',
          'limited_support',
          'verification_timeout'
        ];
        for (final v in variants) {
          final info = ClaimVerdictHelper.resolveVerdictString(v);
          expect(info.type, ClaimVerdictType.inconclusive,
              reason: 'Failed on $v');
          expect(info.color, const Color(0xFFEAB308), reason: 'Failed on $v');
          expect(info.isCaution, isTrue, reason: 'Failed on $v');
        }
      });
    });

    group('Input types', () {
      test('Null or empty input returns default unverified', () {
        final nullInfo = ClaimVerdictHelper.resolveVerdict(null);
        expect(nullInfo.label, 'UNVERIFIED');
        expect(nullInfo.type, ClaimVerdictType.inconclusive);

        final emptyInfo = ClaimVerdictHelper.resolveVerdict('   ');
        expect(emptyInfo.label, 'UNVERIFIED');
      });

      test('String input resolves successfully', () {
        final info = ClaimVerdictHelper.resolveVerdict('mostly_true');
        expect(info.type, ClaimVerdictType.mostlyTrue);
      });

      test('ClaimResult input resolves successfully', () {
        final claim = ClaimResult(
          text: 'test claim',
          verdict: 'verified_true',
          classificationConfidence: 0.95,
        );
        final info = ClaimVerdictHelper.resolveVerdict(claim);
        expect(info.type, ClaimVerdictType.verifiedTrue);
        expect(info.confidenceVal, 0.95);
        expect(info.confidenceText, 'High (95%)');
      });

      test('Map with various keys resolves successfully', () {
        final keys = ['status', 'verificationStatus', 'verdict', 'label'];
        for (final key in keys) {
          final info = ClaimVerdictHelper.resolveVerdict({key: 'false_claim'});
          expect(info.type, ClaimVerdictType.falseClaim,
              reason: 'Failed with key: $key');
        }
      });

      test('Map with isVerified flag resolves to verified true', () {
        final info = ClaimVerdictHelper.resolveVerdict({
          'status': 'custom_status',
          'isVerified': true,
        });
        expect(info.type, ClaimVerdictType.verifiedTrue);
      });
    });

    group('Confidence extraction and formatting', () {
      test('Percentage > 1.0 is converted to fraction', () {
        final info = ClaimVerdictHelper.resolveVerdict({
          'status': 'verified',
          'confidence': 90.0,
        });
        expect(info.confidenceVal, 0.9);
        expect(info.confidenceText, 'High (90%)');
      });

      test('Fraction <= 1.0 is handled correctly', () {
        final info = ClaimVerdictHelper.resolveVerdict({
          'status': 'verified',
          'confidence': 0.65,
        });
        expect(info.confidenceVal, 0.65);
        expect(info.confidenceText, 'Medium (65%)');
      });

      test('Low confidence resolves to Limited', () {
        final info = ClaimVerdictHelper.resolveVerdict({
          'status': 'verified',
          'confidence': 0.4,
        });
        expect(info.confidenceText, 'Limited (40%)');
      });

      test('Null confidence yields null fields', () {
        final info = ClaimVerdictHelper.resolveVerdict({'status': 'verified'});
        expect(info.confidenceVal, isNull);
        expect(info.confidenceText, isNull);
      });
    });

    group('Text cleaning', () {
      test('cleanResponseText strips prefixes', () {
        final inputs = [
          '[RECOVERY PASS] This is text.',
          '[FAST KNOWLEDGE RECOVERY] This is text.',
          '[GROUNDING] This is text.',
          '[FAST PASS] This is text.',
          '[LLM] This is text.',
          '[RECOVERY] This is text.',
          '✅ This is text.',
          '❌ This is text.',
        ];

        for (final input in inputs) {
          expect(ClaimVerdictHelper.cleanResponseText(input), 'This is text.');
        }
      });

      test('cleanClaimText strips emojis and handles fallback', () {
        expect(ClaimVerdictHelper.cleanClaimText('✅ Good claim', 0),
            'Good claim');
        expect(ClaimVerdictHelper.cleanClaimText('❔ Questionable claim', 1),
            'Questionable claim');
        expect(ClaimVerdictHelper.cleanClaimText('', 5), 'Claim #6');
        expect(ClaimVerdictHelper.cleanClaimText('  ✅  ', 2), 'Claim #3');
      });
    });
  });
}
