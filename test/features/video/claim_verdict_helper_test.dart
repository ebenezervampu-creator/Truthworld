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

      test('cleanResponseText humanizes robotic subjective/opinion responses and explains why it was configured as an opinion', () {
        const roboticInput1 = 'Classified as subjective content — not subject to factual verification.';
        final humanized1 = ClaimVerdictHelper.cleanResponseText(roboticInput1);
        expect(
          humanized1,
          'Classified as an opinion because this statement shares a personal viewpoint or feeling rather than a measurable fact that can be proven true or false.',
        );

        const roboticInput2 = 'Classified as subjective content - not subject to factual verification';
        final humanized2 = ClaimVerdictHelper.cleanResponseText(
          roboticInput2,
          claimText: "The word 'complete' (in complete protein) is vital.",
        );
        expect(
          humanized2,
          "Classified as an opinion because the speaker describes this as 'vital'. While science can measure real facts like nutrients or numbers, deciding that something is 'vital' is a personal value judgment, not a measurable fact.",
        );

        const roboticInput3 = 'Subjective content — not subject to factual verification.';
        final humanized3 = ClaimVerdictHelper.cleanResponseText(
          roboticInput3,
          claimText: 'Chocolate ice cream is the best dessert.',
        );
        expect(
          humanized3,
          "Classified as an opinion because the speaker uses the word 'best'. Words like 'best' describe personal taste — everyone likes different things, and no science test can prove what is truly 'best'.",
        );
      });

      test('Opinion verdict summary takeaway explains why it was configured as an opinion', () {
        final opinionVerdict = ClaimVerdictHelper.resolveVerdictString('opinion');
        expect(
          opinionVerdict.summaryTakeaway,
          'Classified as an opinion because it shares a personal perspective or value judgment rather than a measurable fact.',
        );
        expect(opinionVerdict.microTakeaway, 'Personal viewpoint, not a testable fact');
      });

      test('cleanClaimText strips emojis and handles fallback', () {
        expect(ClaimVerdictHelper.cleanClaimText('✅ Good claim', 0),
            'Good claim');
        expect(ClaimVerdictHelper.cleanClaimText('❔ Questionable claim', 1),
            'Questionable claim');
        expect(ClaimVerdictHelper.cleanClaimText('', 5), 'Claim #6');
        expect(ClaimVerdictHelper.cleanClaimText('  ✅  ', 2), 'Claim #3');
      });

      test('humanizeConclusionText transforms academic conclusions into kid-accessible English', () {
        const academicInput = 'Empirical corroboration substantiates the core tenets of this video with verified data.';
        final humanized = ClaimVerdictHelper.humanizeConclusionText(academicInput);
        expect(humanized, contains('Reliable experts and records back up what was said'));

        const roboticNoClaims = 'No empirical assertions were detected in the speech transcript.';
        final humanizedNoClaims = ClaimVerdictHelper.humanizeConclusionText(roboticNoClaims);
        expect(humanizedNoClaims, contains("We checked this video and didn't find any specific facts that need checking"));

        const roboticThesis = 'The overarching thesis presents empirical concordance with published archives.';
        final humanizedThesis = ClaimVerdictHelper.humanizeConclusionText(roboticThesis);
        expect(humanizedThesis, contains('The main points in this video match real facts from'));
      });

      test('buildCompleteVideoConclusion generates a single cohesive paragraph answering the video', () {
        final conclusionVerified = ClaimVerdictHelper.buildCompleteVideoConclusion(
          videoTitle: 'How Driverless Robotaxis Work',
          summary: 'This video explores how autonomous robotaxis navigate city streets.',
          verifiedCount: 15,
          cautionCount: 2,
          falseCount: 0,
        );
        expect(conclusionVerified, contains('autonomous robotaxis navigate city streets'));
        expect(conclusionVerified, contains('Our comprehensive verification confirms'));
        expect(conclusionVerified.contains('\n'), isFalse, reason: 'Must be a single paragraph');
        expect(conclusionVerified.startsWith('Based on '), isFalse);

        final conclusionTitleOnly = ClaimVerdictHelper.buildCompleteVideoConclusion(
          videoTitle: 'How Driverless Robotaxis Work',
          verifiedCount: 15,
          cautionCount: 2,
          falseCount: 0,
        );
        expect(conclusionTitleOnly, contains('How Driverless Robotaxis Work'));

        final conclusionCaution = ClaimVerdictHelper.buildCompleteVideoConclusion(
          videoTitle: 'Quantum Computing Breakthroughs',
          summary: 'A look at upcoming quantum processor timelines.',
          verifiedCount: 2,
          cautionCount: 8,
          falseCount: 0,
        );
        expect(conclusionCaution, contains('The documented events and real-world milestones'));
        expect(conclusionCaution.contains('\n'), isFalse);

        final conclusionFalse = ClaimVerdictHelper.buildCompleteVideoConclusion(
          videoTitle: 'Perpetual Energy Machine Revealed',
          verifiedCount: 1,
          cautionCount: 0,
          falseCount: 5,
        );
        expect(conclusionFalse, contains('conflict directly with documented records'));
        expect(conclusionFalse.contains('\n'), isFalse);

        // Ensures formulaic conclusions are replaced with complete answers
        final replacedFormula = ClaimVerdictHelper.buildCompleteVideoConclusion(
          rawConclusion: 'Based on 62 empirical claims evaluated across external authoritative sources: 12 verified true, 45 requiring context or caution, and 5 contradicted by documented evidence. Inspect individual claim breakdowns for citations and details.',
          videoTitle: 'Waymo Autonomous Fleet Expansion',
          verifiedCount: 12,
          cautionCount: 45,
          falseCount: 5,
        );
        expect(replacedFormula.startsWith('Based on '), isFalse);
        expect(replacedFormula, contains('conflict directly with documented records'));
      });

      test('getMostValuableSources ranks primary and authoritative sources and limits count', () {
        final sampleSources = [
          {'title': 'Random Blog', 'domain': 'randomblog.com', 'trustLevel': 'Low'},
          {'title': 'CPUC Regulatory Ruling', 'domain': 'cpuc.ca.gov', 'trustLevel': 'High', 'type': 'Primary'},
          {'title': 'Reuters Industry Report', 'domain': 'reuters.com', 'trustLevel': 'High'},
          {'title': 'Another CPUC Document', 'domain': 'cpuc.ca.gov', 'trustLevel': 'High'},
          {'title': 'NHTSA Crash Database', 'domain': 'nhtsa.gov', 'trustLevel': 'High', 'type': 'Primary'},
          {'title': 'Medium Tech Article', 'domain': 'medium.com', 'trustLevel': 'Medium'},
        ];

        final top = ClaimVerdictHelper.getMostValuableSources(sampleSources, limit: 3);
        expect(top.length, 3);
        // High-scoring gov and reuters sources should be selected
        final domains = top.map((s) => s['domain']).toList();
        expect(domains, contains('cpuc.ca.gov'));
        expect(domains, contains('nhtsa.gov'));
        expect(domains, contains('reuters.com'));
      });

      test('getClaimsOverviewHighlights extracts top verified, caution, and false claims', () {
        final sampleClaims = [
          {'claim': 'Opinion on future AI', 'status': 'opinion'},
          {'claim': 'Waymo operates in Phoenix', 'status': 'verified_true', 'isVerified': true},
          {'claim': 'Full profitability by next year', 'status': 'disputed'},
          {'claim': 'Cars fly over traffic', 'status': 'false_claim'},
        ];

        final highlights = ClaimVerdictHelper.getClaimsOverviewHighlights(sampleClaims);
        expect(highlights['topVerified']?['claim'], 'Waymo operates in Phoenix');
        expect(highlights['topCaution']?['claim'], 'Full profitability by next year');
        expect(highlights['topFalse']?['claim'], 'Cars fly over traffic');
      });
    });
  });
}
