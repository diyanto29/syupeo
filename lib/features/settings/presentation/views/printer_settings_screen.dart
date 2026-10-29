import 'dart:async';
import 'dart:convert';

import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/transaction/data/invoice_pdf_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dpos/core/widgets/bluetooth_prompt_sheet.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:printing/printing.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

enum _BluetoothPermissionAction { requestAgain, openSettings, dismiss }

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen>
    with WidgetsBindingObserver {
  final _printerService = ThermalPrinterService();
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _footerController = TextEditingController();
  final _codeTableController = TextEditingController();

  static const int _maxStoredLogoWidth = 320;
  static const int _maxStoredLogoHeight = 140;

  PrinterSettings _settings = PrinterSettings.defaults();
  List<ThermalPrinterDevice> _devices = const [];
  List<Printer> _windowsPrinters = const [];
  bool _loading = true;
  bool _scanning = false;
  bool _connecting = false;
  bool _pickingLogo = false;
  bool _printing = false;
  bool _bluetoothEnabled = false;
  bool _connected = false;
  bool _waitingForSettingsPermission = false;
  String? _statusMessage;
  Timer? _btStatePollTimer;

  List<Permission> get _bluetoothPermissions {
    if (kIsWeb) {
      return const [];
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ],
      TargetPlatform.iOS ||
      TargetPlatform.macOS => const [Permission.bluetooth],
      _ => const <Permission>[],
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController.text = _settings.receiptTitle;
    _footerController.text = _settings.receiptFooter;
    _codeTableController.text = _settings.codeTable;
    _loadSettings();
    _startBluetoothPolling();
  }

  void _startBluetoothPolling() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    _btStatePollTimer?.cancel();
    _btStatePollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      try {
        final enabled = await _printerService.bluetoothEnabled;
        if (!mounted) return;
        if (enabled != _bluetoothEnabled) {
          await _refreshStatus(scan: enabled);
          if (enabled && !_connected && _settings.hasSelectedPrinter) {
            _autoConnect();
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _btStatePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _footerController.dispose();
    _codeTableController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingForSettingsPermission) {
        _waitingForSettingsPermission = false;
        _refreshAfterPermissionSettings();
      } else {
        _refreshStatus(scan: true).then((_) {
          if (mounted && !_connected && _settings.hasSelectedPrinter) {
            _autoConnect();
          }
        });
      }
      _startBluetoothPolling();
    } else if (state == AppLifecycleState.paused) {
      _btStatePollTimer?.cancel();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await PrinterSettings.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _titleController.text = settings.receiptTitle;
      _footerController.text = settings.receiptFooter;
      _codeTableController.text = settings.codeTable;
    });
    if (mounted) {
      setState(() => _loading = false);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _refreshWindowsPrinters();
    } else {
      final permitted = await _ensureBluetoothPermission();
      await _refreshStatus(scan: permitted);
      if (permitted && !_connected && _settings.hasSelectedPrinter) {
        _autoConnect();
      }
    }
  }

  Future<void> _refreshWindowsPrinters() async {
    setState(() {
      _scanning = true;
      _statusMessage = null;
    });
    try {
      final printers = await Printing.listPrinters();
      if (!mounted) return;
      setState(() {
        _windowsPrinters = printers;
        _scanning = false;
        _connected = printers.isNotEmpty;
        _statusMessage = printers.isEmpty
            ? 'Tidak ada printer Windows terdeteksi. Colok printer via USB dan install driver POS-58.'
            : '${printers.length} printer Windows / USB terdeteksi.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _statusMessage = 'Gagal memuat printer Windows: $e';
      });
    }
  }

  Future<void> _saveSettings(PrinterSettings settings) async {
    if (!mounted) {
      return;
    }
    setState(() => _settings = settings);
    await settings.save();
    ref.invalidate(printerSettingsProvider);
  }

  Future<bool> _ensureBluetoothPermission() async {
    final permissions = _bluetoothPermissions;
    if (permissions.isEmpty) {
      return true;
    }

    final statuses = await permissions.request();
    if (await _hasBluetoothPermission()) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final canRequestAgain = statuses.values.any((status) => status.isDenied);
    final action = await _showBluetoothPermissionDialog(
      canRequestAgain: canRequestAgain,
    );

    if (action == _BluetoothPermissionAction.requestAgain) {
      await permissions.request();
      if (await _hasBluetoothPermission()) {
        return true;
      }

      if (!mounted) {
        return false;
      }
      final fallbackAction = await _showBluetoothPermissionDialog(
        canRequestAgain: false,
      );
      if (fallbackAction == _BluetoothPermissionAction.openSettings) {
        _waitingForSettingsPermission = true;
        await openAppSettings();
      }
      return false;
    }

    if (action == _BluetoothPermissionAction.openSettings) {
      _waitingForSettingsPermission = true;
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> _hasBluetoothPermission() async {
    final permissions = _bluetoothPermissions;
    if (permissions.isEmpty) {
      return true;
    }

    final statuses = await Future.wait(
      permissions.map((permission) => permission.status),
    );
    final handlerGranted = statuses.every(
      (status) => status.isGranted || status.isLimited,
    );
    if (!handlerGranted) {
      return false;
    }

    try {
      return await _printerService.bluetoothPermissionGranted;
    } catch (_) {
      return true;
    }
  }

  Future<_BluetoothPermissionAction> _showBluetoothPermissionDialog({
    required bool canRequestAgain,
  }) async {
    final action = await BluetoothPromptSheet.show(
      context,
      type: BluetoothPromptType.permission,
      canRequestPermission: canRequestAgain,
    );

    if (action == BluetoothPromptAction.primaryAction) {
      return canRequestAgain
          ? _BluetoothPermissionAction.requestAgain
          : _BluetoothPermissionAction.openSettings;
    } else if (action == BluetoothPromptAction.openSettings) {
      return _BluetoothPermissionAction.openSettings;
    }
    return _BluetoothPermissionAction.dismiss;
  }

  Future<void> _promptEnableBluetooth() async {
    final action = await BluetoothPromptSheet.show(
      context,
      type: BluetoothPromptType.enableBluetooth,
    );

    if (action == BluetoothPromptAction.primaryAction) {
      await _printerService.requestEnableBluetooth();
      // Polling aktif mendeteksi ketika pengguna mengaktifkan Bluetooth
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        final enabled = await _printerService.bluetoothEnabled;
        if (enabled) {
          await _refreshStatus(scan: true);
          if (!_connected && _settings.hasSelectedPrinter) {
            _autoConnect();
          }
          break;
        }
      }
    } else if (action == BluetoothPromptAction.openSettings) {
      await _printerService.openBluetoothSettings();
    }
  }

  Future<void> _refreshAfterPermissionSettings() async {
    final permitted = await _hasBluetoothPermission();
    await _refreshStatus(scan: permitted);

    if (!mounted) {
      return;
    }

    if (permitted && !_connected && _settings.hasSelectedPrinter) {
      _autoConnect();
    }

    setState(() {
      _statusMessage = permitted
          ? 'Izin Bluetooth aktif. Silakan cari printer lagi.'
          : 'Izin Nearby devices/Bluetooth masih belum aktif.';
    });
  }

  Future<void> _refreshStatus({bool scan = false}) async {
    final permitted = await _hasBluetoothPermission();
    if (!permitted) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bluetoothEnabled = false;
        _connected = false;
        if (scan) {
          _devices = const [];
        }
        _statusMessage = 'Izin Nearby devices/Bluetooth belum aktif.';
      });
      return;
    }

    try {
      final bluetoothEnabled = await _printerService.bluetoothEnabled;
      final connected = await _printerService.connectionStatus;
      final devices = scan ? await _printerService.pairedPrinters : _devices;

      if (!mounted) {
        return;
      }

      setState(() {
        _bluetoothEnabled = bluetoothEnabled;
        _connected = connected;
        _devices = devices;
        _statusMessage = bluetoothEnabled
            ? null
            : 'Bluetooth perangkat belum aktif.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Bluetooth tidak bisa diakses: $error';
      });
    }
  }

  Future<void> _scanPrinters() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _refreshWindowsPrinters();
      return;
    }

    setState(() {
      _scanning = true;
      _statusMessage = null;
    });

    final permitted = await _ensureBluetoothPermission();
    if (!permitted) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _statusMessage = 'Izin Bluetooth belum diberikan.';
        });
      }
      return;
    }

    final isBtEnabled = await _printerService.bluetoothEnabled;
    if (!isBtEnabled) {
      if (!mounted) return;
      final action = await BluetoothPromptSheet.show(
        context,
        type: BluetoothPromptType.enableBluetooth,
      );
      if (action == BluetoothPromptAction.primaryAction) {
        await _printerService.requestEnableBluetooth();
        await Future.delayed(const Duration(seconds: 1));
      } else if (action == BluetoothPromptAction.openSettings) {
        await _printerService.openBluetoothSettings();
        if (mounted) {
          setState(() {
            _scanning = false;
          });
        }
        return;
      } else {
        if (mounted) {
          setState(() {
            _scanning = false;
            _statusMessage = 'Bluetooth belum diaktifkan.';
          });
        }
        return;
      }
    }

    await _refreshStatus(scan: true);

    if (!mounted) {
      return;
    }

    setState(() {
      _scanning = false;
      if (_bluetoothEnabled && _devices.isEmpty) {
        _statusMessage = 'Belum ada printer Bluetooth yang ditemukan.';
      }
    });
  }

  Future<void> _autoConnect() async {
    if (_connecting || _connected) {
      return;
    }
    final address = _settings.selectedPrinterAddress;
    final name = _settings.selectedPrinterName ?? 'Printer';
    if (address == null || address.isEmpty) {
      return;
    }

    final isBtEnabled = await _printerService.bluetoothEnabled;
    if (!isBtEnabled) {
      return;
    }

    setState(() {
      _connecting = true;
      _statusMessage = 'Menghubungkan otomatis ke $name...';
    });

    try {
      final success = await _printerService.connect(address);
      if (!mounted) return;
      setState(() {
        _connected = success;
        _connecting = false;
        _statusMessage = success
            ? '$name terhubung otomatis.'
            : 'Gagal terhubung otomatis ke $name. Pastikan printer menyala.';
      });
      if (success) {
        ref.invalidate(printerSettingsProvider);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = false;
        _statusMessage = 'Gagal menghubungkan otomatis: $error';
      });
    }
  }

  Future<void> _connectPrinter(ThermalPrinterDevice device) async {
    setState(() {
      _connecting = true;
      _statusMessage = 'Menghubungkan ke ${device.name}...';
    });

    final permitted = await _ensureBluetoothPermission();
    if (!permitted) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _statusMessage = 'Izin Bluetooth belum diberikan.';
        });
      }
      return;
    }

    final isBtEnabled = await _printerService.bluetoothEnabled;
    if (!isBtEnabled) {
      if (!mounted) return;
      final action = await BluetoothPromptSheet.show(
        context,
        type: BluetoothPromptType.enableBluetooth,
      );
      if (action == BluetoothPromptAction.primaryAction) {
        await _printerService.requestEnableBluetooth();
        await Future.delayed(const Duration(seconds: 1));
      } else if (action == BluetoothPromptAction.openSettings) {
        await _printerService.openBluetoothSettings();
        if (mounted) {
          setState(() {
            _connecting = false;
          });
        }
        return;
      } else {
        if (mounted) {
          setState(() {
            _connecting = false;
            _statusMessage = 'Bluetooth belum diaktifkan.';
          });
        }
        return;
      }
    }

    try {
      final success = await _printerService.connect(device.address);
      final nextSettings = _settings.copyWith(
        selectedPrinterName: device.name,
        selectedPrinterAddress: device.address,
      );
      await _saveSettings(nextSettings);

      if (!mounted) {
        return;
      }

      setState(() {
        _connected = success;
        _statusMessage = success
            ? '${device.name} terhubung.'
            : 'Gagal menghubungkan printer.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Gagal menghubungkan printer: $error');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    setState(() {
      _connecting = true;
      _statusMessage = 'Memutus koneksi printer...';
    });

    try {
      final success = await _printerService.disconnect();
      if (!mounted) {
        return;
      }
      setState(() {
        _connected = !success;
        _statusMessage = success
            ? 'Koneksi printer diputus.'
            : 'Printer masih terhubung.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Gagal memutus koneksi: $error');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _pickLogo() async {
    if (_pickingLogo) {
      return;
    }

    setState(() => _pickingLogo = true);

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (file == null) {
        return;
      }

      final rawBytes = await file.readAsBytes();
      final normalizedBytes = _prepareLogoForStorage(rawBytes);
      if (normalizedBytes == null) {
        throw Exception('Format logo tidak didukung.');
      }

      await _saveSettings(
        _settings.copyWith(
          logoBase64: base64Encode(normalizedBytes),
          printLogo: true,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Logo struk berhasil disimpan.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih logo: $error')));
    } finally {
      if (mounted) {
        setState(() => _pickingLogo = false);
      }
    }
  }

  Future<void> _removeLogo() async {
    await _saveSettings(_settings.copyWith(printLogo: false, clearLogo: true));

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Logo struk dihapus.';
    });
  }

  Uint8List? _prepareLogoForStorage(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return null;
    }

    var normalized = _flattenLogoBackground(decoded);
    if (normalized.width > _maxStoredLogoWidth) {
      normalized = img.copyResize(normalized, width: _maxStoredLogoWidth);
    }
    if (normalized.height > _maxStoredLogoHeight) {
      normalized = img.copyResize(normalized, height: _maxStoredLogoHeight);
    }

    return Uint8List.fromList(img.encodePng(normalized));
  }

  img.Image? _buildPrintableLogo() {
    if (!_settings.printLogo) {
      return null;
    }

    final logoBytes = _settings.logoBytes;
    if (logoBytes == null) {
      return null;
    }

    final decoded = img.decodeImage(logoBytes);
    if (decoded == null) {
      return null;
    }

    var printable = _flattenLogoBackground(decoded);
    final maxWidth = switch (_settings.paperSize) {
      PrinterPaperSize.mm58 => 140,
      PrinterPaperSize.mm80 => 200,
    };
    final maxHeight = switch (_settings.paperSize) {
      PrinterPaperSize.mm58 => 72,
      PrinterPaperSize.mm80 => 100,
    };

    if (printable.width > maxWidth || printable.height > maxHeight) {
      final double scaleW = maxWidth / printable.width;
      final double scaleH = maxHeight / printable.height;
      final double scale = scaleW < scaleH ? scaleW : scaleH;
      final targetW = (printable.width * scale).round().clamp(1, maxWidth);
      final targetH = (printable.height * scale).round().clamp(1, maxHeight);
      printable = img.copyResize(
        printable,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );
    }

    printable = img.grayscale(printable);
    printable = img.adjustColor(printable, contrast: 1.25);
    printable = img.luminanceThreshold(printable, threshold: 0.7);

    return printable;
  }

  img.Image _flattenLogoBackground(img.Image source) {
    final canvas = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, source);
    return canvas;
  }

  Future<void> _printTestReceipt() async {
    setState(() {
      _printing = true;
      _statusMessage = 'Mengirim test print...';
    });

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final pdfBytes = await ref
            .read(invoicePdfServiceProvider)
            .generateTestPdf(copyIndex: 1);
        final printers = await Printing.listPrinters();

        Printer? targetPrinter;
        if (_settings.selectedWindowsPrinterName != null &&
            _settings.selectedWindowsPrinterName!.isNotEmpty) {
          targetPrinter = printers
              .where((p) => p.name == _settings.selectedWindowsPrinterName)
              .firstOrNull;
        }
        targetPrinter ??= printers.where((p) => p.isDefault).firstOrNull ??
            (printers.isNotEmpty ? printers.first : null);

        if (targetPrinter != null) {
          for (var i = 0; i < _settings.copies; i++) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              onLayout: (format) async => pdfBytes,
              name: 'Test_Print',
            );
            if (i < _settings.copies - 1) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
          if (mounted) {
            setState(() {
              _connected = true;
              _statusMessage =
                  'Test print Windows terkirim ke ${targetPrinter?.name}.';
            });
          }
          return;
        } else {
          await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Test_Print',
          );
          if (mounted) {
            setState(() {
              _statusMessage = 'Pratinjau test print dibuka.';
            });
          }
          return;
        }
      }

      final connected = await _printerService.connectionStatus;
      if (!connected) {
        throw Exception('Printer belum terhubung.');
      }

      for (var index = 0; index < _settings.copies; index += 1) {
        final ticket = await _buildTestTicket(copyIndex: index + 1);
        final success = await _printerService.printBytes(ticket);
        if (!success) {
          throw Exception('Printer menolak data test print.');
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _connected = true;
        _statusMessage = 'Test print terkirim.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Test print gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  Future<List<int>> _buildTestTicket({required int copyIndex}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(_settings.paperSize.paperSize, profile);
    var bytes = <int>[];
    bytes += generator.reset();
    final logo = _buildPrintableLogo();

    final codeTable = _settings.codeTable.trim();
    if (codeTable.isNotEmpty) {
      bytes += generator.setGlobalCodeTable(codeTable);
    }

    bytes += generator.setGlobalFont(
      _settings.fontMode.fontType,
      maxCharsPerLine: _settings.charactersPerLine,
    );

    if (_settings.openDrawer) {
      bytes += generator.drawer();
    }

    if (logo != null) {
      bytes += generator.image(
        logo,
        align: PosAlign.center,
        isDoubleDensity: true,
      );
      bytes += generator.feed(1);
    }

    bytes += generator.text(
      _settings.receiptTitle.trim().isEmpty
          ? 'D-POS'
          : _settings.receiptTitle.trim(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      maxCharsPerLine: _settings.charactersPerLine,
    );
    bytes += generator.text(
      'Test Printer Bluetooth',
      styles: const PosStyles(align: PosAlign.center),
      maxCharsPerLine: _settings.charactersPerLine,
    );
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(align: PosAlign.center),
      ),
      PosColumn(
        text: 'Total',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Kopi Susu', width: 6),
      PosColumn(
        text: '1',
        width: 2,
        styles: const PosStyles(align: PosAlign.center),
      ),
      PosColumn(
        text: '18.000',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Roti Bakar', width: 6),
      PosColumn(
        text: '2',
        width: 2,
        styles: const PosStyles(align: PosAlign.center),
      ),
      PosColumn(
        text: '30.000',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
      PosColumn(
        text: '48.000',
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    if (_settings.copies > 1) {
      bytes += generator.text(
        'Copy $copyIndex/${_settings.copies}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.feed(1);
    bytes += generator.text(
      _settings.receiptFooter.trim().isEmpty
          ? 'Terima kasih'
          : _settings.receiptFooter.trim(),
      styles: const PosStyles(align: PosAlign.center),
      maxCharsPerLine: _settings.charactersPerLine,
    );
    bytes += generator.feed(_settings.feedLines);

    if (_settings.autoCut) {
      bytes += generator.cut(mode: PosCutMode.partial);
    }

    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Pengaturan Printer'),
              badge: const AppTabletBadge(label: 'Mangga POS'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _scanning || _connecting ? null : _scanPrinters,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : AppBar(
              title: const Text('Pengaturan Printer'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _scanning || _connecting ? null : _scanPrinters,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  final content = isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildConnectionSection(context),
                                  const SizedBox(height: 16),
                                  _buildDeviceSection(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _buildCustomizationSection(context),
                                  const SizedBox(height: 16),
                                  _buildPreviewSection(context),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildConnectionSection(context),
                            const SizedBox(height: 16),
                            _buildDeviceSection(context),
                            const SizedBox(height: 16),
                            _buildCustomizationSection(context),
                            const SizedBox(height: 16),
                            _buildPreviewSection(context),
                          ],
                        );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: content,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildConnectionSection(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _buildWindowsConnectionSection(context);
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedName = _settings.selectedPrinterName ?? 'Belum dipilih';
    final selectedAddress = _settings.selectedPrinterAddress ?? '-';

    return _SettingsSurface(
      icon: Icons.bluetooth_connected_rounded,
      title: 'Koneksi Bluetooth',
      subtitle: 'Printer termal kasir',
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: _bluetoothEnabled ? 'Bluetooth Aktif' : 'Bluetooth Mati',
                color: _bluetoothEnabled ? Colors.green : Colors.red,
              ),
              _StatusPill(
                label: _connected ? 'Terhubung' : 'Belum Terhubung',
                color: _connected ? Colors.green : Colors.orange,
              ),
            ],
          ),
          if (!_bluetoothEnabled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF2F2), Color(0xFFFFF7ED)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Icon(
                      Icons.bluetooth_disabled_rounded,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bluetooth Belum Aktif',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF991B1B),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Nyalakan Bluetooth untuk menghubungkan printer kasir.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7F1D1D),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _promptEnableBluetooth,
                    icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                    label: const Text('Nyalakan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _InfoLine(label: 'Printer', value: selectedName),
          const SizedBox(height: 10),
          _InfoLine(label: 'Address', value: selectedAddress),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.62),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons =
                  constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.1;

              final scanButton = FilledButton.icon(
                onPressed: _scanning || _connecting ? null : _scanPrinters,
                icon: _scanning
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Cari Printer'),
              );

              final disconnectButton = OutlinedButton.icon(
                onPressed: !_connected || _connecting
                    ? null
                    : _disconnectPrinter,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Putus'),
              );

              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    scanButton,
                    const SizedBox(height: 12),
                    disconnectButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: scanButton),
                  const SizedBox(width: 12),
                  Expanded(child: disconnectButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _buildWindowsDeviceSection(context);
    }

    return _SettingsSurface(
      icon: Icons.print_outlined,
      title: 'Daftar Printer',
      subtitle: '${_devices.length} perangkat tersedia',
      child: Column(
        children: [
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tidak ada printer pada daftar Bluetooth perangkat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.55),
                ),
              ),
            )
          else
            ..._devices.map((device) {
              final selected =
                  device.address == _settings.selectedPrinterAddress;
              return _PrinterDeviceTile(
                device: device,
                selected: selected,
                connecting: _connecting,
                connected: selected && _connected,
                onConnect: () => _connectPrinter(device),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCustomizationSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final logoBytes = _settings.logoBytes;

    return _SettingsSurface(
      icon: Icons.tune_rounded,
      title: 'Custom Struk',
      subtitle: 'Ukuran kertas, font, dan output',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ukuran Kertas', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PrinterPaperSize>(
              segments: PrinterPaperSize.values
                  .map(
                    (size) => ButtonSegment<PrinterPaperSize>(
                      value: size,
                      label: Text(size.label),
                    ),
                  )
                  .toList(),
              selected: {_settings.paperSize},
              onSelectionChanged: (selected) {
                final paperSize = selected.first;
                _saveSettings(
                  _settings.copyWith(
                    paperSize: paperSize,
                    charactersPerLine: paperSize.defaultCharacters,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Karakter per Baris',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                '${_settings.charactersPerLine}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            min: 24,
            max: 64,
            divisions: 40,
            value: _settings.charactersPerLine.toDouble(),
            label: '${_settings.charactersPerLine}',
            onChanged: (value) {
              _saveSettings(
                _settings.copyWith(charactersPerLine: value.round()),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PrinterFontMode>(
            value: _settings.fontMode,
            decoration: const InputDecoration(
              labelText: 'Mode Font',
              border: OutlineInputBorder(),
            ),
            items: PrinterFontMode.values
                .map(
                  (mode) =>
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                )
                .toList(),
            onChanged: (mode) {
              if (mode == null) {
                return;
              }
              _saveSettings(_settings.copyWith(fontMode: mode));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Judul Struk',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(receiptTitle: value));
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _footerController,
            decoration: const InputDecoration(
              labelText: 'Footer Struk',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(receiptFooter: value));
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Logo Struk',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: _settings.printLogo && logoBytes != null,
                      onChanged: logoBytes == null
                          ? null
                          : (value) {
                              _saveSettings(
                                _settings.copyWith(printLogo: value),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  logoBytes == null
                      ? 'Upload logo agar tercetak di header struk.'
                      : _settings.printLogo
                      ? 'Logo aktif dan akan dicetak.'
                      : 'Logo tersimpan, tapi belum ikut dicetak.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.58),
                  ),
                ),
                if (logoBytes != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 220,
                        maxHeight: 100,
                      ),
                      child: Image.memory(logoBytes, fit: BoxFit.contain),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackButtons =
                        constraints.maxWidth < 420 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.1;

                    final uploadButton = FilledButton.tonalIcon(
                      onPressed: _pickingLogo ? null : _pickLogo,
                      icon: _pickingLogo
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              logoBytes == null
                                  ? Icons.upload_file_rounded
                                  : Icons.edit_rounded,
                            ),
                      label: Text(
                        logoBytes == null ? 'Upload Logo' : 'Ganti Logo',
                      ),
                    );

                    final removeButton = OutlinedButton.icon(
                      onPressed: _pickingLogo ? null : _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Hapus'),
                    );

                    if (logoBytes == null) {
                      return SizedBox(
                        width: double.infinity,
                        child: uploadButton,
                      );
                    }

                    if (stackButtons) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          uploadButton,
                          const SizedBox(height: 12),
                          removeButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: uploadButton),
                        const SizedBox(width: 12),
                        Expanded(child: removeButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeTableController,
            decoration: const InputDecoration(
              labelText: 'Code Table',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(codeTable: value));
            },
          ),
          const SizedBox(height: 12),
          _NumberStepper(
            icon: Icons.copy_rounded,
            label: 'Jumlah Copy',
            value: _settings.copies,
            min: 1,
            max: 5,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(copies: value));
            },
          ),
          _NumberStepper(
            icon: Icons.vertical_align_bottom_rounded,
            label: 'Feed Akhir',
            value: _settings.feedLines,
            min: 1,
            max: 8,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(feedLines: value));
            },
          ),
          _SwitchLine(
            icon: Icons.content_cut_rounded,
            label: 'Auto Cut',
            value: _settings.autoCut,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(autoCut: value));
            },
          ),
          _SwitchLine(
            icon: Icons.point_of_sale_rounded,
            label: 'Buka Cash Drawer',
            value: _settings.openDrawer,
            onChanged: (value) {
              _saveSettings(_settings.copyWith(openDrawer: value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final logoBytes = _settings.logoBytes;
    final width = _settings.charactersPerLine.clamp(24, 44);
    final divider = '-' * width;
    final title = _settings.receiptTitle.trim().isEmpty
        ? 'D-POS'
        : _settings.receiptTitle.trim();
    final footer = _settings.receiptFooter.trim().isEmpty
        ? 'Terima kasih'
        : _settings.receiptFooter.trim();

    return _SettingsSurface(
      icon: Icons.receipt_long_rounded,
      title: 'Preview & Test',
      subtitle: 'Simulasi output struk',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_settings.printLogo && logoBytes != null) ...[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 200,
                          maxHeight: 84,
                        ),
                        child: Image.memory(logoBytes, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    [
                      _center(title, width),
                      _center('Test Printer Bluetooth', width),
                      divider,
                      'Item             Qty     Total',
                      divider,
                      'Kopi Susu          1    18.000',
                      'Roti Bakar         2    30.000',
                      divider,
                      'TOTAL                  48.000',
                      _center(footer, width),
                    ].join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                      color: scheme.onSurface.withOpacity(0.78),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_settings.printLogo && logoBytes == null) ...[
            const SizedBox(height: 10),
            Text(
              'Logo aktif, tapi file logo belum tersedia.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: ((!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
                    ? _windowsPrinters.isEmpty
                    : !_connected) ||
                _printing
                ? null
                : _printTestReceipt,
            icon: _printing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: const Text('Test Print'),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsConnectionSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedName = _settings.selectedWindowsPrinterName ??
        (_windowsPrinters.where((p) => p.isDefault).firstOrNull?.name ??
            'Gunakan Default Windows');

    return _SettingsSurface(
      icon: Icons.usb_rounded,
      title: 'Printer Windows / USB',
      subtitle: 'Printer termal kasir via driver Windows / USB',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _StatusPill(
                label: 'Mode Windows Spooler',
                color: Colors.blue,
              ),
              _StatusPill(
                label: _windowsPrinters.isNotEmpty
                    ? '${_windowsPrinters.length} Printer Terdeteksi'
                    : 'Belum Ada Printer',
                color:
                    _windowsPrinters.isNotEmpty ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoLine(label: 'Printer Aktif', value: selectedName),
          const SizedBox(height: 10),
          const _InfoLine(
            label: 'Tipe Koneksi',
            value: 'Driver Windows / USB Spooler (ESC/POS Safe)',
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.62),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _scanning ? null : _refreshWindowsPrinters,
            icon: _scanning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Refresh Printer Windows / USB'),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsDeviceSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _SettingsSurface(
      icon: Icons.print_rounded,
      title: 'Daftar Printer Windows',
      subtitle: '${_windowsPrinters.length} printer terpasang di Windows',
      child: Column(
        children: [
          if (_windowsPrinters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(
                    Icons.print_disabled_rounded,
                    size: 48,
                    color: scheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada printer Windows terdeteksi.',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Colok printer EPPOS via USB dan pastikan driver POS-58 sudah diinstall di Windows.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._windowsPrinters.map((printer) {
              final isSelected =
                  _settings.selectedWindowsPrinterName == printer.name ||
                  (_settings.selectedWindowsPrinterName == null &&
                      printer.isDefault);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isSelected
                      ? scheme.primaryContainer.withOpacity(0.4)
                      : scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color:
                          isSelected ? scheme.primary : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _saveSettings(
                        _settings.copyWith(
                          selectedWindowsPrinterName: printer.name,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              color: isSelected ? Colors.white : scheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        printer.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (printer.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'Default Windows',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  printer.url.isNotEmpty
                                      ? printer.url
                                      : 'USB / Local Port',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        scheme.onSurface.withOpacity(0.55),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                              size: 22,
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                _saveSettings(
                                  _settings.copyWith(
                                    selectedWindowsPrinterName: printer.name,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Pilih'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _center(String text, int width) {
    if (text.length >= width) {
      return text.substring(0, width);
    }
    final leftPadding = ((width - text.length) / 2).floor();
    return '${' ' * leftPadding}$text';
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.52),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.48),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrinterDeviceTile extends StatelessWidget {
  const _PrinterDeviceTile({
    required this.device,
    required this.selected,
    required this.connecting,
    required this.connected,
    required this.onConnect,
  });

  final ThermalPrinterDevice device;
  final bool selected;
  final bool connecting;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackButton =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.1;

            final actionButton = FilledButton.tonal(
              onPressed: connecting ? null : onConnect,
              child: Text(connected ? 'Aktif' : 'Connect'),
            );

            final details = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: selected
                      ? scheme.primary.withOpacity(0.12)
                      : scheme.surfaceContainerHighest,
                  child: Icon(
                    connected ? Icons.print_rounded : Icons.print_outlined,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (stackButton) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [details, const SizedBox(height: 12), actionButton],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                actionButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurface.withOpacity(0.58)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Kurangi',
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Tambah',
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurface.withOpacity(0.58)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
