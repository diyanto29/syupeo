import 'dart:io';
import 'package:dpos/features/settings/data/printer_settings_repository.dart';
import 'package:dpos/features/settings/data/qris_settings_repository.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:dpos/features/transaction/data/invoice_pdf_service.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService(ref);
});

class ReceiptService {
  const ReceiptService(this._ref);

  final Ref _ref;

  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

  /// Generate ESC/POS receipt bytes for thermal printer.
  Future<List<int>> generateReceiptBytes(TransactionOrder order) async {
    final settings = await PrinterSettings.load();
    final profile = await CapabilityProfile.load();
    final generator = Generator(settings.paperSize.paperSize, profile);

    List<int> bytes = [];

    // ── Header ──────────────────────────────────────────────
    bytes += generator.reset();

    final codeTable = settings.codeTable.trim();
    if (codeTable.isNotEmpty) {
      bytes += generator.setGlobalCodeTable(codeTable);
    }

    bytes += generator.setGlobalFont(
      settings.fontMode.fontType,
      maxCharsPerLine: settings.charactersPerLine,
    );

    final logo = _buildPrintableLogo(settings);
    if (logo != null) {
      bytes += generator.image(
        logo,
        align: PosAlign.center,
        isDoubleDensity: true,
      );
      bytes += generator.feed(1);
    }

    bytes += generator.text(
      settings.receiptTitle.trim().isEmpty
          ? 'D-POS'
          : settings.receiptTitle.trim(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      maxCharsPerLine: settings.charactersPerLine,
    );
    bytes += generator.feed(1);

    // ── Invoice Info ────────────────────────────────────────
    bytes += generator.text(
      'No: ${order.invoiceNumber}',
      styles: const PosStyles(align: PosAlign.center),
    );

    final dateStr = order.createdAt != null
        ? _dateFormat.format(order.createdAt!)
        : _dateFormat.format(DateTime.now());
    bytes += generator.text(
      dateStr,
      styles: const PosStyles(align: PosAlign.center),
    );

    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text(
        'Pelanggan: ${order.customerName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    final diningBanner = switch (order.diningOption) {
      DiningOption.takeAway => '*** TAKE AWAY (BUNGKUS) ***',
      DiningOption.delivery => '*** DELIVERY (PESAN ANTAR) ***',
      DiningOption.goFood => '*** ONLINE: GOFOOD ***',
      DiningOption.grabFood => '*** ONLINE: GRABFOOD ***',
      DiningOption.shopeeFood => '*** ONLINE: SHOPEEFOOD ***',
      DiningOption.custom => '*** PESANAN KHUSUS ***',
      DiningOption.dineIn => (order.tableNumber != null
          ? '*** DINE IN (MEJA ${order.tableNumber}) ***'
          : '*** DINE IN ***'),
    };

    bytes += generator.feed(1);
    bytes += generator.text(
      diningBanner,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    bytes += generator.feed(1);

    if (order.tableNumber != null) {
      bytes += generator.text(
        'Meja: ${order.tableNumber}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    if (order.cashierName != null && order.cashierName!.isNotEmpty) {
      bytes += generator.text(
        'Kasir: ${order.cashierName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }
    if (order.waiterName != null && order.waiterName!.isNotEmpty) {
      bytes += generator.text(
        'Waiter: ${order.waiterName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    bytes += generator.hr(ch: '-');

    // ── Items ───────────────────────────────────────────────
    for (final item in order.items) {
      final nameWithPromo = item.promoTag != null
          ? '${item.displayName} ${item.promoTag}'
          : item.displayName;

      bytes += generator.text(
        nameWithPromo,
        styles: const PosStyles(bold: true),
      );

      if (item.isPackage && item.packageComponents.isNotEmpty) {
        for (final comp in item.packageComponents) {
          bytes += generator.text(
            '   + $comp',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
            ),
          );
        }
      }

      bytes += generator.row([
        PosColumn(
          text:
              '  ${item.quantity} x ${_currencyFormat.format(item.unitPrice)}',
          width: 7,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _currencyFormat.format(item.rawSubtotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (item.hasDiscount) {
        bytes += generator.row([
          PosColumn(
            text: '  Disc: ${item.discountName}',
            width: 6,
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
            ),
          ),
          PosColumn(
            text: '-${_currencyFormat.format(item.discountApplied)}',
            width: 6,
            styles: const PosStyles(
              align: PosAlign.right,
              fontType: PosFontType.fontB,
            ),
          ),
        ]);
      }

      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += generator.text(
          '  Catatan: ${item.notes}',
          styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontB,
          ),
        );
      }
    }

    bytes += generator.hr(ch: '-');

    // ── Subtotal ────────────────────────────────────────────
    bytes += generator.row([
      PosColumn(
        text: 'Subtotal',
        width: 7,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: _currencyFormat.format(order.subtotal),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // ── Discounts ───────────────────────────────────────────
    for (final disc in order.discounts) {
      bytes += generator.row([
        PosColumn(
          text: 'Disc: ${disc.name}',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '-${_currencyFormat.format(disc.appliedAmount)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // ── Tax ─────────────────────────────────────────────────
    if (order.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'Pajak',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _currencyFormat.format(order.taxAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (order.discountTotal > 0 || order.taxAmount > 0) {
      bytes += generator.hr(ch: '-');
    }

    // ── Grand Total ─────────────────────────────────────────
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 7,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: _currencyFormat.format(order.grandTotal),
        width: 5,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += generator.feed(1);

    // ── Payment Info ────────────────────────────────────────
    if (order.payments.isNotEmpty) {
      for (final pay in order.payments) {
        bytes += generator.row([
          PosColumn(
            text: 'Bayar (${pay.methodName})',
            width: 7,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: _currencyFormat.format(pay.amount),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (order.changeAmount > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Kembalian',
            width: 7,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: _currencyFormat.format(order.changeAmount),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      final isDebt = order.payments.any((p) => p.methodType == 'debt');
      if (isDebt) {
        bytes += generator.feed(1);
        bytes += generator.text(
          '** KASBON / TEMPO **',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
        );
        bytes += generator.text(
          '(PIUTANG BELUM LUNAS)',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    } else {
      bytes += generator.text(
        '** BELUM LUNAS **',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
    }

    bytes += generator.feed(1);

    // ── Optional QRIS on Receipt ────────────────────────────
    const qrisRepo = QrisSettingsRepository();
    final qrisSettings = await qrisRepo.load();
    if (qrisSettings.printOnReceipt) {
      if (qrisSettings.hasQrisPayload) {
        bytes += generator.feed(1);
        bytes += generator.text(
          'QRIS PEMBAYARAN',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        bytes += generator.qrcode(
          qrisSettings.qrisPayload!,
          size: QRSize.size6,
          align: PosAlign.center,
        );
        if (qrisSettings.merchantName != null &&
            qrisSettings.merchantName!.trim().isNotEmpty) {
          bytes += generator.text(
            qrisSettings.merchantName!,
            styles: const PosStyles(align: PosAlign.center),
          );
        }
        bytes += generator.feed(1);
      } else if (qrisSettings.hasQrisImage) {
        final qrisImage = _buildPrintableQris(qrisSettings);
        if (qrisImage != null) {
          bytes += generator.feed(1);
          bytes += generator.text(
            'QRIS PEMBAYARAN',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          );
          bytes += generator.image(qrisImage, align: PosAlign.center);
          if (qrisSettings.merchantName != null &&
              qrisSettings.merchantName!.trim().isNotEmpty) {
            bytes += generator.text(
              qrisSettings.merchantName!,
              styles: const PosStyles(align: PosAlign.center),
            );
          }
          bytes += generator.feed(1);
        }
      }
    }

    // ── Footer ──────────────────────────────────────────────
    bytes += generator.text(
      settings.receiptFooter.trim().isEmpty
          ? 'Terima kasih'
          : settings.receiptFooter.trim(),
      styles: const PosStyles(align: PosAlign.center),
      maxCharsPerLine: settings.charactersPerLine,
    );

    bytes += generator.feed(settings.feedLines);
    if (settings.autoCut) {
      bytes += generator.cut();
    }
    if (settings.openDrawer) {
      bytes += generator.drawer();
    }

    return bytes;
  }

  img.Image? _buildPrintableQris(QrisSettings qrisSettings) {
    if (!qrisSettings.hasQrisImage) return null;
    try {
      final file = File(qrisSettings.imagePath!);
      if (!file.existsSync()) return null;
      final fileBytes = file.readAsBytesSync();
      final decoded = img.decodeImage(fileBytes);
      if (decoded == null) return null;
      return img.copyResize(decoded, width: 200);
    } catch (_) {
      return null;
    }
  }

  img.Image? _buildPrintableLogo(PrinterSettings settings) {
    if (!settings.printLogo) {
      return null;
    }

    final logoBytes = settings.logoBytes;
    if (logoBytes == null) {
      return null;
    }

    final decoded = img.decodeImage(logoBytes);
    if (decoded == null) {
      return null;
    }

    var printable = _flattenLogoBackground(decoded);
    final maxWidth = switch (settings.paperSize) {
      PrinterPaperSize.mm58 => 140,
      PrinterPaperSize.mm80 => 200,
    };
    final maxHeight = switch (settings.paperSize) {
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

  /// Print receipt to Bluetooth or Windows thermal printer.
  Future<bool> printReceipt(TransactionOrder order) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final pdfBytes = await _ref
            .read(invoicePdfServiceProvider)
            .generateInvoicePdf(order);
        final settings = await PrinterSettings.load();
        final printers = await Printing.listPrinters();

        Printer? targetPrinter;
        if (settings.selectedWindowsPrinterName != null &&
            settings.selectedWindowsPrinterName!.isNotEmpty) {
          targetPrinter = printers
              .where((p) => p.name == settings.selectedWindowsPrinterName)
              .firstOrNull;
        }
        targetPrinter ??= printers.where((p) => p.isDefault).firstOrNull ??
            (printers.isNotEmpty ? printers.first : null);

        if (targetPrinter != null) {
          for (var i = 0; i < settings.copies; i++) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              onLayout: (format) async => pdfBytes,
              name: 'Struk_${order.invoiceNumber}',
            );
            if (i < settings.copies - 1) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
          return true;
        } else {
          return await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Struk_${order.invoiceNumber}',
          );
        }
      }

      final printerService = _ref.read(thermalPrinterServiceProvider);
      final connected = await printerService.connectionStatus;

      if (!connected) {
        final isBtEnabled = await printerService.bluetoothEnabled;
        if (!isBtEnabled) {
          await printerService.requestEnableBluetooth();
          await Future.delayed(const Duration(seconds: 1));
        }

        final settings = await PrinterSettings.load();
        if (settings.selectedPrinterAddress == null) {
          return false;
        }
        final result = await printerService.connect(
          settings.selectedPrinterAddress!,
        );
        if (!result) return false;
      }

      final bytes = await generateReceiptBytes(order);
      final settings = await PrinterSettings.load();

      for (var i = 0; i < settings.copies; i++) {
        await printerService.printBytes(bytes);
        if (i < settings.copies - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      return true;
    } catch (error) {
      debugPrint('Print error: $error');
      return false;
    }
  }

  /// Generate ESC/POS receipt bytes for kitchen ticket (KOT).
  Future<List<int>> generateKitchenReceiptBytes(TransactionOrder order) async {
    final settings = await PrinterSettings.load();
    final profile = await CapabilityProfile.load();
    final generator = Generator(settings.paperSize.paperSize, profile);

    List<int> bytes = [];

    // ── Reset & Font ─────────────────────────────────────────
    bytes += generator.reset();

    final codeTable = settings.codeTable.trim();
    if (codeTable.isNotEmpty) {
      bytes += generator.setGlobalCodeTable(codeTable);
    }

    bytes += generator.setGlobalFont(
      settings.fontMode.fontType,
      maxCharsPerLine: settings.charactersPerLine,
    );

    // ── Header ───────────────────────────────────────────────
    bytes += generator.text(
      '*** TIKET DAPUR (KOT) ***',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      maxCharsPerLine: settings.charactersPerLine,
    );
    bytes += generator.feed(1);

    final diningBanner = switch (order.diningOption) {
      DiningOption.takeAway => '*** TAKE AWAY (BUNGKUS) ***',
      DiningOption.delivery => '*** DELIVERY (ANTAR) ***',
      DiningOption.goFood => '*** ONLINE: GOFOOD ***',
      DiningOption.grabFood => '*** ONLINE: GRABFOOD ***',
      DiningOption.shopeeFood => '*** ONLINE: SHOPEEFOOD ***',
      DiningOption.custom => '*** PESANAN KHUSUS ***',
      DiningOption.dineIn => (order.tableNumber != null
          ? '*** MEJA ${order.tableNumber} ***'
          : '*** DINE IN ***'),
    };

    bytes += generator.text(
      diningBanner,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(1);

    bytes += generator.text(
      'No: ${order.invoiceNumber}',
      styles: const PosStyles(align: PosAlign.center),
    );

    final dateStr = order.createdAt != null
        ? _dateFormat.format(order.createdAt!)
        : _dateFormat.format(DateTime.now());
    bytes += generator.text(
      'Waktu: $dateStr',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (order.waiterName != null && order.waiterName!.isNotEmpty) {
      bytes += generator.text(
        'Waiter: ${order.waiterName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }
    if (order.cashierName != null && order.cashierName!.isNotEmpty) {
      bytes += generator.text(
        'Kasir: ${order.cashierName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text(
        'Pelanggan: ${order.customerName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    bytes += generator.hr(ch: '=');

    // ── Items ────────────────────────────────────────────────
    for (final item in order.items) {
      bytes += generator.text(
        '[ ${item.quantity}x ]  ${item.displayName}',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );

      if (item.isPackage && item.packageComponents.isNotEmpty) {
        for (final comp in item.packageComponents) {
          bytes += generator.text(
            '   + $comp',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
            ),
          );
        }
      }

      if (item.notes != null && item.notes!.trim().isNotEmpty) {
        bytes += generator.text(
          '  * REQ: ${item.notes} *',
          styles: const PosStyles(
            align: PosAlign.left,
            bold: true,
          ),
        );
      }
      bytes += generator.feed(1);
    }

    bytes += generator.hr(ch: '=');

    if (order.notes != null && order.notes!.trim().isNotEmpty) {
      bytes += generator.text(
        'CATATAN PESANAN:\n${order.notes}',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.hr(ch: '-');
    }

    final totalItems = order.items.fold(0, (sum, item) => sum + item.quantity);
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL ITEM',
        width: 8,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$totalItems Item',
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.feed(settings.feedLines > 0 ? settings.feedLines : 2);
    if (settings.autoCut) {
      bytes += generator.cut();
    }

    return bytes;
  }

  /// Print kitchen order ticket (KOT) to printer (Windows or Bluetooth).
  Future<bool> printKitchenReceipt(TransactionOrder order) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final pdfBytes = await _ref
            .read(invoicePdfServiceProvider)
            .generateKitchenReceiptPdf(order);
        final settings = await PrinterSettings.load();
        final printers = await Printing.listPrinters();

        Printer? targetPrinter;
        if (settings.selectedWindowsPrinterName != null &&
            settings.selectedWindowsPrinterName!.isNotEmpty) {
          targetPrinter = printers
              .where((p) => p.name == settings.selectedWindowsPrinterName)
              .firstOrNull;
        }
        targetPrinter ??= printers.where((p) => p.isDefault).firstOrNull ??
            (printers.isNotEmpty ? printers.first : null);

        if (targetPrinter != null) {
          await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (format) async => pdfBytes,
            name: 'Dapur_${order.invoiceNumber}',
          );
          return true;
        } else {
          return await Printing.layoutPdf(
            onLayout: (format) async => pdfBytes,
            name: 'Dapur_${order.invoiceNumber}',
          );
        }
      }

      final printerService = _ref.read(thermalPrinterServiceProvider);
      final connected = await printerService.connectionStatus;

      if (!connected) {
        final isBtEnabled = await printerService.bluetoothEnabled;
        if (!isBtEnabled) {
          await printerService.requestEnableBluetooth();
          await Future.delayed(const Duration(seconds: 1));
        }

        final settings = await PrinterSettings.load();
        if (settings.selectedPrinterAddress == null) {
          return false;
        }
        final result = await printerService.connect(
          settings.selectedPrinterAddress!,
        );
        if (!result) return false;
      }

      final bytes = await generateKitchenReceiptBytes(order);
      await printerService.printBytes(bytes);
      return true;
    } catch (error) {
      debugPrint('Print kitchen error: $error');
      return false;
    }
  }

  /// Print QR Code for table self-order.
  Future<bool> printTableQr({
    required String url,
    required String outletName,
    required String tableNumber,
  }) async {
    try {
      final printerService = _ref.read(thermalPrinterServiceProvider);
      final connected = await printerService.connectionStatus;

      if (!connected) {
        final settings = await PrinterSettings.load();
        if (settings.selectedPrinterAddress == null) {
          return false;
        }
        final result = await printerService.connect(
          settings.selectedPrinterAddress!,
        );
        if (!result) return false;
      }

      final settings = await PrinterSettings.load();
      final profile = await CapabilityProfile.load();
      final generator = Generator(settings.paperSize.paperSize, profile);

      List<int> bytes = [];
      bytes += generator.reset();
      
      // Header
      bytes += generator.text(
        outletName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'MEJA: $tableNumber',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.feed(1);

      // QR Code
      bytes += generator.qrcode(
        url,
        size: QRSize.size6,
        align: PosAlign.center,
      );
      bytes += generator.feed(1);

      bytes += generator.text(
        'Scan QR di atas untuk',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'melihat menu & pesan mandiri',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(settings.feedLines);
      if (settings.autoCut) {
        bytes += generator.cut();
      }

      await printerService.printBytes(bytes);
      return true;
    } catch (error) {
      debugPrint('Print QR error: $error');
      return false;
    }
  }
}
