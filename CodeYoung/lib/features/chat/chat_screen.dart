import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/repositories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/common.dart';

/// AI Mentor tab — real-time Q&A backed by live internet search, with voice
/// input (speech-to-text) and spoken replies (text-to-speech from Python).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  late final stt.SpeechToText _speech;
  final _player = AudioPlayer();

  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _sending = false;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _speaking = false;
  bool _autoSpeak = true;
  StreamSubscription? _playerSub;

  static const _suggestions = [
    'What is Codeyoung?',
    'How do I book a free trial?',
    'Explain Python loops simply',
    'What is a website made of?',
    'How do line-following robots work?',
    'Explain fractions like I am 8',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _speaking = false);
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (s) {
          if (mounted && (s == 'done' || s == 'notListening')) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }

    // Restore any prior conversation so the tab feels continuous.
    try {
      final api = ref.read(apiServiceProvider);
      final history = await api.getList('/api/chat/history');
      if (history.isNotEmpty && mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(history.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return ChatMessage(
                role: '${m['role'] ?? 'assistant'}',
                content: '${m['content'] ?? ''}',
                source: m['source'] as String?,
              );
            }));
        });
        _scrollToEnd();
      }
    } catch (_) {
      // Offline / no session yet — start fresh.
    }

    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content:
              "Hi! I'm your CodeYoung mentor. Ask me anything about our courses, the free trial, 1:1 mentors — or any coding, maths or science question. I search the live internet and can read every answer aloud.",
          source: 'codeyoung',
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    _playerSub?.cancel();
    _player.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 140,
        duration: 300.ms,
        curve: Curves.easeOut,
      );
    });
  }

  /* -------------------------------------------------------------- send --- */

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    _input.clear();
    _focus.unfocus();

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _scrollToEnd();

    try {
      final reply = await sendChat(
        ref,
        message: text,
        history: _messages,
        speak: _autoSpeak,
        sessionId: _sessionId,
      );
      setState(() {
        _sessionId ??= 'app';
        _messages.add(reply);
        _sending = false;
      });
      _scrollToEnd();
      // Prefer the audio the reply already carried — asking /tts again for the
      // same text used to synthesise it twice and delay speech by seconds.
      if (_autoSpeak) _play(reply.audioBase64, reply.content);
    } on ApiException catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: e.message,
          error: e.message,
          timestamp: DateTime.now(),
        ));
        _sending = false;
      });
      _scrollToEnd();
    } catch (_) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content:
              'I could not reach the mentor service. Please check that the backend (port 3000) and the Python mentor (port 5001) are running, then try again.',
          error: 'offline',
          timestamp: DateTime.now(),
        ));
        _sending = false;
      });
      _scrollToEnd();
    }
  }

  /* -------------------------------------------------------------- voice --- */

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    if (!_speechAvailable) {
      showAppSnackBar(
        context,
        'Voice input is not available on this device. You can still type your question.',
        error: true,
      );
      return;
    }

    await _stopSpeaking();
    setState(() => _listening = true);

    final locales = await _speech.locales();
    final localeId = locales
        .firstWhere(
          (l) => l.localeId.startsWith('en'),
          orElse: () => locales.isNotEmpty
              ? locales.first
              : stt.LocaleName('en', 'English'),
        )
        .localeId;

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _input.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          if (result.recognizedWords.trim().isNotEmpty) _send();
        }
      },
    );
  }

  /// Speaks [text], reusing [preloaded] (base64 mp3) when the reply already
  /// brought audio back. Only falls back to a network TTS call when needed.
  Future<void> _play(String? preloaded, String text) async {
    try {
      // Stop any current playback first.
      await _player.stop();
      if (mounted) setState(() => _speaking = true);

      String? audio = preloaded;
      if (audio == null || audio.isEmpty) {
        final api = ref.read(apiServiceProvider);
        final json = await api.postJson('/api/chat/tts', {'text': text, 'lang': 'en'});
        final a = json['audio'];
        audio = a is String && a.isNotEmpty ? a : null;
      }
      if (audio == null) {
        if (mounted) setState(() => _speaking = false);
        return;
      }

      await _player.setSource(BytesSource(base64Decode(audio)));
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.resume();
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _speak(String text) => _play(null, text);

  Future<void> _stopSpeaking() async {
    await _player.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _clear() async {
    setState(() => _messages.clear());
    try {
      final api = ref.read(apiServiceProvider);
      await api.delete('/api/chat/history');
    } catch (_) {
      // Local clear is enough.
    }
    _bootstrap();
  }

  /* --------------------------------------------------------------- UI ---- */

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppHeader(
        actions: [
          IconButton(
            tooltip: _autoSpeak ? 'Voice replies on' : 'Voice replies off',
            onPressed: () => setState(() => _autoSpeak = !_autoSpeak),
            style: IconButton.styleFrom(
              backgroundColor: _autoSpeak
                  ? AppColors.accentPurple.withValues(alpha: isDark ? 0.30 : 0.14)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05)),
              foregroundColor: _autoSpeak
                  ? AppColors.accentPurple
                  : (isDark ? AppColors.textOnDark : AppColors.textSecondary),
            ),
            icon: Icon(
              _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _clear,
            style: IconButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.textOnDark : AppColors.textSecondary,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _Header(
              listening: _listening,
              speaking: _speaking,
              userName: user?.name,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _messages.length) {
                    return const _TypingBubble().animate().fadeIn(duration: 250.ms);
                  }
                  final m = _messages[i];
                  return _Bubble(
                    message: m,
                    isDark: isDark,
                    onRetry: m.error != null
                        ? () {
                            setState(() => _messages.removeAt(i));
                            _send(m.content);
                          }
                        : null,
                    onSpeak: m.isUser
                        ? null
                        : () {
                            if (_speaking) {
                              _stopSpeaking();
                            } else {
                              _speak(m.content);
                            }
                          },
                    speaking: _speaking && !m.isUser && i == _messages.length - 1,
                  );
                },
              ),
            ),
            if (_messages.isNotEmpty && _messages.length <= 3)
              _SuggestionStrip(
                suggestions: _suggestions,
                onPick: _send,
              ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              sending: _sending,
              listening: _listening,
              canSend: _input.text.trim().isNotEmpty,
              onSend: () => _send(),
              onMic: _toggleMic,
              onChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Header                                                                     */
/* -------------------------------------------------------------------------- */

class _Header extends StatelessWidget {
  const _Header({
    required this.listening,
    required this.speaking,
    required this.userName,
  });

  final bool listening;
  final bool speaking;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppGradients.grape,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 26),
                if (listening)
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).fadeOut(
                        duration: 700.ms,
                        curve: Curves.easeOut,
                      ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'CodeYoung Mentor',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    _OnlineDot(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  listening
                      ? 'Listening...'
                      : speaking
                          ? 'Speaking aloud...'
                          : 'Live internet answers${userName != null ? '' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: listening
                        ? AppColors.accentGreen
                        : speaking
                            ? AppColors.accentPurple
                            : (isDark
                                ? AppColors.textOnDark.withValues(alpha: 0.65)
                                : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.accentGreen,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Color(0x804CAF50), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Messages                                                                   */
/* -------------------------------------------------------------------------- */

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isDark,
    required this.onSpeak,
    required this.speaking,
    this.onRetry,
  });

  final ChatMessage message;
  final bool isDark;
  final VoidCallback? onSpeak;
  final VoidCallback? onRetry;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.error != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 9),
              decoration: BoxDecoration(
                gradient: isError ? AppGradients.sunset : AppGradients.grape,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.smart_toy_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryBlue
                        : (isError
                            ? AppColors.error.withValues(alpha: 0.10)
                            : (isDark ? AppColors.bgDarkCard : AppColors.bgWhite)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 20),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isError
                                ? AppColors.error.withValues(alpha: 0.35)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: isUser
                          ? Colors.white
                          : (isDark ? AppColors.textOnDark : AppColors.textPrimary),
                    ),
                  ),
                ),

                // Source / actions row
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!isUser && message.source != null)
                        _SourceChip(source: message.source!),
                      if (!isUser && message.sources.isNotEmpty)
                        ...message.sources.take(2).map(
                              (s) => _LinkChip(source: s),
                            ),
                      if (!isUser && onSpeak != null)
                        _MiniAction(
                          icon: speaking
                              ? Icons.stop_circle_rounded
                              : Icons.volume_up_rounded,
                          label: speaking ? 'Stop' : 'Listen',
                          color:
                              speaking ? AppColors.accentPink : AppColors.accentPurple,
                          onTap: onSpeak!,
                        ),
                      if (onRetry != null)
                        _MiniAction(
                          icon: Icons.refresh_rounded,
                          label: 'Retry',
                          color: AppColors.primaryBlue,
                          onTap: onRetry!,
                        ),
                      if (isUser)
                        Text(
                          _timeOf(message),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark
                                ? AppColors.textOnDark.withValues(alpha: 0.45)
                                : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 42),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 320.ms)
        .slide(begin: Offset(isUser ? 0.06 : -0.06, 0));
  }

  String _timeOf(ChatMessage m) {
    final t = m.timestamp;
    if (t == null) return '';
    final h = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'codeyoung' => ('Codeyoung', AppColors.primaryBlue),
      'codeyoung+web' => ('Codeyoung + Web', AppColors.accentGreen),
      'web' => ('Live web', AppColors.accentGreen),
      'curriculum' => ('Curriculum', AppColors.accentOrange),
      'offline' => ('Offline', AppColors.error),
      _ => ('Mentor', AppColors.primaryBlue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (source) {
              'web' || 'codeyoung+web' => Icons.public_rounded,
              'offline' => Icons.cloud_off_rounded,
              _ => Icons.school_rounded,
            },
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.source});

  final Map<String, dynamic> source;

  Future<void> _open() async {
    final url = '${source['url'] ?? ''}';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = '${source['title'] ?? 'Source'}';
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, size: 11, color: AppColors.accentCyan),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(
              gradient: AppGradients.grape,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgDarkCard : AppColors.bgWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 5),
                _dot(150),
                const SizedBox(width: 5),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delay) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: 500.ms,
          delay: delay.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.6, 0.6),
          duration: 500.ms,
          curve: Curves.easeInOut,
        );
  }
}

/* -------------------------------------------------------------------------- */
/* Suggestions                                                                */
/* -------------------------------------------------------------------------- */

class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, i) {
          final s = suggestions[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onPick(s),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.30)),
                ),
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slide(begin: const Offset(0, 0.4));
  }
}

/* -------------------------------------------------------------------------- */
/* Composer                                                                   */
/* -------------------------------------------------------------------------- */

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.listening,
    required this.canSend,
    required this.onSend,
    required this.onMic,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool listening;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSurface : AppColors.bgWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listening)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.accentGreen.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_rounded, size: 15, color: AppColors.accentGreen),
                    SizedBox(width: 7),
                    Text(
                      'Listening… speak now',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mic
                AnimatedContainer(
                  duration: 220.ms,
                  decoration: BoxDecoration(
                    color: listening
                        ? AppColors.accentGreen
                        : AppColors.primaryBlue.withValues(alpha: isDark ? 0.28 : 0.12),
                    shape: BoxShape.circle,
                    boxShadow: listening
                        ? [
                            BoxShadow(
                              color: AppColors.accentGreen.withValues(alpha: 0.5),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    onPressed: sending ? null : onMic,
                    tooltip: listening ? 'Stop listening' : 'Ask with your voice',
                    icon: Icon(
                      listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: listening ? Colors.white : AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.bgDarkCard : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: listening
                            ? AppColors.accentGreen.withValues(alpha: 0.5)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.07)),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => onChanged(),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Ask your mentor anything...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      ),
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send
                AnimatedContainer(
                  duration: 220.ms,
                  decoration: BoxDecoration(
                    gradient: canSend && !sending ? AppGradients.grape : null,
                    color: canSend && !sending
                        ? null
                        : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
                    shape: BoxShape.circle,
                    boxShadow: canSend && !sending
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8E2DE2).withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    onPressed: canSend && !sending ? onSend : null,
                    tooltip: 'Send',
                    icon: sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.primaryBlue,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend && !sending
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textOnDark.withValues(alpha: 0.4)
                                    : AppColors.textSecondary),
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
