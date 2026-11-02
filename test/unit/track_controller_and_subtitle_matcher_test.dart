import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:haipee/pages/player/player_state.dart';
import 'package:haipee/modules/playback/subtitle_matcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerState Track & Subtitle Controller Fields', () {
    test('PlayerState defaults for track and subtitle controls', () {
      const state = PlayerState();
      expect(state.playerTracks, isNull);
      expect(state.currentAudioTrack, isNull);
      expect(state.currentSubtitleTrack, isNull);
      expect(state.subtitleDelay, equals(0.0));
      expect(state.aniSkipIntervals, isEmpty);
      expect(state.currentAniSkipInterval, isNull);
      expect(state.autoSkipOpEd, isFalse);
    });

    test('PlayerState copyWith correctly modifies and clears tracks', () {
      const state = PlayerState();

      const audio = AudioTrack('aid1', 'Japanese', 'ja');
      const sub = SubtitleTrack('sid1', 'Chinese', 'zh');
      const tracks = Tracks(
        video: [VideoTrack('vid1', 'Main', null)],
        audio: [audio],
        subtitle: [sub],
      );

      final updated = state.copyWith(
        playerTracks: tracks,
        currentAudioTrack: audio,
        currentSubtitleTrack: sub,
        subtitleDelay: 1.5,
        autoSkipOpEd: true,
      );

      expect(updated.playerTracks, equals(tracks));
      expect(updated.currentAudioTrack, equals(audio));
      expect(updated.currentSubtitleTrack, equals(sub));
      expect(updated.subtitleDelay, equals(1.5));
      expect(updated.autoSkipOpEd, isTrue);

      // Clearing tracks with null
      final cleared = updated.copyWith(
        currentAudioTrack: null,
        currentSubtitleTrack: null,
        subtitleDelay: 0.0,
      );
      expect(cleared.currentAudioTrack, isNull);
      expect(cleared.currentSubtitleTrack, isNull);
      expect(cleared.subtitleDelay, equals(0.0));
    });
  });

  group('SubtitleMatcher Tests', () {
    late SubtitleMatcher matcher;

    setUp(() {
      matcher = SubtitleMatcher();
    });

    test('selectBestMatch scores language preference over lower ranked languages', () {
      const candidates = [
        SubtitleMatch(url: '/subs/en.srt', language: 'en-US', confidence: 0.8, format: 'srt'),
        SubtitleMatch(url: '/subs/zh.ass', language: 'zh-CN', confidence: 0.8, format: 'ass'),
        SubtitleMatch(url: '/subs/fr.srt', language: 'fr-FR', confidence: 0.9, format: 'srt'),
      ];

      // Default preferred: ['zh-CN', 'en-US'], preferred formats: ['ass', 'srt']
      final best = matcher.selectBestMatch(candidates);
      expect(best, isNotNull);
      expect(best!.language, equals('zh-CN'));
      expect(best.format, equals('ass'));
      expect(best.url, equals('/subs/zh.ass'));
    });

    test('extractFormat correctly extracts extensions', () {
      expect(SubtitleMatcher.extractFormat('movie.ass'), equals('ass'));
      expect(SubtitleMatcher.extractFormat('subtitles/chinese.srt'), equals('srt'));
      expect(SubtitleMatcher.extractFormat('https://example.com/sub.vtt'), equals('vtt'));
      expect(SubtitleMatcher.extractFormat('movie_without_extension'), isNull);
    });

    test('validateSubtitleFile checks physical existence and non-zero length', () async {
      final tempDir = Directory.systemTemp.createTempSync('sub_test_');
      try {
        final validFile = File('${tempDir.path}/test.srt');
        validFile.writeAsStringSync('1\n00:00:01,000 --> 00:00:03,000\nHello');

        final emptyFile = File('${tempDir.path}/empty.srt');
        emptyFile.writeAsStringSync('');

        expect(await SubtitleMatcher.validateSubtitleFile(validFile.path), isTrue);
        expect(await SubtitleMatcher.validateSubtitleFile(emptyFile.path), isFalse);
        expect(await SubtitleMatcher.validateSubtitleFile('${tempDir.path}/non_existent.srt'), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('fromApiResponse converts raw API records into SubtitleMatch instances', () {
      final raw = [
        {
          'url': 'https://subs.org/1.ass',
          'language': 'zh-CN',
          'confidence': 0.95,
          'source': 'zimuku',
        },
        {
          'url': 'https://subs.org/2.srt',
          'language': 'en-US',
          'confidence': 0.70,
          'source': 'opensubtitles',
        },
      ];

      final matches = SubtitleMatcher.fromApiResponse(raw);
      expect(matches.length, equals(2));
      expect(matches[0].format, equals('ass'));
      expect(matches[0].language, equals('zh-CN'));
      expect(matches[0].confidence, equals(0.95));
      expect(matches[1].format, equals('srt'));
      expect(matches[1].language, equals('en-US'));
    });
  });
}
