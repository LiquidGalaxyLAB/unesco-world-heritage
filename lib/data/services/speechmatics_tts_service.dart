import 'dart:async';
import 'dart:convert';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Streams 16 kHz PCM from Speechmatics directly to the device audio output.
class SpeechmaticsTtsService {
  SpeechmaticsTtsService({http.Client? client, this.onPlaybackComplete})
    : _client = client ?? http.Client();

  static const _endpoint = 'https://preview.tts.speechmatics.com/generate';
  static const _sampleRate = 16000;

  final http.Client _client;
  final void Function()? onPlaybackComplete;
  Future<void> _feedQueue = Future<void>.value();
  StreamSubscription<List<int>>? _audioSubscription;
  bool _isAudioOutputReady = false;
  int? _pendingByte;
  int _totalSamples = 0;
  DateTime? _playbackStartedAt;
  Timer? _playbackCompleteTimer;

  Future<void> speak(String text, {String voice = 'megan'}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    await stop();
    final request =
        http.Request(
            'POST',
            Uri.parse('$_endpoint/$voice?output_format=pcm_16000'),
          )
          ..headers.addAll(await _headers())
          ..body = jsonEncode(<String, String>{'text': trimmedText});
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw SpeechmaticsTtsException(response.statusCode, body);
    }

    await _ensureAudioOutput();
    _pendingByte = null;
    _totalSamples = 0;
    _playbackStartedAt = null;
    _audioSubscription = response.stream.listen(
      _queuePcmChunk,
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_finishPlayback());
      },
      onDone: () => unawaited(_finishPlayback()),
      cancelOnError: true,
    );
  }

  Future<Map<String, String>> _headers() async {
    final apiKey = dotenv.env['SPEECHMATICS_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw StateError(
        'Speechmatics API key is not set. Add it in API Authentication.',
      );
    }

    return <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  Future<void> _ensureAudioOutput() async {
    if (_isAudioOutputReady) return;
    await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: 1);
    FlutterPcmSound.start();
    _isAudioOutputReady = true;
  }

  void _queuePcmChunk(List<int> chunk) {
    _feedQueue = _feedQueue.then((_) async {
      final samples = <int>[];
      var index = 0;

      final pendingByte = _pendingByte;
      if (pendingByte != null && chunk.isNotEmpty) {
        samples.add(_toSignedPcm16(pendingByte, chunk.first));
        index = 1;
        _pendingByte = null;
      }

      while (index + 1 < chunk.length) {
        samples.add(_toSignedPcm16(chunk[index], chunk[index + 1]));
        index += 2;
      }
      if (index < chunk.length) _pendingByte = chunk[index];

      if (samples.isNotEmpty) {
        _playbackStartedAt ??= DateTime.now();
        _totalSamples += samples.length;
        await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
      }
    });
  }

  int _toSignedPcm16(int lowByte, int highByte) {
    final value = lowByte | (highByte << 8);
    return value >= 0x8000 ? value - 0x10000 : value;
  }

  Future<void> _finishPlayback() async {
    await _feedQueue;
    final startedAt = _playbackStartedAt;
    if (startedAt == null) {
      onPlaybackComplete?.call();
      return;
    }

    final totalDuration = Duration(
      milliseconds: (_totalSamples * 1000 / _sampleRate).ceil(),
    );
    final remaining = totalDuration - DateTime.now().difference(startedAt);
    _playbackCompleteTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => onPlaybackComplete?.call(),
    );
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _pendingByte = null;
    _playbackCompleteTimer?.cancel();
    if (_isAudioOutputReady) {
      await FlutterPcmSound.release();
      _isAudioOutputReady = false;
    }
  }

  Future<void> dispose() async {
    await stop();
    _client.close();
  }
}

class SpeechmaticsTtsException implements Exception {
  const SpeechmaticsTtsException(this.statusCode, this.responseBody);

  final int statusCode;
  final String responseBody;

  @override
  String toString() =>
      'Speechmatics TTS request failed ($statusCode): $responseBody';
}
