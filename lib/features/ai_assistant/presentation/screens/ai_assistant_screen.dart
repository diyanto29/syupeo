import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/features/ai_assistant/controllers/ai_assistant_controller.dart';
import 'package:dpos/features/ai_assistant/domain/ai_message_model.dart';
import 'package:dpos/features/ai_assistant/presentation/widgets/ai_api_key_dialog.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;

  final List<String> _quickSuggestions = [
    '📦 Prediksi Stok Habis Kapan',
    '💡 Ide Bundling Promo Sore',
    '📊 Cek Laba Bersih Hari Ini',
    '💰 Total Pendapatan Hari Ini',
    '🏆 Produk Terlaris Hari Ini',
    '💵 Saldo Kas Laci Kasir',
    '❓ Panduan Buka & Tutup Shift',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _textController.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    _textController.clear();
    ref.read(aiAssistantControllerProvider.notifier).sendUserMessage(text);
    _scrollToBottom();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantControllerProvider);
    final controller = ref.read(aiAssistantControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    ref.listen<AiAssistantState>(aiAssistantControllerProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
      if (next.voiceErrorMessage != null &&
          next.voiceErrorMessage != prev?.voiceErrorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.voiceErrorMessage!),
            backgroundColor: scheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.indigo.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asisten AI Syupeo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Gemini AI • Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: state.isTtsEnabled
                ? 'Suara AI Aktif (Klik untuk Mute)'
                : 'Suara AI Mati (Klik untuk Nyalakan)',
            icon: Icon(
              state.isTtsEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: state.isTtsEnabled ? Colors.blue.shade700 : null,
            ),
            onPressed: () {
              ref.read(aiAssistantControllerProvider.notifier).toggleTts();
            },
          ),
          IconButton(
            tooltip: 'Hapus Percakapan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref
                  .read(aiAssistantControllerProvider.notifier)
                  .clearConversation();
            },
          ),
          IconButton(
            tooltip: 'Konfigurasi Gemini Key',
            icon: const Icon(Icons.key_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AiApiKeyDialog(
                  initialKey: state.apiKey ?? '',
                  onSave: (k) {
                    ref
                        .read(aiAssistantControllerProvider.notifier)
                        .saveApiKey(k);
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length && state.isLoading) {
                    return _buildTypingIndicator(theme, scheme);
                  }

                  final msg = state.messages[index];
                  return _buildMessageBubble(
                    msg,
                    theme,
                    scheme,
                    state,
                    controller,
                  );
                },
              ),
            ),

            // Quick Suggestions
            if (!state.isLoading && !state.isListening)
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = _quickSuggestions[index];
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      onPressed: () => _handleSend(suggestion),
                    );
                  },
                ),
              ),

            // Input Bar (Normal or WhatsApp-style Voice Recording)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: state.isListening
                  ? _buildVoiceRecordingBar(state, controller, scheme)
                  : _buildNormalInputBar(state, controller, scheme),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input Bar Normal ──────────────────────────────────────────────

  Widget _buildNormalInputBar(
    AiAssistantState state,
    AiAssistantController controller,
    ColorScheme scheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ketik atau gunakan suara...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                _handleSend();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        if (_hasText)
          IconButton.filled(
            onPressed: !state.isLoading ? () => _handleSend() : null,
            style: IconButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          )
        else
          IconButton.filled(
            tooltip: 'Bicara dengan Suara',
            onPressed: !state.isLoading
                ? () {
                    HapticFeedback.mediumImpact();
                    controller.startVoiceRecording();
                  }
                : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.mic_rounded, size: 22),
          ),
      ],
    );
  }

  // ── WhatsApp-style Voice Recording Bar ────────────────────────────

  Widget _buildVoiceRecordingBar(
    AiAssistantState state,
    AiAssistantController controller,
    ColorScheme scheme,
  ) {
    final timerStr = _formatDuration(state.recordingDurationSeconds);

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.blue.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Cancel / Delete Button
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 22,
            ),
            tooltip: 'Batalkan Rekaman',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.cancelVoiceRecording();
            },
          ),
          const SizedBox(width: 8),

          // Blinking Red Dot
          _buildBlinkingRedDot(),
          const SizedBox(width: 8),

          // Timer
          Text(
            timerStr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(width: 10),

          // Spoken Text or Soundwave
          Expanded(
            child: state.currentSpokenText.isNotEmpty
                ? Text(
                    state.currentSpokenText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Row(
                    children: [
                      _buildSoundWave(state.soundLevel),
                      const SizedBox(width: 8),
                      Text(
                        'Mendengarkan suara Anda...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),

          // Finish & Send Button
          Material(
            color: Colors.blue.shade600,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.mediumImpact();
                controller.stopAndSendVoiceRecording();
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkingRedDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.2, end: 1.0),
      duration: const Duration(milliseconds: 650),
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundWave(double level) {
    final normalized = (level / 10.0).clamp(0.1, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final factor = (index % 2 == 0 ? 10.0 : 16.0) * normalized + 4.0;
        return Container(
          width: 3,
          height: factor.clamp(4.0, 18.0),
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // ── Bubbles ───────────────────────────────────────────────────────

  Widget _buildMessageBubble(
    AiMessageModel msg,
    ThemeData theme,
    ColorScheme scheme,
    AiAssistantState state,
    AiAssistantController controller,
  ) {
    final isUser = msg.isUser;
    final isThisSpeaking =
        state.isSpeaking && state.currentlySpeakingMsgId == msg.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.indigo.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? scheme.primary
                        : msg.isError
                            ? scheme.errorContainer
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isUser
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    border: !isUser && !msg.isError
                        ? Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: isUser
                      ? SelectableText(
                          msg.content,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: scheme.onPrimary,
                          ),
                        )
                      : MarkdownBody(
                          data: msg.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: msg.isError
                                  ? scheme.onErrorContainer
                                  : scheme.onSurface,
                            ),
                            h1: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                            h2: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                            h3: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade800,
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                            listBullet: TextStyle(
                              fontSize: 13,
                              color: scheme.primary,
                            ),
                            horizontalRuleDecoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (!isUser && !msg.isError) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Audio Play / Stop Button
                      InkWell(
                        onTap: () {
                          if (isThisSpeaking) {
                            controller.stopSpeaking();
                          } else {
                            controller.speakMessage(msg.content, msg.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isThisSpeaking
                                    ? Icons.stop_circle_rounded
                                    : Icons.volume_up_rounded,
                                size: 14,
                                color: isThisSpeaking
                                    ? Colors.orange.shade700
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isThisSpeaking ? 'Hentikan' : 'Putar Suara',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isThisSpeaking
                                      ? Colors.orange.shade700
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Copy Button
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Teks berhasil disalin'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.indigo.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Asisten sedang menganalisis...',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
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
