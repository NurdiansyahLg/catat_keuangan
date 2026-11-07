import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../budget/screens/budget_screen.dart';
import '../../transactions/screens/add_transaction_screen.dart';
import '../../settings/screens/wallet_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSeeAllTransactions});

  final VoidCallback? onSeeAllTransactions;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _txRepo = TransactionRepository();
  int _balance = 0;
  int _income = 0;
  int _expense = 0;
  List<TransactionModel> _recentTxs = [];
  Map<String, int> _walletBalances = {};
  String _topExpenseCategory = 'Makanan';
  int _topExpenseAmount = 0;
  List<Map<String, dynamic>> _last6Months = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final balance = await _txRepo.getTotalBalance();
    final walletBalances = await _txRepo.getWalletBalances();
    final summary = await _txRepo.getMonthlySummary(now.year, now.month);
    final recent = await _txRepo.getRecent(limit: 5);

    // Top category insight for this month
    final startOfMonth = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final endOfMonth = DateTime(now.year, now.month + 1).millisecondsSinceEpoch;
    String topCategory = 'Makanan';
    int topAmount = 0;

    try {
      final db = await DatabaseHelper.instance.database;
      final topCats = await db.rawQuery('''
        SELECT COALESCE(c.name, t.title) as name, SUM(t.amount) as total
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.type = 'expense' AND t.date >= ? AND t.date < ?
        GROUP BY COALESCE(c.name, t.title)
        ORDER BY total DESC
        LIMIT 1
      ''', [startOfMonth, endOfMonth]);

      if (topCats.isNotEmpty) {
        topCategory = (topCats.first['name'] as String?) ?? 'Makanan';
        topAmount = (topCats.first['total'] as int?) ?? 0;
      } else {
        // If no transactions this month, check all-time top expense or recent expense
        final allTimeTop = await db.rawQuery('''
          SELECT COALESCE(c.name, t.title) as name, SUM(t.amount) as total
          FROM transactions t
          LEFT JOIN categories c ON t.category_id = c.id
          WHERE t.type = 'expense'
          GROUP BY COALESCE(c.name, t.title)
          ORDER BY total DESC
          LIMIT 1
        ''');
        if (allTimeTop.isNotEmpty) {
          topCategory = (allTimeTop.first['name'] as String?) ?? 'Makanan';
          topAmount = (allTimeTop.first['total'] as int?) ?? 0;
        }
      }
    } catch (_) {}

    // Last 6 months trend
    final sixMonths = await _txRepo.getLast6MonthsSummary();

    if (mounted) {
      setState(() {
        _balance = balance;
        _walletBalances = walletBalances;
        _income = summary['income'] ?? 0;
        _expense = summary['expense'] ?? 0;
        _recentTxs = recent;
        _topExpenseCategory = topCategory;
        _topExpenseAmount = topAmount;
        _last6Months = sixMonths;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    const _DashboardHeader(),
                    const SizedBox(height: 16),
                    _BalanceCard(balance: _balance),
                    const SizedBox(height: 14),
                    _IncomeExpenseRow(income: _income, expense: _expense),
                    const SizedBox(height: 14),
                    _WalletsSection(walletBalances: _walletBalances),
                    const SizedBox(height: 14),
                    _SavingsRateCard(income: _income, expense: _expense),
                    const SizedBox(height: 14),
                    const _TargetTabunganCard(),
                    const SizedBox(height: 18),
                    _InsightPengeluaranSection(
                      categoryName: _topExpenseCategory,
                      amount: _topExpenseAmount,
                    ),
                    const SizedBox(height: 18),
                    _TrendCard(
                      monthlyData: _last6Months,
                      currentIncome: _income,
                      currentExpense: _expense,
                    ),
                    const SizedBox(height: 20),
                    _TransactionSection(
                      recentTxs: _recentTxs,
                      onSeeAll: widget.onSeeAllTransactions ?? () {},
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          if (added == true) _loadData();
        },
        tooltip: 'Tambah transaksi',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  HELPER FORMATTERS
// ══════════════════════════════════════════
String _formatRupiah(int v) {
  final abs = v.abs().toString();
  final buf = StringBuffer();
  int c = 0;
  for (int i = abs.length - 1; i >= 0; i--) {
    if (c > 0 && c % 3 == 0) buf.write('.');
    buf.write(abs[i]);
    c++;
  }
  final sign = v < 0 ? '-' : '';
  return '$sign Rp ${buf.toString().split('').reversed.join('')}';
}

String _formatCompact(int v) {
  final abs = v.abs();
  if (abs >= 1000000) {
    final jt = abs / 1000000;
    return 'Rp ${jt.toStringAsFixed(abs % 1000000 == 0 ? 0 : 1)}jt';
  } else if (abs >= 1000) {
    return 'Rp ${(abs / 1000).round()}rb';
  }
  return 'Rp $abs';
}

// ══════════════════════════════════════════
//  1. HEADER
// ══════════════════════════════════════════
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);

    return Row(
      children: [
        // Avatar icon
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border(context),
              width: 1.2,
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uang lebih tertata.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Dompetin',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: text,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        // Bell icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border(context),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF4B5563),
            size: 20,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  2. BALANCE CARD (Total Saldo)
// ══════════════════════════════════════════
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Saldo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRupiah(balance),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  3. INCOME / EXPENSE ROW
// ══════════════════════════════════════════
class _IncomeExpenseRow extends StatelessWidget {
  const _IncomeExpenseRow({required this.income, required this.expense});
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);

    return Row(
      children: [
        // Pemasukan
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDEF2EC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_rounded,
                        size: 14,
                        color: Color(0xFF1A7A68),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pemasukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatRupiah(income),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Pengeluaran
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDECEB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.south_rounded,
                        size: 14,
                        color: Color(0xFFD94040),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pengeluaran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatRupiah(expense),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  4. SALDO PER DOMPET (Vertical List in Card)
// ══════════════════════════════════════════
class _WalletsSection extends StatelessWidget {
  const _WalletsSection({required this.walletBalances});
  final Map<String, int> walletBalances;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);

    final wallets = [
      (
        'Dompet Utama',
        Icons.account_balance_wallet_outlined,
        const Color(0xFF1A7A68),
        const Color(0xFFDEF2EC),
        walletBalances['Dompet Utama'] ?? 0,
      ),
      (
        'Tunai',
        Icons.payments_outlined,
        const Color(0xFF16A34A),
        const Color(0xFFDCFCE7),
        walletBalances['Tunai'] ?? walletBalances['Cash'] ?? 0,
      ),
      (
        'Bank',
        Icons.account_balance_outlined,
        const Color(0xFF2563EB),
        const Color(0xFFDBEAFE),
        walletBalances['Bank'] ?? 0,
      ),
      (
        'E-Wallet',
        Icons.credit_card_outlined,
        const Color(0xFF7C3AED),
        const Color(0xFFF3E8FF),
        walletBalances['E-Wallet'] ?? 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Text(
              'Saldo per Dompet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletSettingsScreen()),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 19,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Card container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: List.generate(wallets.length, (i) {
              final w = wallets[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i < wallets.length - 1 ? 16 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: w.$4,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(w.$2, size: 20, color: w.$3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      w.$1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRupiah(w.$5),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  5. SAVINGS RATE CARD
// ══════════════════════════════════════════
class _SavingsRateCard extends StatelessWidget {
  const _SavingsRateCard({required this.income, required this.expense});
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final savings = income - expense;
    final rate =
        income > 0 ? ((savings / income) * 100).clamp(0, 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFB89339),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Rate',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rasio tabungan bulan ini',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$rate%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  6. BUAT TARGET TABUNGAN CARD
// ══════════════════════════════════════════
class _TargetTabunganCard extends StatelessWidget {
  const _TargetTabunganCard();

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFDEF2EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.flag_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Target Tabungan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pantau dana darurat, liburan, atau barang impian.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  7. INSIGHT PENGELUARAN SECTION
// ══════════════════════════════════════════
class _InsightPengeluaranSection extends StatelessWidget {
  const _InsightPengeluaranSection({
    required this.categoryName,
    required this.amount,
  });

  final String categoryName;
  final int amount;

  static IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('makan') || n.contains('restoran') || n.contains('kuliner')) return Icons.restaurant_outlined;
    if (n.contains('transport') || n.contains('bensin') || n.contains('motor') || n.contains('mobil')) return Icons.directions_car_outlined;
    if (n.contains('belanja') || n.contains('shopping')) return Icons.shopping_bag_outlined;
    if (n.contains('kesehatan') || n.contains('dokter') || n.contains('obat')) return Icons.local_hospital_outlined;
    if (n.contains('pendidikan') || n.contains('sekolah') || n.contains('kursus')) return Icons.school_outlined;
    if (n.contains('rumah') || n.contains('kontrakan') || n.contains('kos')) return Icons.home_outlined;
    if (n.contains('hiburan') || n.contains('film') || n.contains('game')) return Icons.movie_outlined;
    if (n.contains('gaji') || n.contains('salary')) return Icons.attach_money_rounded;
    if (n.contains('bisnis')) return Icons.business_center_outlined;
    if (n.contains('investasi') || n.contains('tabungan')) return Icons.savings_outlined;
    return Icons.receipt_long_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insight Pengeluaran',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: text,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEF2EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(categoryName),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName.isNotEmpty
                          ? '$categoryName paling besar'
                          : 'Makanan paling besar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatCompact(amount),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  8. TREN TABUNGAN (6 Bulan Terakhir)
// ══════════════════════════════════════════
class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.monthlyData,
    required this.currentIncome,
    required this.currentExpense,
  });

  final List<Map<String, dynamic>> monthlyData;
  final int currentIncome;
  final int currentExpense;

  static const _monthNames = [
    'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
    'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'
  ];

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);
    final sub = const Color(0xFF6B7280);

    final now = DateTime.now();
    final currentNet = currentIncome - currentExpense;

    // Build 6 items
    final List<Map<String, dynamic>> items = [];
    if (monthlyData.length >= 6) {
      items.addAll(monthlyData.sublist(monthlyData.length - 6));
    } else {
      // Fallback: past 5 months + current
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i);
        items.add({
          'month': d,
          'income': i == 0 ? currentIncome : 0,
          'expense': i == 0 ? currentExpense : 0,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tren Tabungan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const Spacer(),
            Text(
              '6 Bulan Terakhir',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              // Inner chart container
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Builder(builder: (context) {
                  // Calculate max abs net for proportional bars
                  final maxAbs = items.fold<int>(1, (m, item) {
                    final inc = (item['income'] as int?) ?? 0;
                    final exp = (item['expense'] as int?) ?? 0;
                    final absNet = (inc - exp).abs();
                    return absNet > m ? absNet : m;
                  });
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final d = item['month'] as DateTime? ?? DateTime.now();
                      final inc = (item['income'] as int?) ?? 0;
                      final exp = (item['expense'] as int?) ?? 0;
                      final net = inc - exp;
                      final isCurrentMonth = i == items.length - 1;
                      final monthLabel = _monthNames[d.month - 1];

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Center(
                              child: _buildProportionalBar(net, maxAbs),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            monthLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: isCurrentMonth
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isCurrentMonth
                                  ? AppColors.primary
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      );
                    }),
                  );
                }),
              ),
              const SizedBox(height: 12),
              // Bottom status row
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentNet < 0
                          ? const Color(0xFFD94040)
                          : (currentNet > 0
                              ? const Color(0xFF1A7A68)
                              : const Color(0xFF9CA3AF)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentNet < 0
                        ? 'Bulan ini minus -${_formatCompact(currentNet.abs())}'
                        : (currentNet > 0
                            ? 'Bulan ini surplus +${_formatCompact(currentNet)}'
                            : 'Bulan ini seimbang Rp 0'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: currentNet < 0
                          ? const Color(0xFFD94040)
                          : (currentNet > 0
                              ? const Color(0xFF1A7A68)
                              : const Color(0xFF4B5563)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Saldo bersih',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: sub,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProportionalBar(int net, int maxAbs) {
    const maxHeight = 50.0;
    const minHeight = 4.0;
    final ratio = maxAbs > 0 ? net.abs() / maxAbs : 0.0;
    final height = net == 0 ? minHeight : (minHeight + (maxHeight - minHeight) * ratio);

    if (net < 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFD94040),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    } else if (net > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    } else {
      return Container(
        width: 14,
        height: minHeight,
        decoration: BoxDecoration(
          color: const Color(0xFF9CA3AF),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
  }
}

// ══════════════════════════════════════════
//  9. TRANSAKSI TERBARU SECTION
// ══════════════════════════════════════════
class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.recentTxs,
    required this.onSeeAll,
  });
  final List<TransactionModel> recentTxs;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.bodyText(context);
    final sub = const Color(0xFF6B7280);
    final surface = AppColors.surface(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Transaksi Terbaru',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: text,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentTxs.isEmpty)
          const DashedBorderCard()
        else
          Column(
            children: recentTxs.map((tx) {
              final isExpense = tx.isExpense;
              final prefix = isExpense ? '- ' : '+ ';
              final amountColor =
                  isExpense ? const Color(0xFFD94040) : const Color(0xFF1A7A68);
              final iconBg =
                  isExpense ? const Color(0xFFFDECEB) : const Color(0xFFDEF2EC);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isExpense
                            ? Icons.south_rounded
                            : Icons.north_rounded,
                        size: 16,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.wallet,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$prefix${_formatRupiah(tx.amount)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  DASHED BORDER EMPTY CARD
// ══════════════════════════════════════════
class DashedBorderCard extends StatelessWidget {
  const DashedBorderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: const Color(0xFFCDD5D4),
        radius: 16,
        dashWidth: 6,
        dashGap: 4,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bg(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 26,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum ada transaksi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.bodyText(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Catat pengeluaran atau pemasukan\npertama Anda hari ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final extracted = metric.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extracted, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
