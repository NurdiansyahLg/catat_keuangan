import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/telegram_config_service.dart';
import '../../../core/services/telegram_service.dart';

class TelegramSettingsScreen extends StatefulWidget {
  const TelegramSettingsScreen({super.key});

  @override
  State<TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<TelegramSettingsScreen> {
  final _botTokenController = TextEditingController();
  final _chatIdController = TextEditingController();
  bool _obscureToken = true;
  bool _autoSync = true;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isConfigured = false;
  String _statusMessage = '';
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = TelegramConfigService.instance;
    await config.init();
    setState(() {
      _botTokenController.text = config.botToken;
      _chatIdController.text = config.chatId;
      _autoSync = config.autoSync;
      _isConfigured = config.isConfigured;
      _statusMessage = config.lastStatus;
      _lastSyncTime = config.lastSyncTime;
    });
  }

  Future<void> _testAndSaveConfig() async {
    final botToken = _botTokenController.text.trim();
    final chatId = _chatIdController.text.trim();

    if (botToken.isEmpty || chatId.isEmpty) {
      _showSnackBar('Mohon isi Bot Token dan Chat ID terlebih dahulu.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Test sending a test message
      final isConnected = await TelegramService.instance.testConnection(
        botToken: botToken,
        chatId: chatId,
      );

      if (isConnected) {
        final config = TelegramConfigService.instance;
        await config.saveConfig(
          botToken: botToken,
          chatId: chatId,
          autoSync: _autoSync,
        );
        await config.updateSyncStatus(status: 'Terhubung ke Telegram');

        await _loadConfig();
        if (mounted) {
          _showSnackBar('Berhasil terhubung ke Telegram! Pesan tes telah dikirim.');
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'Gagal terhubung. Pastikan Bot Token dan Chat ID benar, serta sudah menekan /start pada bot.',
            isError: true,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manualSync() async {
    if (!_isConfigured) {
      _showSnackBar('Konfigurasi Telegram terlebih dahulu.', isError: true);
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final result = await SyncService.instance.performSync(isManual: true);
      await _loadConfig();
      if (mounted) {
        _showSnackBar(result.message, isError: !result.success);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _clearConfig() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Konfigurasi?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Aplikasi tidak akan terhubung ke Telegram dan sinkronisasi otomatis akan dinonaktifkan.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await TelegramConfigService.instance.clearConfig();
      _botTokenController.clear();
      _chatIdController.clear();
      await _loadConfig();
      if (mounted) {
        _showSnackBar('Konfigurasi Telegram berhasil dihapus.');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: isError ? AppColors.expense : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);
    final sub = AppColors.subText(context);

    final lastSyncStr = _lastSyncTime != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(_lastSyncTime!)
        : 'Belum pernah';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Integrasi Telegram',
          style: GoogleFonts.plusJakartaSans(
            color: text,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Status Banner ──
            _StatusCard(
              isConfigured: _isConfigured,
              statusMessage: _statusMessage,
              lastSyncStr: lastSyncStr,
              surface: surface,
              text: text,
              sub: sub,
            ),
            const SizedBox(height: 20),

            // ── Form Input Card ──
            _SectionTitle(title: 'KONEKSI BOT TELEGRAM', text: text),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bot Token Field
                  Text('Bot Token',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: text,
                      )),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _botTokenController,
                    obscureText: _obscureToken,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: text),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 123456789:ABCdefGhIJKlmNoPQR...',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
                      filled: true,
                      fillColor: AppColors.bg(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureToken ? Icons.visibility_off : Icons.visibility,
                          color: sub,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureToken = !_obscureToken),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chat ID Field
                  Text('Chat ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: text,
                      )),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _chatIdController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: text),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 987654321',
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
                      filled: true,
                      fillColor: AppColors.bg(context),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testAndSaveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isConfigured ? 'Update & Tes Koneksi' : 'Tes & Simpan Koneksi',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  if (_isConfigured) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _clearConfig,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          side: const BorderSide(color: AppColors.expense),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Hapus Konfigurasi',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Auto Sync Switch ──
            _SectionTitle(title: 'SINKRONISASI OTOMATIS', text: text),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                title: Text(
                  'Auto-Sync saat Online',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
                subtitle: Text(
                  'Otomatis mengunggah backup ke Telegram saat HP terhubung ke internet.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
                ),
                activeThumbColor: AppColors.primary,
                value: _autoSync,
                onChanged: (val) async {
                  setState(() => _autoSync = val);
                  await TelegramConfigService.instance.setAutoSync(val);
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Manual Sync Action ──
            _SectionTitle(title: 'SINKRONISASI MANUAL', text: text),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.incomeContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.cloud_upload_outlined,
                      size: 22, color: AppColors.primary),
                ),
                title: Text(
                  'Sinkronkan Sekarang',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
                subtitle: Text(
                  'Ekspor dan kirim backup data terbaru ke Telegram secara manual.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
                ),
                trailing: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                onTap: _isSyncing ? null : _manualSync,
              ),
            ),
            const SizedBox(height: 20),

            // ── Tutorial Card ──
            _SectionTitle(title: 'PANDUAN PEMBUATAN BOT', text: text),
            const SizedBox(height: 10),
            _TutorialCard(surface: surface, text: text, sub: sub),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  STATUS CARD
// ══════════════════════════════════════════
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isConfigured,
    required this.statusMessage,
    required this.lastSyncStr,
    required this.surface,
    required this.text,
    required this.sub,
  });

  final bool isConfigured;
  final String statusMessage;
  final String lastSyncStr;
  final Color surface, text, sub;

  @override
  Widget build(BuildContext context) {
    final statusColor = isConfigured ? AppColors.income : AppColors.expense;
    final statusBg = isConfigured ? AppColors.incomeContainer : AppColors.expenseContainer;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isConfigured ? Icons.telegram_rounded : Icons.cloud_off_rounded,
              size: 28,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConfigured ? 'Terhubung' : 'Belum Terkonfigurasi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sync Terakhir: $lastSyncStr',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  SECTION TITLE
// ══════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.text});
  final String title;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  TUTORIAL CARD
// ══════════════════════════════════════════
class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.surface,
    required this.text,
    required this.sub,
  });

  final Color surface, text, sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepItem(
            number: '1',
            title: 'Buat Bot via BotFather',
            desc: 'Buka Telegram, cari bot @BotFather. Kirim pesan /newbot lalu ikuti petunjuk untuk membuat nama bot.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 12),
          _StepItem(
            number: '2',
            title: 'Dapatkan Bot Token',
            desc: 'BotFather akan memberikan HTTP API Token (contoh: 123456:ABC...). Salin token tersebut ke kolom Bot Token di atas.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 12),
          _StepItem(
            number: '3',
            title: 'Mulai Percakapan Bot',
            desc: 'Buka bot baru Anda di Telegram, lalu tekan tombol START atau kirim pesan /start agar bot diizinkan mengirim pesan ke Anda.',
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 12),
          _StepItem(
            number: '4',
            title: 'Dapatkan Chat ID Anda',
            desc: 'Cari bot @userinfobot di Telegram, lalu tekan /start. Bot akan membalas dengan ID Anda (contoh: 987654321). Salin angka tersebut ke kolom Chat ID di atas.',
            text: text,
            sub: sub,
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.number,
    required this.title,
    required this.desc,
    required this.text,
    required this.sub,
  });

  final String number, title, desc;
  final Color text, sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.incomeContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
