import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:voice_bill/services/gemini_service.dart';
import 'package:voice_bill/services/local_parser_service.dart';

enum STTState {
  idle,
  listening,
  processing,
  error,
}

class VoiceController {
  final GeminiService _gemini = GeminiService();
  final LocalParserService _localParser = LocalParserService();
  final Connectivity _connectivity = Connectivity();

  stt.SpeechToText? _localSTT;

  STTState _state = STTState.idle;
  STTState get state => _state;

  bool _isListening = false;
  bool get isListening => _isListening;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  VoidCallback? onStateChanged;

  String? _lastError;
  String? get lastError => _lastError;

  /// Chữ nghe được tạm thời (partial) trong lúc đang nói — để overlay hiện
  /// trực tiếp, giúp người dùng biết máy đang nghe đúng.
  String _partialWords = '';
  String get partialWords => _partialWords;

  VoiceController() {
    // speech_to_text hỗ trợ cả web (qua package:web) lẫn mobile, nên dùng
    // chung một đường — bỏ WebSpeechService thủ công bằng dart:html (vốn bóc
    // transcript không đáng tin và phá build mobile).
    _localSTT = stt.SpeechToText();
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivity.checkConnectivity().then((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      onStateChanged?.call();
    });
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = !result.contains(ConnectivityResult.none);
      onStateChanged?.call();
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _localSTT?.stop();
  }

  void _setState(STTState newState, {bool? listening}) {
    _state = newState;
    if (listening != null) _isListening = listening;
    onStateChanged?.call();
  }

  Future<void> startListening({
    required void Function(String text) onResult,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _lastError = null;
    _partialWords = '';
    _setState(STTState.listening, listening: true);
    await Future.delayed(const Duration(milliseconds: 200));

    if (_localSTT != null) {
      await _startLocalListening(onResult: onResult, timeout: timeout);
    } else {
      _lastError = 'Không tìm thấy phương thức nhận dạng giọng nói';
      _setState(STTState.error, listening: false);
    }
  }

  Future<void> _startLocalListening({
    required void Function(String text) onResult,
    required Duration timeout,
  }) async {
    final completer = Completer<void>();
    Timer? timeoutTimer;
    var lastWords = '';

    // Chốt kết quả: gom được chữ thì trả về, không thì báo "không nghe thấy".
    // Không phụ thuộc cờ finalResult (tiếng Việt nhiều khi không bật cờ này).
    void deliver() {
      if (completer.isCompleted) return;
      timeoutTimer?.cancel();
      final text = lastWords.trim();
      if (text.isNotEmpty) {
        _setState(STTState.processing, listening: false);
        onResult(text);
      } else {
        _lastError = 'Không nghe thấy giọng nói. Hãy nói to và rõ hơn.';
        _setState(STTState.error, listening: false);
      }
      completer.complete();
    }

    try {
      final ok = await _localSTT!.initialize(
        onError: (error) {
          if (completer.isCompleted) return;
          // Đã gom được chữ mà gặp no-match -> coi như nghe xong.
          if (lastWords.trim().isNotEmpty) {
            deliver();
            return;
          }
          timeoutTimer?.cancel();
          _lastError = _mapSttError(error.errorMsg);
          _setState(STTState.error, listening: false);
          completer.complete();
        },
        onStatus: (status) {
          // 'done'/'notListening' = phiên nghe kết thúc -> chốt kết quả đã gom.
          if ((status == 'done' || status == 'notListening') &&
              !completer.isCompleted) {
            deliver();
          }
        },
      );
      if (!ok) {
        _lastError =
            'Không khởi tạo được micro. Hãy kiểm tra/cho phép quyền Microphone.';
        _setState(STTState.error, listening: false);
        return;
      }

      timeoutTimer = Timer(timeout, () {
        if (completer.isCompleted) return;
        _localSTT!.stop(); // -> kích hoạt status 'done' -> deliver()
      });

      await _localSTT!.listen(
        listenOptions: stt.SpeechListenOptions(
          // Web set lang = localeId trực tiếp nên phải dùng 'vi-VN'.
          localeId: kIsWeb ? 'vi-VN' : 'vi_VN',
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          // Người lớn tuổi hay ngắt quãng khi nói — cho 4s im lặng mới chốt.
          pauseFor: const Duration(seconds: 4),
        ),
        onResult: (result) {
          // Gom văn bản từ mọi kết quả (kể cả tạm thời) và đẩy ra ngoài để
          // overlay hiện chữ trực tiếp khi người dùng đang nói.
          if (result.recognizedWords.isNotEmpty) {
            lastWords = result.recognizedWords;
            _partialWords = result.recognizedWords;
            onStateChanged?.call();
          }
          if (result.finalResult && !completer.isCompleted) {
            deliver();
          }
        },
      );

      await completer.future;
    } catch (e) {
      if (!completer.isCompleted) {
        _lastError = 'Lỗi micro: $e';
        _setState(STTState.error, listening: false);
      }
    } finally {
      timeoutTimer?.cancel();
    }
  }

  String _mapSttError(String code) {
    final c = code.toLowerCase();
    if (c.contains('denied') ||
        c.contains('not-allowed') ||
        c.contains('not_allowed') ||
        c.contains('permission')) {
      return 'Micro đang bị chặn. Hãy cấp quyền Microphone cho trình duyệt/ứng dụng rồi thử lại.';
    }
    if (c.contains('no-speech') ||
        c.contains('no_match') ||
        c.contains('nomatch') ||
        c.contains('speech_timeout')) {
      return 'Không nghe thấy giọng nói. Hãy nói to và rõ hơn.';
    }
    if (c.contains('audio')) {
      return 'Không truy cập được micro. Kiểm tra thiết bị micro.';
    }
    if (c.contains('network')) {
      return 'Mất kết nối mạng (nhận giọng nói cần Internet).';
    }
    return 'Lỗi micro ($code), thử lại.';
  }

  void stopListening() {
    _localSTT?.stop();
    _isListening = false;
    _state = STTState.idle;
    onStateChanged?.call();
  }

  List<Map<String, dynamic>> parseSaleText(String text) {
    return _localParser.parseSaleItems(text);
  }

  Future<List<Map<String, dynamic>>> parseSaleTextAsync(
    String text, {
    List<Map<String, dynamic>> products = const [],
  }) async {
    if (_isOnline) {
      try {
        final result = await _gemini.parseSaleItems(text, products: products);
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return _localParser.parseSaleItems(text);
  }

  List<Map<String, dynamic>> parseStockText(String text) {
    return _localParser.parseStockItems(text);
  }

  Future<List<Map<String, dynamic>>> parseStockTextAsync(
    String text, {
    List<Map<String, dynamic>> products = const [],
  }) async {
    if (_isOnline) {
      try {
        final result = await _gemini.parseStockItems(text, products: products);
        if (result.isNotEmpty) return result;
      } catch (_) {}
    }
    return _localParser.parseStockItems(text);
  }
}
