import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _txRepo = TransactionRepository();
  final _catRepo = CategoryRepository();

  int _selectedPeriod = 1; // 0=Minggu, 1=Bulan, 2=3 Bulan, 3=Tahun
  final _periods = ['Minggu ini', 'Bulan ini', '3 Bulan', 'Tahun ini'];

  // Data
  int _income = 0, _expense = 0;
  List<Map<String, dynamic>> _monthlyData = [];
  List<_CatData> _categoryData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    return switch (_selectedPeriod) {
      0 => DateTimeRange(
          start: now.subtract(const Duration(days: 7)), end: now),
      1 => DateTimeRange(start: DateTime(now.year, now.month), end: now),
      2 => DateTimeRange(
          start: DateTime(now.year, now.month - 2), end: now),
      _ => DateTimeRange(start: DateTime(now.year), end: now),
    };
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final r = _range;
    final monthly = await _txRepo.getLast6MonthsSummary();
    final catRaw = await _txRepo.getCategoryExpenses(r.start, r.end);
    final allCats = await _catRepo.getAll();

    // Summary for selected period
    int inc = 0, exp = 0;
    for (final m in monthly) {
      final d = m['month'] as DateTime;
      if (!d.isBefore(r.start) && !d.isAfter(r.end)) {
        inc += (m['income'] as int);
        exp += (m['expense'] as int);
      }
    }

    // Recalculate for current period properly
    final txs = await _txRepo.getByDateRange(r.start, r.end);
    inc = 0; exp = 0;
    for (final tx in txs) {
      if (tx.isExpense) { exp += tx.amount; }
      else { inc += tx.amount; }
    }

    // Category data
    final catData = <_CatData>[];
    for (final row in catRaw) {
      final catId = row['category_id'] as int?;
      final total = (row['total'] as int?) ?? 0;
      final cat = catId != null
          ? allCats.where((c) => c.id == catId).firstOrNull
          : null;
      catData.add(_CatData(
        name: cat?.name ?? (row['title'] as String? ?? '?'),
        amount: total,
        color: cat?.color ?? const Color(0xFF9CA3AF),
      ));
    }

    if (mounted) {
      setState(() {
        _income = inc;
        _expense = exp;
        _monthlyData = monthly;
        _categoryData = catData;
        _loading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────
  String _fmt(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(s[i]);
      c++;
    }
    return 'Rp ${buf.toString().split('').reversed.join('')}';
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','Mei','Jun',
    'Jul','Agu','Sep','Okt','Nov','Des',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        elevation: 0,
        title: Text(
          'Laporan',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.bodyText(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface(context), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: Color(0xFF6B7280), size: 20),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Period Filter ──
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _periods.length,
              itemBuilder: (_, i) {
                final sel = _selectedPeriod == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPeriod = i);
                    _loadData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _periods[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _income == 0 && _expense == 0
                    ? _EmptyReport()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // ── Summary Row ──
                          _SummaryRow(
                            income: _income,
                            expense: _expense,
                            fmt: _fmt,
                          ),
                          const SizedBox(height: 16),

                          // ── Bar Chart ──
                          _BarChartCard(
                            data: _monthlyData,
                            months: _months,
                          ),
                          const SizedBox(height: 16),

                          // ── Category Pie ──
                          if (_categoryData.isNotEmpty)
                            _CategoryPieCard(
                              data: _categoryData,
                              fmt: _fmt,
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
//  DATA CLASS
// ══════════════════════════════════════════
class _CatData {
  const _CatData({
    required this.name,
    required this.amount,
    required this.color,
  });
  final String name;
  final int amount;
  final Color color;
}

// ══════════════════════════════════════════
//  EMPTY REPORT
// ══════════════════════════════════════════
class _EmptyReport extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppColors.incomeContainer, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 42, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('Belum ada data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.bodyText(context),
                )),
            const SizedBox(height: 8),
            Text(
              'Tambahkan transaksi terlebih dahulu\nuntuk melihat laporan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: const Color(0xFF9CA3AF), height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  SUMMARY ROW
// ══════════════════════════════════════════
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.income,
    required this.expense,
    required this.fmt,
  });
  final int income, expense;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Pemasukan',
            value: fmt(income),
            color: AppColors.income,
            bgColor: AppColors.incomeContainer,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Pengeluaran',
            value: fmt(expense),
            color: AppColors.expense,
            bgColor: AppColors.expenseContainer,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Selisih',
            value: fmt(net),
            color: net >= 0 ? AppColors.primary : AppColors.expense,
            bgColor: net >= 0
                ? AppColors.incomeContainer
                : AppColors.expenseContainer,
            icon: net >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });
  final String label, value;
  final Color color, bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: const Color(0xFF9CA3AF),
              )),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: color,
              ),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  BAR CHART (6 Bulan)
// ══════════════════════════════════════════
class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.data, required this.months});
  final List<Map<String, dynamic>> data;
  final List<String> months;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxVal = data.fold<double>(0, (m, d) {
      final inc = (d['income'] as int).toDouble();
      final exp = (d['expense'] as int).toDouble();
      return [m, inc, exp].reduce((a, b) => a > b ? a : b);
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tren 6 Bulan',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.bodyText(context),
              )),
          const SizedBox(height: 4),
          Row(
            children: [
              _Legend(color: AppColors.income, label: 'Pemasukan'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.expense, label: 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 100 : maxVal * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx >= data.length) return const SizedBox();
                        final d = data[idx]['month'] as DateTime;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(months[d.month - 1],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF),
                              )),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xFFE5E7EB),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) {
                  final d = data[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (d['income'] as int).toDouble(),
                        color: AppColors.income,
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: (d['expense'] as int).toDouble(),
                        color: AppColors.expense,
                        width: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    barsSpace: 4,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: const Color(0xFF9CA3AF),
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  PIE CHART — Category Breakdown
// ══════════════════════════════════════════
class _CategoryPieCard extends StatefulWidget {
  const _CategoryPieCard({required this.data, required this.fmt});
  final List<_CatData> data;
  final String Function(int) fmt;

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.data.fold<int>(0, (s, d) => s + d.amount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pengeluaran per Kategori',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.bodyText(context),
              )),
          const SizedBox(height: 16),
          Row(
            children: [
              // Pie chart
              SizedBox(
                width: 140, height: 140,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (_, res) {
                        setState(() {
                          _touched = res?.touchedSection?.touchedSectionIndex ?? -1;
                        });
                      },
                    ),
                    sections: List.generate(widget.data.length, (i) {
                      final d = widget.data[i];
                      final pct = total > 0 ? (d.amount / total * 100) : 0.0;
                      final isTouched = _touched == i;
                      return PieChartSectionData(
                        value: d.amount.toDouble(),
                        color: d.color,
                        radius: isTouched ? 60 : 50,
                        title: isTouched
                            ? '${pct.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    }),
                    centerSpaceRadius: 28,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Column(
                  children: widget.data.map((d) {
                    final pct = total > 0
                        ? (d.amount / total * 100).toStringAsFixed(0)
                        : '0';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: d.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(d.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, color: AppColors.bodyText(context),
                                ),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('$pct%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: const Color(0xFF9CA3AF),
                              )),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
