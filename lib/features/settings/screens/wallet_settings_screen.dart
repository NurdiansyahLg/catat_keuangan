import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/wallet_settings_service.dart';

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  final _service = WalletSettingsService.instance;
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  static const _walletMeta = [
    (
      name: 'Dompet Utama',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF1A7A68),
      bgColor: Color(0xFFDEF2EC),
      desc: 'Dompet utama untuk transaksi sehari-hari',
    ),
    (
      name: 'Bank',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF2563EB),
      bgColor: Color(0xFFDBEAFE),
      desc: 'Rekening tabungan atau giro bank',
    ),
    (
      name: 'E-Wallet',
      icon: Icons.credit_card_outlined,
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFF3E8FF),
      desc: 'GoPay, OVO, Dana, ShopeePay, dsb.',
    ),
    (
      name: 'Tunai',
      icon: Icons.payments_outlined,
      color: Color(0xFF16A34A),
      bgColor: Color(0xFFDCFCE7),
      desc: 'Uang tunai di tangan / dompet fisik',
    ),
  ];

  @override
  void initState() {
    super.initState();
    for (final w in _walletMeta) {
      _controllers[w.name] = TextEditingController();
    }
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final balances = await _service.getAllInitialBalances();
    if (mounted) {
      setState(() {
        for (final w in _walletMeta) {
          final val = balances[w.name] ?? 0;
          _controllers[w.name]!.text = val == 0 ? '' : val.toString();
        }
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final w in _walletMeta) {
      final raw = _controllers[w.name]!.text.replaceAll('.', '').trim();
      final amount = int.tryParse(raw) ?? 0;
      await _service.setInitialBalance(w.name, amount);
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saldo awal berhasil disimpan!',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);
    final text = AppColors.bodyText(context);
    final sub = AppColors.subText(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saldo Awal Dompet',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.incomeContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Masukkan saldo awal untuk setiap dompet sebelum mulai mencatat transaksi. Saldo ini akan ditambahkan ke total saldo dompet Anda.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Wallet input fields
                      ..._walletMeta.map((w) => _WalletInputCard(
                            meta: w,
                            controller: _controllers[w.name]!,
                            sub: sub,
                            text: text,
                          )),
                    ],
                  ),
                ),

                // Save button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined,
                              color: Colors.white, size: 20),
                      label: Text(
                        _saving ? 'Menyimpan...' : 'Simpan Saldo Awal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFB0C4C1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WalletInputCard extends StatelessWidget {
  const _WalletInputCard({
    required this.meta,
    required this.controller,
    required this.sub,
    required this.text,
  });

  final ({
    String name,
    IconData icon,
    Color color,
    Color bgColor,
    String desc,
  }) meta;
  final TextEditingController controller;
  final Color sub, text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: meta.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 20, color: meta.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.desc,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: text,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
              prefixText: 'Rp ',
              prefixStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: meta.color,
              ),
              filled: true,
              fillColor: AppColors.bg(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: meta.color, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
