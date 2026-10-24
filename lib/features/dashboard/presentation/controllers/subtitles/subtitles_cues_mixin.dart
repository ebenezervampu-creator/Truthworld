import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';

/// Mixin handling cue editing, additions, deletions, timing shifts, and search/replace
mixin SubtitlesCuesMixin on SubtitlesControllerBase {
  void addLanguageTrack(String langCode, {bool copyCuesFromCurrent = false}) {
    if (availableLanguages.contains(langCode)) {
      selectedLanguage.value = langCode;
      hasUnsavedChanges.value = false;
      final subs = selectedVideo.value?.mediaSubtitles ?? {};
      if (subs.containsKey(langCode)) {
        parseCuesForLanguage(langCode, subs[langCode]);
      } else {
        currentCues.clear();
      }
      return;
    }
    availableLanguages.add(langCode);
    selectedLanguage.value = langCode;
    if (copyCuesFromCurrent && currentCues.isNotEmpty) {
      currentCues.value = currentCues
          .map((c) => SubtitleCue(
                id: UniqueKey().toString(),
                startTime: c.startTime,
                endTime: c.endTime,
                text: c.text,
              ))
          .toList();
      hasUnsavedChanges.value = true;
    } else {
      currentCues.clear();
    }
    showSuccess('Added new track for ${getLanguageName(langCode)}');
  }

  void updateCueText(int index, String newText) {
    if (index < 0 || index >= currentCues.length) return;
    if (currentCues[index].text != newText) {
      recordSnapshot();
      currentCues[index].text = newText;
      hasUnsavedChanges.value = true;
      currentCues.refresh();
    }
  }

  void updateCueTiming(int index, {String? startTime, String? endTime}) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    if (startTime != null) currentCues[index].startTime = startTime;
    if (endTime != null) currentCues[index].endTime = endTime;
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  void toggleSelectCue(String id) {
    if (selectedCueIds.contains(id)) {
      selectedCueIds.remove(id);
    } else {
      selectedCueIds.add(id);
    }
  }

  void toggleSelectAllCues() {
    if (selectedCueIds.length == currentCues.length && currentCues.isNotEmpty) {
      selectedCueIds.clear();
    } else {
      selectedCueIds
        ..clear()
        ..addAll(currentCues.map((c) => c.id));
    }
  }

  void deleteSelectedCues() {
    if (selectedCueIds.isEmpty) return;
    recordSnapshot();
    currentCues.removeWhere((c) => selectedCueIds.contains(c.id));
    selectedCueIds.clear();
    hasUnsavedChanges.value = true;
    currentCues.refresh();
    showSuccess('Removed selected subtitle segments');
  }

  void setZoomScale(double scale) {
    cueZoomScale.value = scale.clamp(0.7, 1.5);
  }

  void zoomIn() {
    setZoomScale(cueZoomScale.value + 0.1);
  }

  void zoomOut() {
    setZoomScale(cueZoomScale.value - 0.1);
  }

  void addNewCue() {
    recordSnapshot();
    final lastEndTime = currentCues.isNotEmpty
        ? currentCues.last.endTime
        : '00:00:00.000';
    currentCues.add(
      SubtitleCue(
        id: UniqueKey().toString(),
        startTime: lastEndTime,
        endTime: shiftTimeString(
          lastEndTime,
          4000,
        ),
        text: 'New Subtitle Segment',
      ),
    );
    hasUnsavedChanges.value = true;
  }

  void addCueAtCurrentTime() {
    recordSnapshot();
    final curPos = currentVideoPosition.value;
    final startStr = SubtitlesControllerBase.formatDurationToTimecode(curPos);
    final endStr = SubtitlesControllerBase.formatDurationToTimecode(curPos + const Duration(seconds: 4));
    currentCues.add(
      SubtitleCue(
        id: UniqueKey().toString(),
        startTime: startStr,
        endTime: endStr,
        text: 'New Subtitle Segment',
      ),
    );
    sortCuesChronologically();
    hasUnsavedChanges.value = true;
  }

  void setStartToCurrentTime(int index) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    currentCues[index].startTime =
        SubtitlesControllerBase.formatDurationToTimecode(currentVideoPosition.value);
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  void setEndToCurrentTime(int index) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    currentCues[index].endTime =
        SubtitlesControllerBase.formatDurationToTimecode(currentVideoPosition.value);
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  void duplicateCue(int index) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    final original = currentCues[index];
    final shiftedStart = shiftTimeString(original.endTime, 100);
    final shiftedEnd = shiftTimeString(shiftedStart, 3000);
    currentCues.insert(
      index + 1,
      SubtitleCue(
        id: UniqueKey().toString(),
        startTime: shiftedStart,
        endTime: shiftedEnd,
        text: original.text,
      ),
    );
    hasUnsavedChanges.value = true;
  }

  void clearAllCues() {
    recordSnapshot();
    currentCues.clear();
    hasUnsavedChanges.value = true;
    showSuccess(
        'Cleared all cues in ${getLanguageName(selectedLanguage.value)} track');
  }

  void sortCuesChronologically() {
    currentCues.sort((a, b) {
      final aMs = SubtitleParser.parseTimeDuration(a.startTime).inMilliseconds;
      final bMs = SubtitleParser.parseTimeDuration(b.startTime).inMilliseconds;
      return aMs.compareTo(bMs);
    });
    currentCues.refresh();
  }

  void shiftAllCues(int offsetMs) {
    if (currentCues.isEmpty) return;
    recordSnapshot();
    for (var i = 0; i < currentCues.length; i++) {
      final cue = currentCues[i];
      cue.startTime = shiftTimeString(cue.startTime, offsetMs);
      cue.endTime = shiftTimeString(cue.endTime, offsetMs);
    }
    hasUnsavedChanges.value = true;
    currentCues.refresh();
    showSuccess(
      'Shifted all cues by ${offsetMs >= 0 ? "+$offsetMs" : "$offsetMs"}ms',
    );
  }

  int replaceTextInCues(String findText, String replaceWith) {
    if (findText.isEmpty) return 0;
    recordSnapshot();
    var count = 0;
    for (var i = 0; i < currentCues.length; i++) {
      if (currentCues[i].text.contains(findText)) {
        currentCues[i].text =
            currentCues[i].text.replaceAll(findText, replaceWith);
        count++;
      }
    }
    if (count > 0) {
      hasUnsavedChanges.value = true;
      currentCues.refresh();
      showSuccess('Replaced $count occurrences of "$findText"');
    } else {
      showError('No occurrences found for "$findText"');
    }
    return count;
  }

  void deleteCue(int index) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    currentCues.removeAt(index);
    hasUnsavedChanges.value = true;
  }

  void shiftCueTiming(
    int index, {
    bool isStart = true,
    int shiftMilliseconds = 500,
  }) {
    if (index < 0 || index >= currentCues.length) return;
    recordSnapshot();
    final cue = currentCues[index];
    final targetTimeStr = isStart ? cue.startTime : cue.endTime;

    final shifted = shiftTimeString(targetTimeStr, shiftMilliseconds);
    if (isStart) {
      cue.startTime = shifted;
    } else {
      cue.endTime = shifted;
    }
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  void setCueSearchQuery(String query) {
    searchQueryInCues.value = query;
  }
}
