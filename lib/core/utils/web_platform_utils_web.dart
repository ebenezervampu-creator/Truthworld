import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/web_platform_utils_stub.dart';
import 'package:web/web.dart' as web;

export 'package:truthworld/core/utils/web_platform_utils_stub.dart'
    show WebAudioPlayerAdapter;

/// Web implementation of platform utilities utilizing modern package:web and dart:js_interop.
class WebPlatformUtilsImpl {
  static String createBlobUrl(Uint8List bytes, [String mimeType = 'video/mp4']) {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
      return web.URL.createObjectURL(blob);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.createBlobUrl');
      return '';
    }
  }

  static void revokeBlobUrl(String url) {
    try {
      if (url.isNotEmpty) {
        web.URL.revokeObjectURL(url);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.revokeBlobUrl');
    }
  }

  static Future<Duration?> getVideoDurationFromBytes(
    Uint8List bytes, [
    String mimeType = 'video/mp4',
  ]) async {
    try {
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
      final url = web.URL.createObjectURL(blob);
      final video = web.document.createElement('video') as web.HTMLVideoElement
        ..src = url
        ..preload = 'metadata';

      final completer = Completer<Duration?>();
      video.onloadedmetadata = ((web.Event _) {
        final durSec = video.duration;
        web.URL.revokeObjectURL(url);
        if (!completer.isCompleted) {
          if (!durSec.isNaN && !durSec.isInfinite && durSec > 0) {
            completer.complete(Duration(seconds: durSec.floor()));
          } else {
            completer.complete(null);
          }
        }
      }).toJS;

      video.onerror = ((web.Event _) {
        web.URL.revokeObjectURL(url);
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS;

      return await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          web.URL.revokeObjectURL(url);
          return null;
        },
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.getVideoDurationFromBytes');
      return null;
    }
  }

  static bool isFullscreen() {
    try {
      return web.document.fullscreenElement != null;
    } catch (_) {
      return false;
    }
  }

  static void requestFullscreen() {
    try {
      if (web.document.fullscreenElement == null) {
        web.document.documentElement?.requestFullscreen();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.requestFullscreen');
    }
  }

  static void exitFullscreen() {
    try {
      if (web.document.fullscreenElement != null) {
        web.document.exitFullscreen();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.exitFullscreen');
    }
  }

  static StreamSubscription? onFullscreenChange(void Function(bool isFullscreen) callback) {
    try {
      return web.EventStreamProviders.fullscreenChangeEvent
          .forTarget(web.document)
          .listen((_) {
        callback(web.document.fullscreenElement != null);
      });
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.onFullscreenChange');
      return null;
    }
  }

  static void pushUrlHistory(String route) {
    try {
      web.window.history.pushState(null, '', route);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.pushUrlHistory');
    }
  }

  static double getInitialBandwidthHint({double defaultKbps = 5000}) {
    try {
      final nav = web.window.navigator as JSObject;
      if (nav.has('connection')) {
        final conn = nav['connection'] as JSObject?;
        if (conn != null) {
          if (conn.has('saveData')) {
            final saveData = conn['saveData'] as JSBoolean?;
            if (saveData != null && saveData.toDart) {
              return 800; // Data Saver mode active: conservative 800 kbps
            }
          }
          if (conn.has('downlink')) {
            final downlink = conn['downlink'] as JSNumber?;
            if (downlink != null) {
              return downlink.toDartDouble * 1000;
            }
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.getInitialBandwidthHint');
    }
    return defaultKbps;
  }

  static bool hasInjectedData() {
    try {
      if (!globalContext.has('__VIDEO_DATA__')) return false;
      final data = globalContext['__VIDEO_DATA__'];
      return data != null && !data.isUndefined;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.hasInjectedData');
      return false;
    }
  }

  static Map<String, dynamic>? getInjectedData() {
    try {
      if (!globalContext.has('__VIDEO_DATA__')) return null;
      final jsData = globalContext['__VIDEO_DATA__'] as JSObject?;
      if (jsData == null || jsData.isUndefined) return null;

      final data = <String, dynamic>{
        'id': (jsData['id'] as JSString?)?.toDart,
        'title': (jsData['title'] as JSString?)?.toDart,
        'description': (jsData['description'] as JSString?)?.toDart,
        'thumbnail': (jsData['thumbnail'] as JSString?)?.toDart,
        'duration': (jsData['duration'] as JSNumber?)?.toDartInt,
        'uploadDate': (jsData['uploadDate'] as JSString?)?.toDart,
        'creatorId': (jsData['creatorId'] as JSString?)?.toDart,
        'creatorName': (jsData['creatorName'] as JSString?)?.toDart,
        'channelId': (jsData['channelId'] as JSString?)?.toDart,
        'category': (jsData['category'] as JSString?)?.toDart,
        'tags': (jsData['tags'] as JSArray?)?.toDart.whereType<JSString>().map((e) => e.toDart).toList(),
        'viewCount': (jsData['viewCount'] as JSNumber?)?.toDartInt,
        'rating': (jsData['rating'] as JSNumber?)?.toDartDouble,
        'ratingCount': (jsData['ratingCount'] as JSNumber?)?.toDartInt,
        'videoUrl': (jsData['videoUrl'] as JSString?)?.toDart,
        'hlsUrl': (jsData['hlsUrl'] as JSString?)?.toDart,
        'dashUrl': (jsData['dashUrl'] as JSString?)?.toDart,
        'slug': (jsData['slug'] as JSString?)?.toDart,
      };
      return data;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.getInjectedData');
      return null;
    }
  }

  static dynamic getInjectedField(String field) {
    try {
      if (!globalContext.has('__VIDEO_DATA__')) return null;
      final jsData = globalContext['__VIDEO_DATA__'] as JSObject?;
      if (jsData == null || jsData.isUndefined) return null;
      return jsData[field];
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.getInjectedField');
      return null;
    }
  }

  static void clearInjectedData() {
    try {
      globalContext['__VIDEO_DATA__'] = null;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.clearInjectedData');
    }
  }

  static void removeInjectedData() {
    try {
      globalContext.delete('__VIDEO_DATA__'.toJS);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.removeInjectedData');
    }
  }

  static bool isPipSupported() {
    try {
      final doc = web.document as JSObject;
      return doc.has('pictureInPictureEnabled') &&
          (doc['pictureInPictureEnabled'] as JSBoolean?)?.toDart == true;
    } catch (_) {
      return false;
    }
  }

  static bool isDocumentInPip() {
    try {
      final doc = web.document as JSObject;
      return doc.has('pictureInPictureElement') &&
          doc['pictureInPictureElement'] != null;
    } catch (_) {
      return false;
    }
  }

  static bool enterPip() {
    try {
      final video = web.document.querySelector('video') as web.HTMLVideoElement?;
      if (video == null) return false;
      final doc = web.document as JSObject;
      if (!doc.has('pictureInPictureElement') || doc['pictureInPictureElement'] == null) {
        (video as JSObject).callMethod('requestPictureInPicture'.toJS);
        return true;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.enterPip');
    }
    return false;
  }

  static bool exitPip() {
    try {
      final doc = web.document as JSObject;
      if (doc.has('pictureInPictureElement') && doc['pictureInPictureElement'] != null) {
        doc.callMethod('exitPictureInPicture'.toJS);
        return true;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.exitPip');
    }
    return false;
  }

  static void ensureRecaptchaContainer() {
    try {
      final existing = web.document.getElementById('recaptcha-container');
      if (existing == null) {
        final container = web.document.createElement('div') as web.HTMLDivElement;
        container.id = 'recaptcha-container';
        container.style.cssText =
            'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);z-index:2147483647;pointer-events:none;';
        web.document.body?.appendChild(container);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebPlatformUtils.ensureRecaptchaContainer');
    }
  }

  static WebAudioPlayerAdapter createAudioPlayer() => _WebAudioPlayer();
}

class _WebAudioPlayer implements WebAudioPlayerAdapter {
  web.HTMLAudioElement? _audioElement;
  web.MediaSession? _mediaSession;
  double? _pendingSeekSeconds;

  void _safePlay() {
    if (_audioElement == null) return;
    try {
      final promise = _audioElement!.play();
      promise.toDart.catchError((Object? err) {
        // Suppress transient AbortError / NotAllowedError
        return null;
      });
    } catch (_) {}
  }

  @override
  void init({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function() onEnded,
    required void Function() onWaiting,
    required void Function() onCanPlay,
    required void Function(String err) onError,
    required void Function(double dur) onDurationChange,
    bool useCors = true,
  }) {
    try {
      final el = web.document.createElement('audio') as web.HTMLAudioElement
        ..preload = 'auto';
      if (useCors) {
        el.crossOrigin = 'anonymous';
      }
      _audioElement = el;

      _audioElement!.onplay = ((web.Event _) => onPlay()).toJS;
      _audioElement!.onpause = ((web.Event _) => onPause()).toJS;
      _audioElement!.onended = ((web.Event _) => onEnded()).toJS;
      _audioElement!.onwaiting = ((web.Event _) => onWaiting()).toJS;
      _audioElement!.oncanplay = ((web.Event _) {
        if (_pendingSeekSeconds != null && _audioElement != null) {
          _audioElement!.currentTime = _pendingSeekSeconds!;
          _pendingSeekSeconds = null;
        }
        onCanPlay();
      }).toJS;
      _audioElement!.onerror = ((web.Event e) {
        onError('Unable to play audio. Please check your connection and try again.');
      }).toJS;
      _audioElement!.ondurationchange = ((web.Event _) {
        onDurationChange(_audioElement?.duration ?? 0.0);
      }).toJS;

      web.document.body?.append(_audioElement!);
      _mediaSession = web.window.navigator.mediaSession;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebAudioPlayer.init');
    }
  }

  @override
  void load(String url, {double volume = 1.0, bool loop = false}) {
    if (_audioElement == null) return;
    _audioElement!.src = url;
    _audioElement!.volume = volume.clamp(0.0, 1.0);
    _audioElement!.loop = loop;
    _audioElement!.load();
  }

  @override
  void loadAndPlay(String url, {double volume = 1.0, bool loop = false}) {
    if (_audioElement == null) return;
    _audioElement!.src = url;
    _audioElement!.volume = volume.clamp(0.0, 1.0);
    _audioElement!.loop = loop;
    _safePlay();
  }

  @override
  void play() {
    _safePlay();
  }

  @override
  void pause() {
    try {
      _audioElement?.pause();
    } catch (_) {}
  }

  @override
  void stop() {
    if (_audioElement != null) {
      try {
        _audioElement!.pause();
        _audioElement!.currentTime = 0;
        _audioElement!.src = '';
        _audioElement!.load();
      } catch (_) {}
    }
  }

  @override
  void seek(double seconds) {
    if (_audioElement != null) {
      if (_audioElement!.readyState >= 1) {
        _audioElement!.currentTime = seconds;
        _pendingSeekSeconds = null;
      } else {
        _pendingSeekSeconds = seconds;
      }
    }
  }

  @override
  void setVolume(double volume) {
    if (_audioElement != null) {
      _audioElement!.volume = volume.clamp(0.0, 1.0);
    }
  }

  @override
  void setMuted(bool muted) {
    if (_audioElement != null) {
      _audioElement!.muted = muted;
    }
  }

  @override
  void setPlaybackRate(double rate) {
    if (_audioElement != null) {
      _audioElement!.playbackRate = rate.clamp(0.25, 4.0);
    }
  }

  @override
  bool get isPlaying {
    final el = _audioElement;
    if (el == null) return false;
    return !el.paused && !el.ended;
  }

  @override
  double get currentTime => _audioElement?.currentTime ?? 0.0;

  @override
  double get duration => _audioElement?.duration ?? 0.0;

  @override
  void dispose() {
    if (_audioElement != null) {
      _pendingSeekSeconds = null;
      try {
        _audioElement!.pause();
        _audioElement!.src = '';
        _audioElement!.remove();
      } catch (_) {}
      _audioElement = null;
    }
  }

  @override
  void setupMediaSession({
    required void Function() onPlay,
    required void Function() onPause,
    required void Function(double seconds) onSeekRelative,
    required void Function() onPreviousTrack,
    required void Function() onNextTrack,
  }) {
    try {
      if (_mediaSession == null) return;
      _mediaSession!.setActionHandler('play', ((JSAny? _) => onPlay()).toJS);
      _mediaSession!.setActionHandler('pause', ((JSAny? _) => onPause()).toJS);
      _mediaSession!.setActionHandler('seekbackward', ((JSAny? _) => onSeekRelative(-10)).toJS);
      _mediaSession!.setActionHandler('seekforward', ((JSAny? _) => onSeekRelative(10)).toJS);
      _mediaSession!.setActionHandler('previoustrack', ((JSAny? _) => onPreviousTrack()).toJS);
      _mediaSession!.setActionHandler('nexttrack', ((JSAny? _) => onNextTrack()).toJS);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebAudioPlayer.setupMediaSession');
    }
  }

  @override
  void updateMediaSessionMetadata({
    required String title,
    required String artworkUrl,
  }) {
    try {
      if (_mediaSession != null) {
        _mediaSession!.metadata = web.MediaMetadata(
          web.MediaMetadataInit(
            title: title,
            artist: 'Truthworld',
            album: '',
            artwork: [
              web.MediaImage(
                src: artworkUrl,
                sizes: '512x512',
                type: 'image/jpeg',
              ),
            ].toJS,
          ),
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebAudioPlayer.updateMediaSessionMetadata');
    }
  }

  @override
  void updateMediaSessionPositionState({
    required double duration,
    required double position,
    required double playbackRate,
  }) {
    try {
      if (_mediaSession != null && duration > 0) {
        _mediaSession!.setPositionState(
          web.MediaPositionState(
            duration: duration,
            playbackRate: playbackRate,
            position: position,
          ),
        );
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'WebAudioPlayer.updateMediaSessionPositionState');
    }
  }
}
