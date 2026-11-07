import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/theme_controller.dart';
import '../../../data/helpers/csv_exporter.dart';
import '../../../data/local/database_helper.dart';

import '../../../core/services/telegram_config_service.dart';
import 'telegram_settings_screen.dart';
import 'wallet_settings_screen.dart';

import '../../categories/screens/categories_screen.dart';
import '../../debts/screens/debt_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);
    final sub = AppColors.subText(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Header ──
            _Header(text: text, sub: sub),
            const SizedBox(height: 24),

            // ── Tema ──
            _SectionTitle(title: 'Tampilan', text: text),
            const SizedBox(height: 10),
            _ThemeCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 20),

            // ── Master Data & Keuangan ──
            _SectionTitle(title: 'Keuangan & Data', text: text),
            const SizedBox(height: 10),
            _WalletInitialCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 10),
            _CategoryCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 10),
            _DebtCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 20),

            // ── Integrasi & Cloud ──
            _SectionTitle(title: 'Integrasi & Cloud', text: text),
            const SizedBox(height: 10),
            _TelegramCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 20),

            // ── Informasi Aplikasi ──
            _SectionTitle(title: 'Tentang', text: text),
            const SizedBox(height: 10),
            _InfoCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 20),

            // ── Export ──
            _SectionTitle(title: 'Export', text: text),
            const SizedBox(height: 10),
            _ExportCard(surface: surface, text: text, sub: sub),
            const SizedBox(height: 20),

            // ── Data Berbahaya ──
            _SectionTitle(title: 'Data', text: text),
            const SizedBox(height: 10),
            _DangerCard(surface: surface, text: text),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════
class _Header extends StatelessWidget {
  const _Header({required this.text, required this.sub});
  final Color text, sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pengaturan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28, fontWeight: FontWeight.w800, color: text,
            )),
        const SizedBox(height: 4),
        Text('Sesuaikan preferensi aplikasi',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: sub)),
      ],
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
      child: Text(title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.primary, letterSpacing: 1.2,
          )),
    );
  }
}

// ══════════════════════════════════════════
//  THEME CARD
// ══════════════════════════════════════════
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.surface,
    required this.text,
    required this.sub,
  });
  final Color surface, text, sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(16),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (_, mode, __) {
          return Column(
            children: [
              _ThemeOption(
                icon: Icons.light_mode_outlined,
                label: 'Mode Terang',
                desc: 'Tampilan cerah dengan latar putih',
                selected: mode == ThemeMode.light,
                surface: surface,
                text: text,
                sub: sub,
                onTap: () => ThemeController.instance.setMode(ThemeMode.light),
                isFirst: true,
              ),
              _Divider(surface: surface),
              _ThemeOption(
                icon: Icons.dark_mode_outlined,
                label: 'Mode Gelap',
                desc: 'Tampilan gelap, ramah mata malam hari',
                selected: mode == ThemeMode.dark,
                surface: surface,
                text: text,
                sub: sub,
                onTap: () => ThemeController.instance.setMode(ThemeMode.dark),
              ),
              _Divider(surface: surface),
              _ThemeOption(
                icon: Icons.phone_android_outlined,
                label: 'Ikuti Sistem',
                desc: 'Otomatis sesuai pengaturan HP',
                selected: mode == ThemeMode.system,
                surface: surface,
                text: text,
                sub: sub,
                onTap: () => ThemeController.instance.setMode(ThemeMode.system),
                isLast: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.surface,
    required this.text,
    required this.sub,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label, desc;
  final bool selected, isFirst, isLast;
  final Color surface, text, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.incomeContainer
                    : AppColors.bg(context),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? AppColors.primary : sub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: text,
                      )),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: sub)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 13),
              )
            else
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: sub.withValues(alpha: 0.5)),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.surface});
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 70),
      color: AppColors.border(context),
    );
  }
}

// ══════════════════════════════════════════
//  INFO CARD
// ══════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.surface,
    required this.text,
    required this.sub,
  });
  final Color surface, text, sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.info_outline_rounded,
            label: 'Versi Aplikasi',
            value: 'v1.0.0',
            text: text, sub: sub, isFirst: true,
          ),
          _Divider(surface: surface),
          _InfoTile(
            icon: Icons.storage_outlined,
            label: 'Database',
            value: 'SQLite (sqflite)',
            text: text, sub: sub,
          ),
          _Divider(surface: surface),
          _InfoTile(
            icon: Icons.code_outlined,
            label: 'Framework',
            value: 'Flutter',
            text: text, sub: sub, isLast: true,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.text,
    required this.sub,
    this.isFirst = false,
    this.isLast = false,
  });
  final IconData icon;
  final String label, value;
  final Color text, sub;
  final bool isFirst, isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.bg(context),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w500, color: text)),
          ),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: sub)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  EXPORT CARD
// ══════════════════════════════════════════
class _ExportCard extends StatefulWidget {
  const _ExportCard({
    required this.surface,
    required this.text,
    required this.sub,
  });
  final Color surface, text, sub;

  @override
  State<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<_ExportCard> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.surface, borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _exporting ? null : _export,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: _exporting
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary),
                      )
                    : const Icon(Icons.download_rounded,
                        size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export ke CSV',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: widget.text,
                        )),
                    const SizedBox(height: 2),
                    Text('Bagikan data transaksi sebagai file .csv',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: widget.sub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: widget.sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await CsvExporter.exportAndShare(context);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

// ══════════════════════════════════════════
//  DANGER CARD
// ══════════════════════════════════════════
class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.surface, required this.text});
  final Color surface, text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showResetDialog(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.expenseContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.delete_sweep_outlined,
                    size: 20, color: AppColors.expense),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reset Data Transaksi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.expense,
                        )),
                    const SizedBox(height: 2),
                    Text('Hapus semua riwayat transaksi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.expense.withValues(alpha: 0.7),
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.expense, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset Data?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Semua transaksi akan dihapus secara permanen. Kategori tidak akan terdampak.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = await DatabaseHelper.instance.database;
              await db.delete('transactions');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semua transaksi berhasil dihapus.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Hapus Semua',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.expense, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  TELEGRAM CARD
// ══════════════════════════════════════════
class _TelegramCard extends StatefulWidget {
  const _TelegramCard({
    required this.surface,
    required this.text,
    required this.sub,
  });
  final Color surface, text, sub;

  @override
  State<_TelegramCard> createState() => _TelegramCardState();
}

class _TelegramCardState extends State<_TelegramCard> {
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final config = TelegramConfigService.instance;
    await config.init();
    if (mounted) {
      setState(() => _isConfigured = config.isConfigured);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TelegramSettingsScreen()),
          );
          _checkStatus();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.telegram_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sinkronisasi Telegram',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.text,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      _isConfigured
                          ? 'Status: Terhubung & Auto-Sync aktif'
                          : 'Hubungkan Bot Telegram untuk backup otomatis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: widget.sub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: widget.sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  WALLET INITIAL BALANCE CARD
// ══════════════════════════════════════════
class _WalletInitialCard extends StatelessWidget {
  const _WalletInitialCard({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WalletSettingsScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Awal Dompet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Atur saldo awal untuk tiap dompet & akun',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  CATEGORY CARD
// ══════════════════════════════════════════
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.category_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kategori Transaksi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: text,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Kelola kategori pengeluaran & pemasukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  DEBT CARD
// ══════════════════════════════════════════
class _DebtCard extends StatelessWidget {
  const _DebtCard({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DebtScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.handshake_rounded,
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catatan Hutang & Piutang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: text,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Kelola catatan pinjaman & jatuh tempo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: sub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}





