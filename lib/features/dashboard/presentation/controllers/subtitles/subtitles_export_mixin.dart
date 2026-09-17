import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' show UniqueKey;
import 'package:flutter/services.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';

/// Mixin handling subtitle formats, conversions (SRT, WebVTT, JSON, TXT), clipboard and file downloads
mixin SubtitlesExportMixin on SubtitlesControllerBase {
  void exportCurrentTrack() {
    if (currentCues.isEmpty) {
      showError('No subtitle segments available to export.');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (final cue in currentCues) {
      buffer.writeln('${cue.startTime} --> ${cue.endTime}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showSuccess(
      'Exported ${getLanguageName(selectedLanguage.value)} track to Clipboard in WEBVTT format!',
    );
  }

  Future<void> downloadSrtTrack({String? langCode}) async {
    final targetLang = langCode ?? selectedLanguage.value;
    if (targetLang.isEmpty) {
      showError('No subtitle language track selected.');
      return;
    }

    final video = selectedVideo.value;
    final titleRaw = video?.title ?? 'subtitles';
    final videoTitle = titleRaw
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_$targetLang.srt';

    if (targetLang == selectedLanguage.value && currentCues.isNotEmpty) {
      final srtContent = compileSrtContent(currentCues);
      DownloadHelper.downloadText(
        srtContent,
        fileName,
        mimeType: 'application/x-subrip',
      );
      showSuccess('Downloaded SRT subtitles: $fileName');
      return;
    }

    final rawSub = video?.mediaSubtitles[targetLang];
    if (rawSub != null && rawSub.isNotEmpty) {
      if (rawSub.startsWith('gs://') ||
          rawSub.startsWith('http://') ||
          rawSub.startsWith('https://')) {
        var downloadUrl = rawSub;
        if (rawSub.startsWith('gs://')) {
          try {
            downloadUrl = await FirebaseStorage.instance
                .refFromURL(rawSub)
                .getDownloadURL();
          } catch (e) {
            logger.error('Failed resolving gs:// subtitle URL',
                error: e, tag: SubtitlesControllerBase.subtitlesTag);
          }
        }
        DownloadHelper.downloadFromUrl(downloadUrl, fileName);
        showSuccess(
            'Downloading SRT file for ${getLanguageName(targetLang)}...');
      } else {
        final srtContent = convertTextToSrt(rawSub);
        DownloadHelper.downloadText(
          srtContent,
          fileName,
          mimeType: 'application/x-subrip',
        );
        showSuccess('Downloaded SRT subtitles: $fileName');
      }
    } else {
      showError('No subtitle data available to download.');
    }
  }

  void downloadVttTrack({String? langCode}) {
    final targetLang = langCode ?? selectedLanguage.value;
    if (targetLang.isEmpty || currentCues.isEmpty) {
      showError('No subtitle segments available to download.');
      return;
    }
    final video = selectedVideo.value;
    final titleRaw = video?.title ?? 'subtitles';
    final videoTitle = titleRaw
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_$targetLang.vtt';

    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (final cue in currentCues) {
      buffer.writeln('${cue.startTime} --> ${cue.endTime}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    DownloadHelper.downloadText(
      buffer.toString(),
      fileName,
      mimeType: 'text/vtt',
    );
    showSuccess('Downloaded WebVTT subtitles: $fileName');
  }

  void downloadTxtTranscript({String? langCode}) {
    final targetLang = langCode ?? selectedLanguage.value;
    if (targetLang.isEmpty || currentCues.isEmpty) {
      showError('No subtitle segments available to download.');
      return;
    }
    final video = selectedVideo.value;
    final titleRaw = video?.title ?? 'subtitles';
    final videoTitle = titleRaw
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_$targetLang.txt';

    final buffer = StringBuffer();
    for (final cue in currentCues) {
      if (cue.text.trim().isNotEmpty) {
        buffer.writeln(cue.text.trim());
      }
    }

    DownloadHelper.downloadText(
      buffer.toString(),
      fileName,
    );
    showSuccess('Downloaded text transcript: $fileName');
  }

  void downloadJsonTrack({String? langCode}) {
    final targetLang = langCode ?? selectedLanguage.value;
    if (targetLang.isEmpty || currentCues.isEmpty) {
      showError('No subtitle segments available to download.');
      return;
    }
    final video = selectedVideo.value;
    final titleRaw = video?.title ?? 'subtitles';
    final videoTitle = titleRaw
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final fileName = '${videoTitle}_$targetLang.json';

    final jsonList = currentCues
        .map((c) => {
              'start': c.startTime,
              'end': c.endTime,
              'text': c.text,
            })
        .toList();

    DownloadHelper.downloadText(
      const JsonEncoder.withIndent('  ').convert(jsonList),
      fileName,
      mimeType: 'application/json',
    );
    showSuccess('Downloaded JSON subtitles: $fileName');
  }

  void copyToClipboard([String format = 'txt']) {
    if (currentCues.isEmpty) {
      showError('No subtitle segments available.');
      return;
    }
    String content;
    if (format == 'srt') {
      content = compileSrtContent(currentCues);
    } else if (format == 'txt') {
      content = currentCues
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n');
    } else {
      final buffer = StringBuffer();
      buffer.writeln('WEBVTT\n');
      for (final cue in currentCues) {
        buffer.writeln('${cue.startTime} --> ${cue.endTime}');
        buffer.writeln(cue.text);
        buffer.writeln();
      }
      content = buffer.toString();
    }
    Clipboard.setData(ClipboardData(text: content));
    showSuccess('Copied ${format.toUpperCase()} to clipboard!');
  }

  Future<void> downloadAllTracks() async {
    final video = selectedVideo.value;
    if (video == null || availableLanguages.isEmpty) {
      showError('No subtitle tracks available.');
      return;
    }
    for (final lang in availableLanguages) {
      await downloadSrtTrack(langCode: lang);
    }
    showSuccess(
      'Downloaded all (${availableLanguages.length}) subtitle tracks as SRT!',
    );
  }

  String compileSrtContent(List<SubtitleCue> cues) {
    final buffer = StringBuffer();
    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      final startSrt = cue.startTime.replaceAll('.', ',');
      final endSrt = cue.endTime.replaceAll('.', ',');
      buffer.writeln('${i + 1}');
      buffer.writeln('$startSrt --> $endSrt');
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String convertTextToSrt(String rawContent) {
    if (rawContent.contains('-->')) {
      final lines = rawContent.split('\n');
      final cues = <SubtitleCue>[];
      SubtitleCue? pendingCue;
      for (final line in lines) {
        if (line.contains('-->')) {
          if (pendingCue != null) cues.add(pendingCue);
          final parts = line.split('-->');
          pendingCue = SubtitleCue(
            id: UniqueKey().toString(),
            startTime: parts[0].trim(),
            endTime: parts.length > 1 ? parts[1].trim() : '00:00:05.000',
            text: '',
          );
        } else if (line.trim().isNotEmpty &&
            !line.startsWith('WEBVTT') &&
            pendingCue != null) {
          pendingCue.text = pendingCue.text.isEmpty
              ? line.trim()
              : '${pendingCue.text}\n${line.trim()}';
        }
      }
      if (pendingCue != null) cues.add(pendingCue);
      return compileSrtContent(cues);
    } else {
      final lines =
          rawContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final cues = <SubtitleCue>[];
      var startSec = 1;
      for (var i = 0; i < lines.length; i++) {
        final startPad = startSec.toString().padLeft(2, '0');
        final endPad = (startSec + 4).toString().padLeft(2, '0');
        cues.add(
          SubtitleCue(
            id: UniqueKey().toString(),
            startTime: '00:00:$startPad.000',
            endTime: '00:00:$endPad.000',
            text: lines[i].trim(),
          ),
        );
        startSec += 5;
      }
      return compileSrtContent(cues);
    }
  }
}
