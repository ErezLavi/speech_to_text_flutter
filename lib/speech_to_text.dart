import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechSampleApp extends StatefulWidget {
  const SpeechSampleApp({super.key});

  @override
  State<SpeechSampleApp> createState() => _SpeechSampleAppState();
}

class _SpeechSampleAppState extends State<SpeechSampleApp> {
  final SpeechToText _speech = SpeechToText();
  static const String _placeholderText = 'Press "Enable & Start" and speak';

  bool _ready = false;
  bool _initializing = false;
  bool _starting = false;
  double _soundLevel = 0;
  String _words = _placeholderText;
  String _status = 'idle';
  String _error = '';
  String _localeId = '';
  List<LocaleName> _localeNames = [];
  String _committedWords = '';
  String _sessionWords = '';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      Future<void>.microtask(_initSpeech);
    }
  }

  Future<bool> _initSpeech() async {
    if (_ready) return true;
    if (_initializing) return false;
    _initializing = true;
    setState(() {
      _error = '';
      _status = 'initializing';
    });
    const configOptions = <SpeechConfigOption>[];
    try {
      final ready = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
        options: configOptions,
      );
      if (ready) {
        _localeNames = await _speech.locales();
      }
      final locale = ready ? await _speech.systemLocale() : null;
      if (!mounted) return false;
      setState(() {
        _ready = ready;
        _localeId = _resolveLocale(locale?.localeId);
        if (!ready) {
          _error = kIsWeb
              ? 'Web speech is unavailable. Use Chrome/Edge, allow microphone, and run from localhost or HTTPS.'
              : 'Speech recognition is unavailable on this device.';
        }
      });
      return ready;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _ready = false;
        _error = 'Initialization failed: $e';
      });
      return false;
    } finally {
      _initializing = false;
      if (mounted && _status == 'initializing') {
        setState(() {
          _status = _ready ? 'ready' : 'failed';
        });
      }
    }
  }

  String _resolveLocale(String? candidate) {
    if (candidate == null || candidate.isEmpty || _localeNames.isEmpty) {
      return '';
    }
    for (final locale in _localeNames) {
      if (locale.localeId == candidate) {
        return candidate;
      }
    }
    return '';
  }

  Future<void> _start() async {
    if (_starting || _initializing) return;
    _starting = true;
    _commitSessionWords();
    final ready = await _initSpeech();
    if (!ready || !_ready) {
      _starting = false;
      return;
    }
    setState(() {
      _error = '';
      _status = 'starting';
    });

    try {
      await _speech.cancel();
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 4),
        localeId: _localeId.isEmpty ? null : _localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to start listening: $e';
      });
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {});
  }

  void _onSoundLevel(double level) {
    if (!mounted) return;
    setState(() {
      _soundLevel = level;
    });
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      final incoming = result.recognizedWords.trim();
      _sessionWords = incoming;
      _words = _buildDisplayWords();
      if (result.finalResult) {
        _commitSessionWords();
      }
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (status == 'done' ||
          status == 'notListening' ||
          status == 'doneNoResult') {
        _soundLevel = 0;
        _commitSessionWords();
      }
    });
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _error = '${error.errorMsg} (permanent: ${error.permanent})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E8A7D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE7F6F4), Color(0xFFF8FAFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Speech To Text',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _pill('Ready', _ready ? 'Yes' : 'No'),
                              _pill('Status', _status),
                              _pill(
                                'Locale',
                                _localeId.isEmpty
                                    ? 'system default'
                                    : _localeId,
                              ),
                              if (_status == 'done' &&
                                  _committedWords.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: FilledButton.tonalIcon(
                                    onPressed: _clearTranscript,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Reset'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F9F8),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFD8E5E2)),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _words,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    height: 1.32,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_error.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3F3),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFF0C8C8)),
                              ),
                              child: Text(
                                _error,
                                style:
                                    const TextStyle(color: Color(0xFFB63939)),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Center(
                            child: AvatarGlow(
                              glowColor: const Color(0xFF0E8A7D),
                              animate: _speech.isListening,
                              duration: const Duration(milliseconds: 1800),
                              repeat: true,
                              child: FloatingActionButton.large(
                                heroTag: 'micButton',
                                backgroundColor: _speech.isListening
                                    ? const Color(0xFFC84E42)
                                    : const Color(0xFF0E8A7D),
                                onPressed: _speech.isListening ? _stop : _start,
                                child: Icon(
                                  _speech.isListening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  size: 38,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _speech.isListening
                                  ? 'Listening...'
                                  : 'Tap to start',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (_soundLevel.abs() / 35).clamp(0.0, 1.0),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: const Color(0xFFDCE8E5),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0E8A7D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE8E5)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF35514C),
          fontSize: 13,
        ),
      ),
    );
  }

  String _buildDisplayWords() {
    final committed = _committedWords.trim();
    final live = _sessionWords.trim();
    if (committed.isEmpty && live.isEmpty) return _placeholderText;
    if (committed.isEmpty) return live;
    if (live.isEmpty) return committed;
    return '$committed $live';
  }

  void _commitSessionWords() {
    final session = _sessionWords.trim();
    if (session.isEmpty) {
      _words = _buildDisplayWords();
      return;
    }

    if (_committedWords.isEmpty) {
      _committedWords = session;
    } else if (!_endsWithNormalized(_committedWords, session)) {
      _committedWords = '$_committedWords $session';
    }

    _sessionWords = '';
    _words = _buildDisplayWords();
  }

  bool _endsWithNormalized(String base, String suffix) {
    final normalizedBase = _normalizeText(base);
    final normalizedSuffix = _normalizeText(suffix);
    if (normalizedSuffix.isEmpty) return true;
    return normalizedBase.endsWith(normalizedSuffix);
  }

  String _normalizeText(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _clearTranscript() {
    setState(() {
      _committedWords = '';
      _sessionWords = '';
      _words = _placeholderText;
      _error = '';
    });
  }
}
