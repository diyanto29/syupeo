import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrisSettings {
  const QrisSettings({
    this.imagePath,
    this.merchantName,
    this.nmid,
    this.printOnReceipt = false,
    this.qrisPayload,
    this.enableDynamicQris = true,
  });

  final String? imagePath;
  final String? merchantName;
  final String? nmid;
  final bool printOnReceipt;
  final String? qrisPayload;
  final bool enableDynamicQris;

  bool get hasQrisImage =>
      imagePath != null &&
      imagePath!.trim().isNotEmpty &&
      File(imagePath!).existsSync();

  bool get hasQrisPayload =>
      qrisPayload != null && qrisPayload!.trim().isNotEmpty;

  QrisSettings copyWith({
    String? imagePath,
    String? merchantName,
    String? nmid,
    bool? printOnReceipt,
    String? qrisPayload,
    bool? enableDynamicQris,
    bool clearImagePath = false,
    bool clearQrisPayload = false,
  }) {
    return QrisSettings(
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      merchantName: merchantName ?? this.merchantName,
      nmid: nmid ?? this.nmid,
      printOnReceipt: printOnReceipt ?? this.printOnReceipt,
      qrisPayload: clearQrisPayload ? null : (qrisPayload ?? this.qrisPayload),
      enableDynamicQris: enableDynamicQris ?? this.enableDynamicQris,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'merchantName': merchantName,
      'nmid': nmid,
      'printOnReceipt': printOnReceipt,
      'qrisPayload': qrisPayload,
      'enableDynamicQris': enableDynamicQris,
    };
  }

  factory QrisSettings.fromMap(Map<String, dynamic> map) {
    return QrisSettings(
      imagePath: map['imagePath'] as String?,
      merchantName: map['merchantName'] as String?,
      nmid: map['nmid'] as String?,
      printOnReceipt: (map['printOnReceipt'] as bool?) ?? false,
      qrisPayload: map['qrisPayload'] as String?,
      enableDynamicQris: (map['enableDynamicQris'] as bool?) ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory QrisSettings.fromJson(String source) =>
      QrisSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}

class QrisSettingsRepository {
  const QrisSettingsRepository();

  static const String _prefKey = 'store_qris_settings';

  Future<QrisSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) {
      return const QrisSettings();
    }
    try {
      final settings = QrisSettings.fromJson(raw);
      // Validasi apakah file gambar lokal masih ada
      if (settings.imagePath != null &&
          !File(settings.imagePath!).existsSync()) {
        return settings.copyWith(clearImagePath: true);
      }
      return settings;
    } catch (_) {
      return const QrisSettings();
    }
  }

  Future<void> save(QrisSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, settings.toJson());
  }

  Future<String> saveImageFile(File file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final qrisDir = Directory('${appDir.path}/qris');
    if (!qrisDir.existsSync()) {
      await qrisDir.create(recursive: true);
    }

    final ext = file.path.contains('.')
        ? '.${file.path.split('.').last}'
        : '.png';
    final targetPath =
        '${qrisDir.path}/store_qris_${DateTime.now().millisecondsSinceEpoch}$ext';

    // Salin file ke storage internal aplikasi
    final savedFile = await file.copy(targetPath);
    return savedFile.path;
  }

  Future<void> deleteImageFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

final qrisSettingsRepositoryProvider = Provider<QrisSettingsRepository>((ref) {
  return const QrisSettingsRepository();
});

class QrisSettingsNotifier extends AsyncNotifier<QrisSettings> {
  @override
  Future<QrisSettings> build() async {
    final repo = ref.read(qrisSettingsRepositoryProvider);
    return repo.load();
  }

  Future<void> updateSettings({
    String? merchantName,
    String? nmid,
    bool? printOnReceipt,
    File? newImageFile,
    bool removeImage = false,
    String? qrisPayload,
    bool? enableDynamicQris,
    bool clearQrisPayload = false,
  }) async {
    final current = state.value ?? const QrisSettings();
    final repo = ref.read(qrisSettingsRepositoryProvider);

    String? newPath = current.imagePath;

    if (removeImage && current.imagePath != null) {
      await repo.deleteImageFile(current.imagePath!);
      newPath = null;
    } else if (newImageFile != null) {
      if (current.imagePath != null) {
        await repo.deleteImageFile(current.imagePath!);
      }
      newPath = await repo.saveImageFile(newImageFile);
    }

    final updated = current.copyWith(
      merchantName: merchantName,
      nmid: nmid,
      printOnReceipt: printOnReceipt,
      imagePath: newPath,
      clearImagePath: removeImage,
      qrisPayload: qrisPayload,
      clearQrisPayload: clearQrisPayload,
      enableDynamicQris: enableDynamicQris,
    );

    state = AsyncData(updated);
    await repo.save(updated);
  }
}

final qrisSettingsProvider =
    AsyncNotifierProvider<QrisSettingsNotifier, QrisSettings>(
      QrisSettingsNotifier.new,
    );
