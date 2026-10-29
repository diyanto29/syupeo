import 'dart:convert';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

final printerSettingsRepositoryProvider = Provider<PrinterSettingsRepository>(
  (ref) => const PrinterSettingsRepository(),
);

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>(
  (ref) => const ThermalPrinterService(),
);

final printerSettingsProvider = FutureProvider<PrinterSettings>((ref) {
  return ref.read(printerSettingsRepositoryProvider).load();
});

enum PrinterPaperSize {
  mm58(label: '58 mm', defaultCharacters: 32, paperSize: PaperSize.mm58),
  mm80(label: '80 mm', defaultCharacters: 48, paperSize: PaperSize.mm80);

  const PrinterPaperSize({
    required this.label,
    required this.defaultCharacters,
    required this.paperSize,
  });

  final String label;
  final int defaultCharacters;
  final PaperSize paperSize;
}

enum PrinterFontMode {
  fontA(label: 'Font A', fontType: PosFontType.fontA),
  fontB(label: 'Font B', fontType: PosFontType.fontB);

  const PrinterFontMode({required this.label, required this.fontType});

  final String label;
  final PosFontType fontType;
}

class ThermalPrinterDevice {
  const ThermalPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

class ThermalPrinterService {
  const ThermalPrinterService();

  Future<bool> get bluetoothPermissionGranted =>
      PrintBluetoothThermal.isPermissionBluetoothGranted;

  Future<bool> get bluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> get connectionStatus => PrintBluetoothThermal.connectionStatus;

  Future<List<ThermalPrinterDevice>> get pairedPrinters async {
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map(
          (device) => ThermalPrinterDevice(
            name: device.name.trim().isEmpty
                ? 'Printer Thermal'
                : device.name.trim(),
            address: device.macAdress,
          ),
        )
        .toList();
  }

  Future<bool> connect(String address) {
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  /// Mencoba menghubungkan secara otomatis ke printer yang tersimpan di settings.
  Future<bool> autoConnect({PrinterSettings? settings}) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }

    try {
      final isConnected = await connectionStatus;
      if (isConnected) return true;

      final targetSettings = settings ?? await PrinterSettings.load();
      final address = targetSettings.selectedPrinterAddress;
      if (address == null || address.isEmpty) {
        return false;
      }

      final isBtEnabled = await bluetoothEnabled;
      if (!isBtEnabled) {
        return false;
      }

      return await connect(address);
    } catch (e) {
      debugPrint('ThermalPrinterService autoConnect error: $e');
      return false;
    }
  }

  Future<bool> printBytes(List<int> bytes) {
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  static const MethodChannel _nativeChannel =
      MethodChannel('dpos/bluetooth_helper');

  /// Minta Android mengaktifkan Bluetooth secara langsung lewat dialog prompt sistem
  Future<bool> requestEnableBluetooth() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod('requestEnableBluetooth');
        return res == true;
      } catch (_) {}
    }
    return false;
  }

  /// Buka halaman Pengaturan Bluetooth HP secara langsung
  Future<bool> openBluetoothSettings() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMethod('openBluetoothSettings');
        return res == true;
      } catch (_) {}
    }
    return false;
  }
}

class PrinterSettings {
  const PrinterSettings({
    required this.paperSize,
    required this.charactersPerLine,
    required this.fontMode,
    required this.copies,
    required this.feedLines,
    required this.autoCut,
    required this.openDrawer,
    required this.printLogo,
    required this.receiptTitle,
    required this.receiptFooter,
    required this.codeTable,
    this.logoBase64,
    this.selectedPrinterName,
    this.selectedPrinterAddress,
    this.selectedWindowsPrinterName,
  });

  final PrinterPaperSize paperSize;
  final int charactersPerLine;
  final PrinterFontMode fontMode;
  final int copies;
  final int feedLines;
  final bool autoCut;
  final bool openDrawer;
  final bool printLogo;
  final String receiptTitle;
  final String receiptFooter;
  final String codeTable;
  final String? logoBase64;
  final String? selectedPrinterName;
  final String? selectedPrinterAddress;
  final String? selectedWindowsPrinterName;

  bool get hasSelectedPrinter =>
      selectedPrinterName != null && selectedPrinterAddress != null;

  bool get hasSelectedWindowsPrinter =>
      selectedWindowsPrinterName != null && selectedWindowsPrinterName!.isNotEmpty;

  bool get hasLogo => logoBytes != null;

  Uint8List? get logoBytes {
    final value = logoBase64;
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  factory PrinterSettings.defaults() {
    return const PrinterSettings(
      paperSize: PrinterPaperSize.mm58,
      charactersPerLine: 32,
      fontMode: PrinterFontMode.fontA,
      copies: 1,
      feedLines: 3,
      autoCut: true,
      openDrawer: false,
      printLogo: false,
      receiptTitle: 'D-POS',
      receiptFooter: 'Terima kasih',
      codeTable: 'CP1252',
    );
  }

  static Future<PrinterSettings> load() {
    return const PrinterSettingsRepository().load();
  }

  Future<void> save() {
    return const PrinterSettingsRepository().save(this);
  }

  PrinterSettings copyWith({
    PrinterPaperSize? paperSize,
    int? charactersPerLine,
    PrinterFontMode? fontMode,
    int? copies,
    int? feedLines,
    bool? autoCut,
    bool? openDrawer,
    bool? printLogo,
    String? receiptTitle,
    String? receiptFooter,
    String? codeTable,
    String? logoBase64,
    bool clearLogo = false,
    String? selectedPrinterName,
    String? selectedPrinterAddress,
    String? selectedWindowsPrinterName,
  }) {
    return PrinterSettings(
      paperSize: paperSize ?? this.paperSize,
      charactersPerLine: charactersPerLine ?? this.charactersPerLine,
      fontMode: fontMode ?? this.fontMode,
      copies: copies ?? this.copies,
      feedLines: feedLines ?? this.feedLines,
      autoCut: autoCut ?? this.autoCut,
      openDrawer: openDrawer ?? this.openDrawer,
      printLogo: printLogo ?? this.printLogo,
      receiptTitle: receiptTitle ?? this.receiptTitle,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      codeTable: codeTable ?? this.codeTable,
      logoBase64: clearLogo ? null : (logoBase64 ?? this.logoBase64),
      selectedPrinterName: selectedPrinterName ?? this.selectedPrinterName,
      selectedPrinterAddress:
          selectedPrinterAddress ?? this.selectedPrinterAddress,
      selectedWindowsPrinterName:
          selectedWindowsPrinterName ?? this.selectedWindowsPrinterName,
    );
  }
}

class PrinterSettingsRepository {
  const PrinterSettingsRepository();

  static const _paperSizeKey = 'printer.paperSize';
  static const _charactersPerLineKey = 'printer.charactersPerLine';
  static const _fontModeKey = 'printer.fontMode';
  static const _copiesKey = 'printer.copies';
  static const _feedLinesKey = 'printer.feedLines';
  static const _autoCutKey = 'printer.autoCut';
  static const _openDrawerKey = 'printer.openDrawer';
  static const _printLogoKey = 'printer.printLogo';
  static const _receiptTitleKey = 'printer.receiptTitle';
  static const _receiptFooterKey = 'printer.receiptFooter';
  static const _codeTableKey = 'printer.codeTable';
  static const _logoBase64Key = 'printer.logoBase64';
  static const _printerNameKey = 'printer.selectedName';
  static const _printerAddressKey = 'printer.selectedAddress';
  static const _windowsPrinterNameKey = 'printer.windowsPrinterName';

  Future<PrinterSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = PrinterSettings.defaults();
    final paperSize = _enumByName(
      PrinterPaperSize.values,
      prefs.getString(_paperSizeKey),
      defaults.paperSize,
    );
    final fontMode = _enumByName(
      PrinterFontMode.values,
      prefs.getString(_fontModeKey),
      defaults.fontMode,
    );

    return PrinterSettings(
      paperSize: paperSize,
      charactersPerLine:
          prefs.getInt(_charactersPerLineKey) ?? paperSize.defaultCharacters,
      fontMode: fontMode,
      copies: prefs.getInt(_copiesKey) ?? defaults.copies,
      feedLines: prefs.getInt(_feedLinesKey) ?? defaults.feedLines,
      autoCut: prefs.getBool(_autoCutKey) ?? defaults.autoCut,
      openDrawer: prefs.getBool(_openDrawerKey) ?? defaults.openDrawer,
      printLogo: prefs.getBool(_printLogoKey) ?? defaults.printLogo,
      receiptTitle: prefs.getString(_receiptTitleKey) ?? defaults.receiptTitle,
      receiptFooter:
          prefs.getString(_receiptFooterKey) ?? defaults.receiptFooter,
      codeTable: prefs.getString(_codeTableKey) ?? defaults.codeTable,
      logoBase64: prefs.getString(_logoBase64Key),
      selectedPrinterName: prefs.getString(_printerNameKey),
      selectedPrinterAddress: prefs.getString(_printerAddressKey),
      selectedWindowsPrinterName: prefs.getString(_windowsPrinterNameKey),
    );
  }

  Future<void> save(PrinterSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paperSizeKey, settings.paperSize.name);
    await prefs.setInt(_charactersPerLineKey, settings.charactersPerLine);
    await prefs.setString(_fontModeKey, settings.fontMode.name);
    await prefs.setInt(_copiesKey, settings.copies);
    await prefs.setInt(_feedLinesKey, settings.feedLines);
    await prefs.setBool(_autoCutKey, settings.autoCut);
    await prefs.setBool(_openDrawerKey, settings.openDrawer);
    await prefs.setBool(_printLogoKey, settings.printLogo);
    await prefs.setString(_receiptTitleKey, settings.receiptTitle);
    await prefs.setString(_receiptFooterKey, settings.receiptFooter);
    await prefs.setString(_codeTableKey, settings.codeTable);

    final logoBase64 = settings.logoBase64;
    if (logoBase64 == null || logoBase64.isEmpty) {
      await prefs.remove(_logoBase64Key);
    } else {
      await prefs.setString(_logoBase64Key, logoBase64);
    }

    final printerName = settings.selectedPrinterName;
    final printerAddress = settings.selectedPrinterAddress;
    if (printerName == null || printerAddress == null) {
      await prefs.remove(_printerNameKey);
      await prefs.remove(_printerAddressKey);
    } else {
      await prefs.setString(_printerNameKey, printerName);
      await prefs.setString(_printerAddressKey, printerAddress);
    }

    final windowsPrinterName = settings.selectedWindowsPrinterName;
    if (windowsPrinterName == null || windowsPrinterName.isEmpty) {
      await prefs.remove(_windowsPrinterNameKey);
    } else {
      await prefs.setString(_windowsPrinterNameKey, windowsPrinterName);
    }
  }

  T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
