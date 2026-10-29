import 'package:flutter/material.dart';

class AiApiKeyDialog extends StatefulWidget {
  const AiApiKeyDialog({
    super.key,
    required this.initialKey,
    required this.onSave,
  });

  final String initialKey;
  final ValueChanged<String> onSave;

  @override
  State<AiApiKeyDialog> createState() => _AiApiKeyDialogState();
}

class _AiApiKeyDialogState extends State<AiApiKeyDialog> {
  late final TextEditingController _keyController;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialKey);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.key_rounded,
              color: Colors.blue.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Google Gemini Key', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Key digunakan untuk Asisten AI MAngga POS dan analisis foto produk otomatis.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: _obscureText,
            decoration: InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'AIzaSy...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Gratis 1.500 permintaan/hari dari Google AI Studio.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_keyController.text.trim());
            Navigator.of(context).pop();
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
