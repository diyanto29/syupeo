import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/core/widgets/app_form_field.dart';
import 'package:dpos/features/discount_management/data/discount_repository.dart';
import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:dpos/features/menu_management/data/menu_category_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';

class DiscountEditorSheet extends ConsumerStatefulWidget {
  const DiscountEditorSheet({
    super.key,
    this.initialDiscount,
    this.isPage = false,
  });

  final DiscountDefinition? initialDiscount;
  final bool isPage;

  @override
  ConsumerState<DiscountEditorSheet> createState() =>
      _DiscountEditorSheetState();
}

class _DiscountEditorSheetState extends ConsumerState<DiscountEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _percentageController = TextEditingController();
  final _amountController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _speechToText = stt.SpeechToText();

  DiscountType _type = DiscountType.percentage;
  bool _isActive = true;
  bool _useSchedule = false;
  bool _useMaxDiscount = false;
  bool _isSaving = false;
  bool _isSpeechReady = false;
  bool _isListening = false;
  bool _hasPendingVoiceReview = false;
  String _voiceTranscript = '';
  String? _speechLocaleId;
  List<String> _voiceCategoryCandidates = const [];
  DateTime? _startsAt;
  DateTime? _endsAt;

  bool get _isEditMode => widget.initialDiscount != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _initVoiceAssistant();
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _percentageController.dispose();
    _amountController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  void _prefill() {
    final discount = widget.initialDiscount;
    if (discount == null) {
      return;
    }

    _nameController.text = discount.name;
    _codeController.text = discount.code ?? '';
    _descriptionController.text = discount.description ?? '';
    _type = discount.type;
    _isActive = discount.isActive;
    _percentageController.text = discount.percentageValue == null
        ? ''
        : _formatNumber(discount.percentageValue!);
    _amountController.text = discount.amountValue == null
        ? ''
        : RupiahInputHelper.format(discount.amountValue!);
    _maxDiscountController.text = discount.maxDiscountAmount == null
        ? ''
        : RupiahInputHelper.format(discount.maxDiscountAmount!);
    _useMaxDiscount = discount.usesMaxDiscount;
    _useSchedule = discount.hasSchedule;
    _startsAt = discount.startsAt;
    _endsAt = discount.endsAt;
  }

  Future<void> _initVoiceAssistant() async {
    final isReady = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );
    if (!mounted) {
      return;
    }

    String? localeId;
    if (isReady) {
      final locales = await _speechToText.locales();
      if (locales.isNotEmpty) {
        localeId = locales
            .firstWhere(
              (locale) => locale.localeId.toLowerCase().startsWith('id_'),
              orElse: () => locales.first,
            )
            .localeId;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSpeechReady = isReady;
      _speechLocaleId = localeId;
    });
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    final hasStopped = status == 'notListening' || status == 'done';
    if (!hasStopped) {
      return;
    }

    setState(() => _isListening = false);
    _showVoiceReviewIfReady();
  }

  void _handleSpeechError(Object error) {
    if (!mounted) {
      return;
    }

    _hasPendingVoiceReview = false;
    setState(() => _isListening = false);
    final message = error.toString().trim().isEmpty
        ? 'Voice input gagal diproses.'
        : 'Voice input gagal: $error';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startVoiceCapture(List<String> categoryNames) async {
    FocusScope.of(context).unfocus();
    if (!_isSpeechReady) {
      await _initVoiceAssistant();
    }
    if (!mounted) {
      return;
    }
    if (!_isSpeechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input belum siap. Cek izin mikrofon lalu coba lagi.',
          ),
        ),
      );
      return;
    }
    if (_isListening) {
      return;
    }

    _voiceCategoryCandidates = categoryNames;
    _hasPendingVoiceReview = true;
    setState(() {
      _isListening = true;
      _voiceTranscript = '';
    });

    await _speechToText.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }
        setState(() => _voiceTranscript = result.recognizedWords.trim());
        if (result.finalResult) {
          _showVoiceReviewIfReady();
        }
      },
      localeId: _speechLocaleId,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> _stopVoiceCaptureAndReview() async {
    if (!_isListening) {
      return;
    }
    await _speechToText.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isListening = false);
    _showVoiceReviewIfReady();
  }

  void _showVoiceReviewIfReady() {
    if (!_hasPendingVoiceReview) {
      return;
    }
    _hasPendingVoiceReview = false;

    final transcript = _voiceTranscript.trim();
    if (transcript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada suara yang terbaca. Coba bicara lebih dekat ke mikrofon.',
          ),
        ),
      );
      return;
    }

    final suggestion = _VoiceDiscountSuggestionParser.parse(
      transcript: transcript,
      availableCategoryNames: _voiceCategoryCandidates,
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final hasAnyParsedValue = suggestion.hasApplicableData;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Voice Input',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cek dulu hasil AI voice sebelum dipakai ke form add discount.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    suggestion.transcript,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 14),
                _VoiceReviewLine(
                  label: 'Nama discount',
                  value: suggestion.name,
                ),
                _VoiceReviewLine(
                  label: 'Kategori item',
                  value: suggestion.categoryName,
                ),
                _VoiceReviewLine(
                  label: 'Kode',
                  value: suggestion.code?.toUpperCase(),
                ),
                _VoiceReviewLine(
                  label: 'Nilai discount',
                  value: suggestion.valueLabel,
                ),
                _VoiceReviewLine(
                  label: 'Maksimal discount',
                  value: suggestion.maxDiscountLabel,
                ),
                _VoiceReviewLine(
                  label: 'Status aktif',
                  value: suggestion.isActive == null
                      ? null
                      : (suggestion.isActive! ? 'Aktif' : 'Nonaktif'),
                ),
                if (!hasAnyParsedValue) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada field yang cocok diparsing. Coba ucapkan format: "Diskon member 10 persen kategori minuman maksimal 20 ribu".',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final editedTranscript = await _openTranscriptEditor(
                            suggestion.transcript,
                          );
                          if (!mounted || editedTranscript == null) {
                            return;
                          }
                          setState(() => _voiceTranscript = editedTranscript);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          _hasPendingVoiceReview = true;
                          _showVoiceReviewIfReady();
                        },
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Edit Transkrip'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.mic_none_rounded),
                        label: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: !hasAnyParsedValue
                            ? null
                            : () {
                                _applyVoiceSuggestion(suggestion);
                                Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Gunakan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _openTranscriptEditor(String transcript) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _TranscriptEditorDialog(initialTranscript: transcript),
    );
  }

  void _applyVoiceSuggestion(_VoiceDiscountSuggestion suggestion) {
    setState(() {
      if (suggestion.name != null) {
        _nameController.text = suggestion.name!;
      }
      if (suggestion.code != null) {
        _codeController.text = suggestion.code!.toUpperCase();
      }
      if (suggestion.isActive != null) {
        _isActive = suggestion.isActive!;
      }
      if (suggestion.type != null) {
        _type = suggestion.type!;
      }

      if (suggestion.type == DiscountType.percentage &&
          suggestion.percentageValue != null) {
        _percentageController.text = _formatNumber(suggestion.percentageValue!);
        _amountController.clear();
      } else if (suggestion.type == DiscountType.fixedAmount &&
          suggestion.amountValue != null) {
        _amountController.text = RupiahInputHelper.format(
          suggestion.amountValue!,
        );
        _percentageController.clear();
        _maxDiscountController.clear();
        _useMaxDiscount = false;
      }

      if (suggestion.type == DiscountType.percentage &&
          suggestion.maxDiscountAmount != null) {
        _useMaxDiscount = true;
        _maxDiscountController.text = RupiahInputHelper.format(
          suggestion.maxDiscountAmount!,
        );
      }

      if (suggestion.categoryName != null) {
        _descriptionController.text = _mergeCategoryIntoDescription(
          _descriptionController.text,
          suggestion.categoryName!,
        );
      }
    });
  }

  String _mergeCategoryIntoDescription(
    String description,
    String categoryName,
  ) {
    const prefix = 'Target kategori item:';
    final rows = description
        .split('\n')
        .map((row) => row.trim())
        .where((row) => row.isNotEmpty)
        .where((row) => !row.toLowerCase().startsWith(prefix.toLowerCase()))
        .toList();
    return ['$prefix $categoryName', ...rows].join('\n');
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    if (_useSchedule &&
        _startsAt != null &&
        _endsAt != null &&
        _endsAt!.isBefore(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal akhir harus setelah tanggal mulai.'),
        ),
      );
      return;
    }

    final businessId = ref.read(homeBootstrapProvider).value?.business?.id;
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data bisnis belum siap. Coba beberapa saat lagi.'),
        ),
      );
      return;
    }

    final percentageValue = _type == DiscountType.percentage
        ? double.tryParse(_percentageController.text.trim())
        : null;
    final amountValue = _type == DiscountType.fixedAmount
        ? RupiahInputHelper.parseToDouble(_amountController.text)
        : null;
    final maxDiscountAmount =
        _type == DiscountType.percentage && _useMaxDiscount
        ? RupiahInputHelper.parseToDouble(_maxDiscountController.text)
        : null;

    final discount = DiscountDefinition(
      id: widget.initialDiscount?.id ?? _uuid.v4(),
      businessId: businessId,
      name: _nameController.text.trim(),
      code: _codeController.text.trim().isEmpty
          ? null
          : _codeController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _type,
      percentageValue: percentageValue,
      amountValue: amountValue,
      maxDiscountAmount: maxDiscountAmount,
      isActive: _isActive,
      startsAt: _useSchedule ? _startsAt : null,
      endsAt: _useSchedule ? _endsAt : null,
      createdAt: widget.initialDiscount?.createdAt,
      updatedAt: widget.initialDiscount?.updatedAt,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(discountsProvider.notifier).upsertDiscount(discount);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan discount: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _startsAt = DateTime(picked.year, picked.month, picked.day);
      if (_endsAt != null && _endsAt!.isBefore(_startsAt!)) {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endsAt ?? _startsAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startsAt ?? DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final maxWidth = width >= 760 ? 720.0 : 560.0;
    final categoryNames =
        ref
            .watch(menuCategoriesProvider)
            .valueOrNull
            ?.map((category) => category.name)
            .where((name) => name.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isPage) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditMode
                                      ? 'Edit Discount'
                                      : 'Tambah Discount',
                                  style:
                                      (isMobile
                                              ? theme.textTheme.titleLarge
                                              : theme.textTheme.headlineSmall)
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Simpan metadata discount yang nanti bisa dipakai fleksibel di berbagai alur transaksi.',
                                  style:
                                      (isMobile
                                              ? theme.textTheme.bodySmall
                                              : theme.textTheme.bodyMedium)
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.66,
                                            ),
                                            height: 1.45,
                                          ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(_isEditMode ? 'Update' : 'Simpan'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _isListening
                                      ? Icons.mic_rounded
                                      : Icons.keyboard_voice_rounded,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Voice Input',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isListening
                                          ? 'Sedang merekam. Tekan "Stop & Review" setelah selesai bicara.'
                                          : 'Isi nama discount, kategori item, dan nominal lewat suara. Hasilnya direview dulu.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.66,
                                            ),
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : (_isListening
                                            ? _stopVoiceCaptureAndReview
                                            : () => _startVoiceCapture(
                                                categoryNames,
                                              )),
                                  icon: Icon(
                                    _isListening
                                        ? Icons.stop_rounded
                                        : Icons.mic_none_rounded,
                                  ),
                                  label: Text(
                                    _isListening
                                        ? 'Stop & Review'
                                        : 'Mulai Voice',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_voiceTranscript.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _voiceTranscript,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.82,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Basic Metadata',
                      icon: Icons.info_outline_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextInput(
                            label: 'Nama Discount',
                            isRequired: true,
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            hintText: 'e.g. Promo Ramadhan, Diskon Member',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppTextInput(
                                  label: 'Kode Promo (Opsional)',
                                  controller: _codeController,
                                  textInputAction: TextInputAction.next,
                                  hintText: 'e.g. RAMADHAN20',
                                ),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Text(
                                      'Status',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E293B),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _isActive,
                                    onChanged: (v) =>
                                        setState(() => _isActive = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextInput(
                            label: 'Deskripsi',
                            controller: _descriptionController,
                            minLines: 2,
                            maxLines: 4,
                            hintText: 'Tulis detail atau syarat discount...',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Aturan Nominal',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Tipe Potongan'),
                          SegmentedButton<DiscountType>(
                            segments: const [
                              ButtonSegment(
                                value: DiscountType.percentage,
                                label: Text('Persentase (%)'),
                                icon: Icon(Icons.percent_rounded, size: 16),
                              ),
                              ButtonSegment(
                                value: DiscountType.fixedAmount,
                                label: Text('Nominal (Rp)'),
                                icon: Icon(Icons.money_rounded, size: 16),
                              ),
                            ],
                            selected: {_type},
                            onSelectionChanged: (v) =>
                                setState(() => _type = v.first),
                          ),
                          const SizedBox(height: 20),
                          if (_type == DiscountType.percentage) ...[
                            AppTextInput(
                              label: 'Besar Potongan Diskon',
                              isRequired: true,
                              prefixBadge: '%',
                              controller: _percentageController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              hintText: '0 - 100',
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Persen wajib diisi';
                                }
                                final p = double.tryParse(v);
                                if (p == null || p < 0 || p > 100) {
                                  return 'Input 0 sampai 100';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _useMaxDiscount,
                                  onChanged: (v) => setState(
                                    () => _useMaxDiscount = v ?? false,
                                  ),
                                ),
                                const Text('Batasi Maksimal Potongan'),
                              ],
                            ),
                            if (_useMaxDiscount) ...[
                              const SizedBox(height: 8),
                              AppCurrencyInput(
                                label: 'Maksimal Potongan',
                                isRequired: true,
                                controller: _maxDiscountController,
                                prefixBadge: 'IDR',
                                hintText: '50.000',
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Maksimal potongan wajib diisi'
                                    : null,
                              ),
                            ],
                          ] else ...[
                            AppCurrencyInput(
                              label: 'Nominal Potongan',
                              isRequired: true,
                              controller: _amountController,
                              prefixBadge: 'IDR',
                              hintText: '10.000',
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Nominal wajib diisi'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Jadwal Aktif',
                      icon: Icons.calendar_month_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 12),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _useSchedule,
                                onChanged: (v) =>
                                    setState(() => _useSchedule = v ?? false),
                              ),
                              const Text('Gunakan Masa Berlaku'),
                            ],
                          ),
                          if (_useSchedule) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _DateButtonField(
                                    label: 'Mulai',
                                    value: _startsAt,
                                    onTap: _pickStartDate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DateButtonField(
                                    label: 'Berakhir',
                                    value: _endsAt,
                                    onTap: _pickEndDate,
                                  ),
                                ),
                              ],
                            ),
                            if (_startsAt != null &&
                                _endsAt != null &&
                                _endsAt!.isBefore(_startsAt!)) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tanggal akhir harus setelah tanggal mulai.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    if (widget.isPage) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_isEditMode ? 'Perbarui Diskon' : 'Simpan Diskon'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _TranscriptEditorDialog extends StatefulWidget {
  const _TranscriptEditorDialog({required this.initialTranscript});

  final String initialTranscript;

  @override
  State<_TranscriptEditorDialog> createState() =>
      _TranscriptEditorDialogState();
}

class _TranscriptEditorDialogState extends State<_TranscriptEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTranscript);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Transkrip Voice'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 7,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Perbaiki teks voice agar parsing lebih akurat',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Proses Ulang'),
        ),
      ],
    );
  }
}

class _VoiceDiscountSuggestion {
  const _VoiceDiscountSuggestion({
    required this.transcript,
    this.name,
    this.categoryName,
    this.code,
    this.type,
    this.percentageValue,
    this.amountValue,
    this.maxDiscountAmount,
    this.isActive,
  });

  final String transcript;
  final String? name;
  final String? categoryName;
  final String? code;
  final DiscountType? type;
  final double? percentageValue;
  final double? amountValue;
  final double? maxDiscountAmount;
  final bool? isActive;

  bool get hasApplicableData {
    return name != null ||
        categoryName != null ||
        code != null ||
        type != null ||
        percentageValue != null ||
        amountValue != null ||
        maxDiscountAmount != null ||
        isActive != null;
  }

  String? get valueLabel {
    if (type == DiscountType.percentage && percentageValue != null) {
      return '${_compactNumber(percentageValue!)}%';
    }
    if (type == DiscountType.fixedAmount && amountValue != null) {
      return RupiahInputHelper.formatWithPrefix(amountValue!);
    }
    return null;
  }

  String? get maxDiscountLabel {
    if (maxDiscountAmount == null) {
      return null;
    }
    return RupiahInputHelper.formatWithPrefix(maxDiscountAmount!);
  }

  static String _compactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _VoiceDiscountSuggestionParser {
  static const Set<String> _generalStopKeywords = {
    'kategori',
    'item',
    'menu',
    'kode',
    'code',
    'maks',
    'maksimal',
    'max',
    'nominal',
    'potongan',
    'diskon',
    'discount',
    'rp',
    'rupiah',
    'persen',
    '%',
    'aktif',
    'nonaktif',
    'mulai',
    'berakhir',
    'sampai',
  };

  static const Set<String> _numberWords = {
    'nol',
    'kosong',
    'satu',
    'dua',
    'tiga',
    'empat',
    'lima',
    'enam',
    'tujuh',
    'delapan',
    'sembilan',
    'sepuluh',
    'sebelas',
    'belas',
    'puluh',
    'ratus',
    'ribu',
    'juta',
    'seratus',
    'seribu',
    'sejuta',
    'rb',
    'jt',
  };

  static const Map<String, int> _digitWordValues = {
    'nol': 0,
    'kosong': 0,
    'satu': 1,
    'dua': 2,
    'tiga': 3,
    'empat': 4,
    'lima': 5,
    'enam': 6,
    'tujuh': 7,
    'delapan': 8,
    'sembilan': 9,
  };

  static _VoiceDiscountSuggestion parse({
    required String transcript,
    required List<String> availableCategoryNames,
  }) {
    final normalizedTranscript = _normalizeSpaces(transcript);
    final normalized = _normalizeForParsing(normalizedTranscript);
    final tokens = _tokenize(normalized);
    final categoryName = _extractCategory(
      normalized,
      tokens,
      availableCategoryNames,
    );
    final code = _extractCode(normalized);
    final isActive = _extractActiveFlag(normalized);
    final percentageValue = _extractPercentage(normalized, tokens);
    final maxAmountData = _extractMaxAmount(tokens);
    final amountValue = _extractAmount(
      tokens,
      maxAmount: maxAmountData?.$1,
      hasPercentage: percentageValue != null,
    );
    final type = _resolveType(
      normalized,
      percentageValue: percentageValue,
      amountValue: amountValue,
    );
    final name = _extractName(normalized);

    return _VoiceDiscountSuggestion(
      transcript: normalizedTranscript,
      name: name,
      categoryName: categoryName,
      code: code,
      type: type,
      percentageValue: percentageValue,
      amountValue: amountValue,
      maxDiscountAmount: maxAmountData?.$1,
      isActive: isActive,
    );
  }

  static String _normalizeForParsing(String value) {
    final lowered = value.toLowerCase();
    final sanitized = lowered.replaceAll(RegExp(r'[^a-z0-9%., ]'), ' ');
    return _normalizeSpaces(sanitized);
  }

  static String _normalizeSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> _tokenize(String normalized) {
    if (normalized.isEmpty) {
      return const [];
    }
    return normalized.split(' ').where((token) => token.isNotEmpty).toList();
  }

  static String? _extractCategory(
    String normalized,
    List<String> tokens,
    List<String> availableCategoryNames,
  ) {
    String? bestMatch;
    var bestLength = 0;
    for (final category in availableCategoryNames) {
      final candidate = category.trim();
      if (candidate.isEmpty) {
        continue;
      }
      final lower = candidate.toLowerCase();
      if (normalized.contains(lower) && lower.length > bestLength) {
        bestMatch = candidate;
        bestLength = lower.length;
      }
    }
    if (bestMatch != null) {
      return bestMatch;
    }

    final phrase = _extractPhraseAfterKeywords(
      tokens: tokens,
      keywords: const {'kategori'},
      stopKeywords: _generalStopKeywords,
      maxTokens: 6,
      skipTokens: const {'item', 'menu'},
    );
    if (phrase != null) {
      final matchedByHint = _matchCategoryByTokenOverlap(
        phrase,
        availableCategoryNames,
      );
      if (matchedByHint != null) {
        return matchedByHint;
      }
      return _titleCase(phrase);
    }

    final matchedFromTranscript = _matchCategoryByTokenOverlap(
      normalized,
      availableCategoryNames,
      minimalScore: 0.75,
    );
    if (matchedFromTranscript != null) {
      return matchedFromTranscript;
    }

    return null;
  }

  static String? _extractCode(String normalized) {
    final match = RegExp(
      r'(?:kode|code)\s+(?:nya\s+)?([a-z0-9_-]{3,30})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static bool? _extractActiveFlag(String normalized) {
    if (RegExp(
      r'\b(nonaktif|non aktif|matikan|disable|off|tidak aktif)\b',
    ).hasMatch(normalized)) {
      return false;
    }
    if (RegExp(
      r'\b(aktif|aktifkan|nyalakan|enable|on)\b',
    ).hasMatch(normalized)) {
      return true;
    }
    return null;
  }

  static double? _extractPercentage(String normalized, List<String> tokens) {
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:persen|%)',
      caseSensitive: false,
    ).firstMatch(normalized);
    final raw = match?.group(1);
    if (raw != null) {
      final parsed = _parseDecimal(raw);
      if (_isValidPercentage(parsed)) {
        return parsed;
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token != 'persen' && token != '%') {
        continue;
      }
      final start = (i - 5).clamp(0, i);
      final beforeTokens = tokens.sublist(start, i);
      final parsedBefore = _parseNumberFromTokens(
        beforeTokens,
        forCurrency: false,
      );
      if (_isValidPercentage(parsedBefore)) {
        return parsedBefore;
      }

      final end = (i + 5).clamp(i + 1, tokens.length);
      final afterTokens = tokens.sublist(i + 1, end);
      final parsedAfter = _parseNumberFromTokens(
        afterTokens,
        forCurrency: false,
      );
      if (_isValidPercentage(parsedAfter)) {
        return parsedAfter;
      }
    }

    return null;
  }

  static bool _isValidPercentage(double? value) {
    return value != null && value > 0 && value <= 100;
  }

  static (double amount, int start, int end)? _extractMaxAmount(
    List<String> tokens,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      if (!{'maks', 'maksimal', 'max'}.contains(tokens[i])) {
        continue;
      }
      final end = (i + 8).clamp(i + 1, tokens.length);
      final segment = tokens.sublist(i + 1, end);
      final parsed = _parseNumberFromTokens(segment, forCurrency: true);
      if (parsed != null && parsed > 0) {
        return (parsed, -1, -1);
      }
    }

    return null;
  }

  static double? _extractAmount(
    List<String> tokens, {
    required double? maxAmount,
    required bool hasPercentage,
  }) {
    for (var i = 0; i < tokens.length; i++) {
      if (!{'rp', 'rupiah'}.contains(tokens[i])) {
        continue;
      }
      final end = (i + 7).clamp(i + 1, tokens.length);
      final segment = tokens.sublist(i + 1, end);
      final parsed = _parseNumberFromTokens(segment, forCurrency: true);
      if (parsed != null && parsed > 0) {
        if (maxAmount != null && parsed == maxAmount) {
          continue;
        }
        return parsed;
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      if (!{'nominal', 'potongan', 'diskon', 'discount'}.contains(tokens[i])) {
        continue;
      }
      final previousToken = i > 0 ? tokens[i - 1] : '';
      if ({'maks', 'maksimal', 'max'}.contains(previousToken)) {
        continue;
      }
      final end = (i + 7).clamp(i + 1, tokens.length);
      final segment = tokens.sublist(i + 1, end);
      if (segment.contains('persen') || segment.contains('%')) {
        continue;
      }
      final parsed = _parseNumberFromTokens(segment, forCurrency: true);
      if (parsed != null && parsed > 0) {
        if (maxAmount != null && parsed == maxAmount) {
          continue;
        }
        return parsed;
      }
    }

    if (!hasPercentage) {
      final fallback = _parseNumberFromTokens(tokens, forCurrency: true);
      if (fallback != null && fallback > 100) {
        if (maxAmount != null && fallback == maxAmount) {
          return null;
        }
        return fallback;
      }
    }

    return null;
  }

  static DiscountType? _resolveType(
    String normalized, {
    required double? percentageValue,
    required double? amountValue,
  }) {
    if (percentageValue != null) {
      return DiscountType.percentage;
    }
    if (amountValue != null) {
      return DiscountType.fixedAmount;
    }
    if (normalized.contains('%') || normalized.contains('persen')) {
      return DiscountType.percentage;
    }
    if (normalized.contains('rupiah') ||
        normalized.contains('rp') ||
        normalized.contains('nominal')) {
      return DiscountType.fixedAmount;
    }
    return null;
  }

  static String? _extractName(String normalized) {
    final explicitMatch = RegExp(
      r'(?:nama|diskon|discount)\s+([a-z0-9 ]+?)(?=(?:\s+(?:kode|kategori|maks|max|nominal|potongan|rp|rupiah|persen|%|aktif|nonaktif|mulai|berakhir|sampai))|$)',
      caseSensitive: false,
    ).firstMatch(normalized);
    final explicit = _cleanNameCandidate(explicitMatch?.group(1));
    if (_isValidNameCandidate(explicit)) {
      return _titleCase(explicit!);
    }

    var fallback = normalized
        .replaceAll(
          RegExp(
            r'\b(tambah|buat|tolong|isi|set|setel|bikin|dong|please|yang|untuk)\b',
          ),
          '',
        )
        .trim();
    fallback = fallback
        .split(
          RegExp(
            r'\b(kode|kategori|maks|max|nominal|potongan|rp|rupiah|persen|%|aktif|nonaktif)\b',
          ),
        )
        .first
        .trim();
    fallback = _cleanNameCandidate(fallback) ?? '';
    if (!_isValidNameCandidate(fallback)) {
      return null;
    }
    return _titleCase(fallback);
  }

  static String? _cleanNameCandidate(String? candidate) {
    if (candidate == null) {
      return null;
    }
    final cleaned = candidate
        .replaceAll(RegExp(r'\b(kategori|item|menu)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static bool _isValidNameCandidate(String? value) {
    if (value == null) {
      return false;
    }
    final cleaned = value.trim();
    if (cleaned.length < 3) {
      return false;
    }
    if (!RegExp(r'[a-z]', caseSensitive: false).hasMatch(cleaned)) {
      return false;
    }
    if (RegExp(r'^(aktif|nonaktif)$', caseSensitive: false).hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  static double? _parseNumberFromTokens(
    List<String> rawTokens, {
    required bool forCurrency,
  }) {
    if (rawTokens.isEmpty) {
      return null;
    }

    final tokens = rawTokens
        .map((token) => _normalizeNumericToken(token))
        .where((token) => token.isNotEmpty && token != 'dan')
        .toList(growable: false);

    for (var i = 0; i < tokens.length; i++) {
      final numeric = _parseDecimal(tokens[i]);
      if (numeric == null) {
        continue;
      }
      final unit = i + 1 < tokens.length ? tokens[i + 1] : null;
      final scaled = _applyUnitMultiplier(numeric, unit);
      if (!forCurrency) {
        return scaled;
      }
      if (scaled > 0) {
        return scaled;
      }
    }

    for (var start = 0; start < tokens.length; start++) {
      if (!_isNumberWordToken(tokens[start])) {
        continue;
      }
      for (var end = tokens.length; end > start; end--) {
        final chunk = tokens.sublist(start, end);
        final parsedWordValue = _parseWordNumberChunk(chunk);
        if (parsedWordValue == null || parsedWordValue <= 0) {
          continue;
        }
        if (!forCurrency) {
          return parsedWordValue;
        }
        return parsedWordValue;
      }
    }
    return null;
  }

  static String _normalizeNumericToken(String token) {
    final cleaned = token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.,%]'), '');
    return switch (cleaned) {
      'rb' => 'ribu',
      'jt' => 'juta',
      _ => cleaned,
    };
  }

  static bool _isNumberWordToken(String token) {
    return _numberWords.contains(token) || _digitWordValues.containsKey(token);
  }

  static double _applyUnitMultiplier(double value, String? unit) {
    final cleanUnit = unit == null ? '' : _normalizeNumericToken(unit);
    return switch (cleanUnit) {
      'ribu' => value * 1000,
      'juta' => value * 1000000,
      _ => value,
    };
  }

  static double? _parseWordNumberChunk(List<String> tokens) {
    if (tokens.isEmpty) {
      return null;
    }

    final commaIndex = tokens.indexOf('koma');
    if (commaIndex >= 0) {
      final intPart = _parseWordNumberChunk(tokens.sublist(0, commaIndex));
      if (intPart == null) {
        return null;
      }
      final decimalTokens = tokens.sublist(commaIndex + 1);
      if (decimalTokens.isEmpty) {
        return intPart;
      }
      final digits = <String>[];
      for (final token in decimalTokens) {
        final normalized = _normalizeNumericToken(token);
        final digit = _digitWordValues[normalized];
        if (digit == null) {
          break;
        }
        digits.add('$digit');
      }
      if (digits.isEmpty) {
        return intPart;
      }
      return double.tryParse('$intPart.${digits.join()}');
    }

    var total = 0.0;
    var current = 0.0;
    var hasNumber = false;

    for (final rawToken in tokens) {
      final token = _normalizeNumericToken(rawToken);
      if (token.isEmpty) {
        continue;
      }

      final digitValue = _digitWordValues[token];
      if (digitValue != null) {
        current += digitValue;
        hasNumber = true;
        continue;
      }

      switch (token) {
        case 'sepuluh':
          current += 10;
          hasNumber = true;
        case 'sebelas':
          current += 11;
          hasNumber = true;
        case 'belas':
          current = (current == 0 ? 1 : current) + 10;
          hasNumber = true;
        case 'puluh':
          current = (current == 0 ? 1 : current) * 10;
          hasNumber = true;
        case 'ratus':
          current = (current == 0 ? 1 : current) * 100;
          hasNumber = true;
        case 'seratus':
          current += 100;
          hasNumber = true;
        case 'seribu':
          total += 1000;
          hasNumber = true;
          current = 0;
        case 'sejuta':
          total += 1000000;
          hasNumber = true;
          current = 0;
        case 'ribu':
          total += (current == 0 ? 1 : current) * 1000;
          hasNumber = true;
          current = 0;
        case 'juta':
          total += (current == 0 ? 1 : current) * 1000000;
          hasNumber = true;
          current = 0;
        default:
          return hasNumber ? (total + current) : null;
      }
    }

    if (!hasNumber) {
      return null;
    }
    return total + current;
  }

  static String? _extractPhraseAfterKeywords({
    required List<String> tokens,
    required Set<String> keywords,
    required Set<String> stopKeywords,
    required int maxTokens,
    Set<String> skipTokens = const {},
  }) {
    for (var i = 0; i < tokens.length; i++) {
      if (!keywords.contains(tokens[i])) {
        continue;
      }
      final phraseTokens = <String>[];
      for (
        var j = i + 1;
        j < tokens.length && phraseTokens.length < maxTokens;
        j++
      ) {
        final token = tokens[j];
        if (stopKeywords.contains(token)) {
          break;
        }
        if (skipTokens.contains(token)) {
          continue;
        }
        phraseTokens.add(token);
      }
      if (phraseTokens.isNotEmpty) {
        return phraseTokens.join(' ').trim();
      }
    }
    return null;
  }

  static String? _matchCategoryByTokenOverlap(
    String hint,
    List<String> availableCategoryNames, {
    double minimalScore = 0.45,
  }) {
    if (hint.trim().isEmpty || availableCategoryNames.isEmpty) {
      return null;
    }
    final hintTokens = hint
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 2)
        .toSet();
    if (hintTokens.isEmpty) {
      return null;
    }

    String? bestCategory;
    var bestScore = 0.0;
    for (final category in availableCategoryNames) {
      final categoryTokens = category
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((token) => token.length > 2)
          .toSet();
      if (categoryTokens.isEmpty) {
        continue;
      }
      final intersectionCount = hintTokens
          .where((token) => categoryTokens.contains(token))
          .length;
      if (intersectionCount == 0) {
        continue;
      }
      final score = intersectionCount / categoryTokens.length;
      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }
    }

    if (bestScore < minimalScore) {
      return null;
    }
    return bestCategory;
  }

  static double? _parseDecimal(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    normalized = normalized.replaceAll('%', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.]'), ''));
  }

  static String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (RegExp(r'^\d+$').hasMatch(word)) {
            return word;
          }
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}

class _VoiceReviewLine extends StatelessWidget {
  const _VoiceReviewLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? '-',
              style: theme.textTheme.bodySmall?.copyWith(
                color: value == null
                    ? scheme.onSurface.withValues(alpha: 0.5)
                    : scheme.onSurface,
                fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _DateButtonField extends StatelessWidget {
  const _DateButtonField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return AppSelectorField(
      label: label,
      valueText: value == null ? null : localizations.formatShortDate(value!),
      placeholder: 'Pilih tanggal',
      leadingIcon: const Icon(
        Icons.event_outlined,
        size: 20,
        color: Color(0xFF64748B),
      ),
      onTap: onTap,
    );
  }
}
