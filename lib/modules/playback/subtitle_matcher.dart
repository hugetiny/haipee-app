import 'dart:io';
import 'package:dio/dio.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

/// Represents a matched subtitle file with its metadata.
class SubtitleMatch {
  const SubtitleMatch({
    required this.url,
    required this.language,
    required this.confidence,
    this.format,
    this.source,
  });

  final String url;
  final String language;
  final double confidence;
  final String? format;
  final String? source;

  @override
  String toString() =>
      'SubtitleMatch(url: $url, language: $language, confidence: $confidence)';
}

/// Heuristic-based subtitle matcher that finds the best subtitle match
/// for a given video based on language, format, and metadata.
class SubtitleMatcher {
  SubtitleMatcher({
    Dio? httpClient,
  }) : _dio = httpClient ?? Dio();

  final Dio _dio;
  final HaipeeLogger _logger = HaipeeLogger();

  /// Finds the best matching subtitle from a list of candidates based on
  /// user preferences and confidence scoring.
  SubtitleMatch? selectBestMatch(
    List<SubtitleMatch> candidates, {
    List<String> preferredLanguages = const <String>['zh-CN', 'en-US'],
    List<String> preferredFormats = const <String>['ass', 'srt', 'vtt'],
  }) {
    if (candidates.isEmpty) {
      return null;
    }

    SubtitleMatch? bestMatch;
    double highestScore = 0.0;

    for (final SubtitleMatch candidate in candidates) {
      double score = candidate.confidence;

      // Language preference scoring
      final int langIndex = preferredLanguages.indexOf(candidate.language);
      if (langIndex >= 0) {
        score += (preferredLanguages.length - langIndex) * 0.2;
      }

      // Format preference scoring
      if (candidate.format != null) {
        final int formatIndex = preferredFormats.indexOf(candidate.format!);
        if (formatIndex >= 0) {
          score += (preferredFormats.length - formatIndex) * 0.1;
        }
      }

      if (score > highestScore) {
        highestScore = score;
        bestMatch = candidate;
      }
    }

    if (bestMatch != null) {
      _logger.log(
        Level.info,
        '[SubtitleMatcher] Selected best match: ${bestMatch.language} '
        '(confidence: ${bestMatch.confidence}, score: $highestScore)',
      );
    }

    return bestMatch;
  }

  /// Downloads a subtitle file from the given URL to the specified path.
  Future<File?> downloadSubtitle(
    String url,
    String savePath, {
    Map<String, String>? headers,
  }) async {
    try {
      _logger.log(
        Level.info,
        '[SubtitleMatcher] Downloading subtitle from $url',
      );

      final Response<List<int>> response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          followRedirects: true,
        ),
      );

      if (response.data == null || response.data!.isEmpty) {
        _logger.log(
          Level.warning,
          '[SubtitleMatcher] Empty subtitle response from $url',
        );
        return null;
      }

      final File file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.data!);

      _logger.log(
        Level.info,
        '[SubtitleMatcher] Subtitle saved to $savePath',
      );

      return file;
    } on DioException catch (error, stackTrace) {
      _logger.log(
        Level.error,
        '[SubtitleMatcher] Failed to download subtitle: ${error.message}',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      _logger.log(
        Level.error,
        '[SubtitleMatcher] Unexpected error downloading subtitle: $error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Extracts subtitle format from URL or filename.
  static String? extractFormat(String urlOrPath) {
    final String extension = path.extension(urlOrPath).toLowerCase();
    if (extension.isEmpty) {
      return null;
    }
    // Remove leading dot
    return extension.substring(1);
  }

  /// Creates a list of subtitle matches from raw API data.
  /// This is a helper for integrating with external subtitle APIs.
  static List<SubtitleMatch> fromApiResponse(
    List<Map<String, dynamic>> apiData, {
    String Function(Map<String, dynamic>)? urlExtractor,
    String Function(Map<String, dynamic>)? languageExtractor,
    double Function(Map<String, dynamic>)? confidenceExtractor,
  }) {
    final List<SubtitleMatch> matches = <SubtitleMatch>[];

    for (final Map<String, dynamic> entry in apiData) {
      try {
        final String? url =
            urlExtractor?.call(entry) ?? entry['url'] as String?;
        final String? language =
            languageExtractor?.call(entry) ?? entry['language'] as String?;
        final double confidence = confidenceExtractor?.call(entry) ??
            (entry['confidence'] as num?)?.toDouble() ??
            0.5;

        if (url != null && language != null) {
          matches.add(
            SubtitleMatch(
              url: url,
              language: language,
              confidence: confidence,
              format: extractFormat(url),
              source: entry['source'] as String?,
            ),
          );
        }
      } catch (error) {
        HaipeeLogger().log(
          Level.warning,
          '[SubtitleMatcher] Failed to parse subtitle entry: $error',
        );
      }
    }

    return matches;
  }

  /// Validates if a subtitle file exists and is readable.
  static Future<bool> validateSubtitleFile(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final int size = await file.length();
      return size > 0;
    } catch (_) {
      return false;
    }
  }
}
