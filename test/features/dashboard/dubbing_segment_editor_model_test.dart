import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_segment_editor_controller.dart';

void main() {
  group('DubbingSegmentEditor Models & Metadata', () {
    test('DubbingEditableSegmentModel prefers editedText when non-empty and parses fields accurately', () {
      final seg = DubbingEditableSegmentModel.fromMap({
        'index': 4,
        'startMs': 12500,
        'endMs': 16200,
        'speaker': 'speaker_1',
        'originalText': 'Hello TruthWorld!',
        'translatedText': '[excited] హలో TruthWorld!',
        'editedText': '[whispers] హలో ట్రూత్ వరల్డ్!',
        'emotionTag': 'whispers',
        'stabilityOverride': 0.34,
        'similarityBoostOverride': 0.88,
        'synthesizedAudioUrl': 'https://example.com/seg4.mp3',
      });

      expect(seg.index, 4);
      expect(seg.startMs, 12500);
      expect(seg.endMs, 16200);
      expect(seg.displayText, '[whispers] హలో ట్రూత్ వరల్డ్!');
      expect(seg.emotionTag, 'whispers');
      expect(seg.stabilityOverride, 0.34);

      final updated = seg.copyWith(clearEmotionTag: true, editedText: 'Updated line');
      expect(updated.emotionTag, isNull);
      expect(updated.displayText, 'Updated line');
    });

    test('PronunciationRuleModel serializes and parses IPA/phonetic rules', () {
      final rule = PronunciationRuleModel.fromMap({
        'id': 'rule_1',
        'term': 'TruthWorld',
        'ipaOrPhonetic': 'Trooth-Wurld',
        'caseSensitive': true,
      });

      expect(rule.term, 'TruthWorld');
      expect(rule.replacement, 'Trooth-Wurld');
      expect(rule.caseSensitive, isTrue);
      expect(rule.toMap(), {
        'id': 'rule_1',
        'term': 'TruthWorld',
        'replacement': 'Trooth-Wurld',
        'caseSensitive': true,
      });
    });

    test('Exposes whitelisted ElevenLabs v4 expressive audio tags', () {
      expect(
        DubbingSegmentEditorController.supportedEmotionTags,
        containsAll(['whispers', 'excited', 'laughs', 'sighs', 'sorrowful', 'angry']),
      );
    });

    test('Parses DAW acoustic & syllable fields and updates startMs/endMs via copyWith', () {
      final seg = DubbingEditableSegmentModel.fromMap({
        'index': 2,
        'startMs': 3200,
        'endMs': 6100,
        'speaker': 'speaker_1',
        'originalText': 'Hold the line!',
        'translatedText': 'లైన్ లో ఉండండి!',
        'energyDb': -15.4,
        'pitchRangeSemitones': 7.5,
        'voiceQuality': 'pressed',
        'syllableBudgetCompliance': 0.96,
        'deliveryStyle': 'urgent drama',
      });

      expect(seg.energyDb, -15.4);
      expect(seg.pitchRangeSemitones, 7.5);
      expect(seg.voiceQuality, 'pressed');
      expect(seg.syllableBudgetCompliance, 0.96);
      expect(seg.deliveryStyle, 'urgent drama');

      final shifted = seg.copyWith(startMs: 3350, endMs: 6350);
      expect(shifted.startMs, 3350);
      expect(shifted.endMs, 6350);
      expect(shifted.voiceQuality, 'pressed');
      expect(shifted.energyDb, -15.4);
    });
  });
}
