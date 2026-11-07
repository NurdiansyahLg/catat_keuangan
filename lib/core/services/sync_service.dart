import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/local/database_helper.dart';
import 'telegram_config_service.dart';
import 'telegram_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final DateTime? timestamp;

  const SyncResult({
    required this.success,
    required this.message,
    this.timestamp,
  });
}

class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastAutoSyncTime;

  bool get isSyncing => _isSyncing;

  /// Initialize connectivity listener for auto-sync
  void init() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        _triggerAutoSyncIfNeeded();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Trigger auto-sync if conditions are met
  Future<void> _triggerAutoSyncIfNeeded() async {
    final config = TelegramConfigService.instance;
    await config.init();

    if (!config.isConfigured || !config.autoSync) return;

    // Rate-limit auto-sync to at most once per 5 minutes to avoid spamming API
    if (_lastAutoSyncTime != null) {
      final difference = DateTime.now().difference(_lastAutoSyncTime!);
      if (difference.inMinutes < 5) return;
    }

    await performSync(isManual: false);
  }

  /// Perform synchronization (Backup to Telegram)
  Future<SyncResult> performSync({bool isManual = true}) async {
    if (_isSyncing) {
      return const SyncResult(
        success: false,
        message: 'Proses sinkronisasi sedang berjalan.',
      );
    }

    final config = TelegramConfigService.instance;
    await config.init();

    if (!config.isConfigured) {
      return const SyncResult(
        success: false,
        message: 'Telegram belum dikonfigurasi. Masukkan Bot Token & Chat ID.',
      );
    }

    // Check internet connection
    final connectivityResults = await Connectivity().checkConnectivity();
    final isOnline = connectivityResults.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      await config.updateSyncStatus(status: 'Gagal: Tidak ada koneksi internet');
      return const SyncResult(
        success: false,
        message: 'Tidak ada koneksi internet.',
      );
    }

    _isSyncing = true;
    try {
      final db = DatabaseHelper.instance;

      // Gather data from SQLite tables
      final categories = await db.query('categories');
      final transactions = await db.query('transactions');
      final budgets = await db.query('budgets');
      final debts = await db.query('debts');

      // Calculate totals for caption
      int totalIncome = 0;
      int totalExpense = 0;
      for (final tx in transactions) {
        final amount = (tx['amount'] as num?)?.toInt() ?? 0;
        final type = tx['type'] as String?;
        if (type == 'income') {
          totalIncome += amount;
        } else if (type == 'expense') {
          totalExpense += amount;
        }
      }
      final balance = totalIncome - totalExpense;

      final currencyFmt = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

      // Create JSON structure
      final backupData = {
        'version': 1,
        'app': 'Catat Keuangan',
        'exported_at': now.toIso8601String(),
        'summary': {
          'total_categories': categories.length,
          'total_transactions': transactions.length,
          'total_budgets': budgets.length,
          'total_debts': debts.length,
          'total_income': totalIncome,
          'total_expense': totalExpense,
          'balance': balance,
        },
        'data': {
          'categories': categories,
          'transactions': transactions,
          'budgets': budgets,
          'debts': debts,
        }
      };

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'catat_keuangan_backup_${DateFormat('yyyyMMdd_HHmmss').format(now)}.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backupData));

      // Caption message with Markdown formatting
      final caption = '''
📱 *Catat Keuangan - Backup Data*
📅 *Waktu:* `$dateStr`

📊 *Ringkasan Keuangan:*
• Total Pemasukan: `${currencyFmt.format(totalIncome)}`
• Total Pengeluaran: `${currencyFmt.format(totalExpense)}`
• Saldo Saat Ini: `${currencyFmt.format(balance)}`

📁 *Detail Data:*
• Transaksi: ${transactions.length} record
• Kategori: ${categories.length} item
• Hutang/Piutang: ${debts.length} record

✅ _Backup database otomatis berhasil diunggah\\._
''';

      // Send to Telegram
      final success = await TelegramService.instance.sendDocument(
        botToken: config.botToken,
        chatId: config.chatId,
        filePath: file.path,
        caption: caption,
        parseMode: 'Markdown',
      );

      // Clean up temp file
      if (file.existsSync()) {
        await file.delete();
      }

      if (success) {
        _lastAutoSyncTime = now;
        await config.updateSyncStatus(
          status: 'Terhubung & Tersinkronisasi',
          syncTime: now,
        );
        return SyncResult(
          success: true,
          message: 'Sinkronisasi ke Telegram berhasil!',
          timestamp: now,
        );
      } else {
        await config.updateSyncStatus(status: 'Gagal mengirim ke Telegram');
        return const SyncResult(
          success: false,
          message: 'Gagal mengirim data ke Telegram. Periksa Bot Token & Chat ID.',
        );
      }
    } catch (e) {
      await config.updateSyncStatus(status: 'Terjadi kesalahan: $e');
      return SyncResult(
        success: false,
        message: 'Kesalahan saat sinkronisasi: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }
}
