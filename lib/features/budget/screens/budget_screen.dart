import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/category_repository.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _budgetRepo = BudgetRepository();
  final _catRepo = CategoryRepository();

  late int _month;
  late int _year;
  List<BudgetModel> _budgets = [];
  bool _loading = true;

  static const _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final budgets = await _budgetRepo.getMonthlyBudgets(_month, _year);
    if (mounted) setState(() { _budgets = budgets; _loading = false; });
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) { _month = 12; _year--; } else { _month--; }
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
    setState(() {
      if (_month == 12) { _month = 1; _year++; } else { _month++; }
    });
    _loadData();
  }

  String _fmtRp(int v) {
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

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);
    final sub = AppColors.subText(context);
    final now = DateTime.now();
    final isCurrentMonth = _month == now.month && _year == now.year;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Text('Budget Bulanan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22, fontWeight: FontWeight.w800, color: text,
                      )),
                  const Spacer(),
                  IconButton(
                    onPressed: _showAddDialog,
                    icon: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 20),
                    ),
                    tooltip: 'Tambah Budget',
                  ),
                ],
              ),
            ),

            // ── Month navigator ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left_rounded),
                      iconSize: 22,
                    ),
                    Text(
                      '${_monthNames[_month]} $_year',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700, color: text,
                      ),
                    ),
                    IconButton(
                      onPressed: isCurrentMonth ? null : _nextMonth,
                      icon: Icon(Icons.chevron_right_rounded,
                          color: isCurrentMonth
                              ? sub.withValues(alpha: 0.3)
                              : null),
                      iconSize: 22,
                    ),
                  ],
                ),
              ),
            ),

            // ── Budget list ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _budgets.isEmpty
                      ? _EmptyBudget(sub: sub, onAdd: _showAddDialog)
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _budgets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _BudgetCard(
                              budget: _budgets[i],
                              surface: surface,
                              text: text,
                              sub: sub,
                              fmtRp: _fmtRp,
                              onDelete: () async {
                                await _budgetRepo.delete(_budgets[i].id!);
                                _loadData();
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final cats = await _catRepo.getByType('expense');
    if (!mounted) return;

    CategoryModel? selected;
    final amountCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, ss) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tambah Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.bodyText(context),
                  )),
              const SizedBox(height: 16),

              // Category picker
              Text('Kategori Pengeluaran',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.subText(context),
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: cats.map((c) {
                  final sel = selected?.id == c.id;
                  return GestureDetector(
                    onTap: () => ss(() => selected = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary
                            : AppColors.bg(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? Colors.white
                                : AppColors.bodyText(context),
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Amount
              Text('Limit Budget (Rp)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.subText(context),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'cth: 500000',
                  hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppColors.subText(context)),
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: AppColors.bg(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final cat = selected;
                    final amount =
                        int.tryParse(amountCtrl.text.replaceAll('.', ''));
                    if (cat == null || amount == null || amount <= 0) return;

                    await _budgetRepo.upsert(BudgetModel(
                      categoryId: cat.id!,
                      categoryName: cat.name,
                      amount: amount,
                      month: _month,
                      year: _year,
                      createdAt: DateTime.now(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Simpan Budget',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  BUDGET CARD
// ══════════════════════════════════════════
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.surface,
    required this.text,
    required this.sub,
    required this.fmtRp,
    required this.onDelete,
  });

  final BudgetModel budget;
  final Color surface, text, sub;
  final String Function(int) fmtRp;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final over = budget.isOverBudget;
    final barColor = over
        ? AppColors.expense
        : budget.progress > 0.8
            ? AppColors.savings
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: over
            ? Border.all(
                color: AppColors.expense.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(budget.categoryName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700, color: text,
                    )),
              ),
              if (over)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.expenseContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Melebihi Limit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      )),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Hapus Budget',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      content: Text(
                        'Hapus budget untuk kategori "${budget.categoryName}"?',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Hapus',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.red, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) onDelete();
                },
                child: Icon(Icons.delete_outline_rounded, size: 18, color: sub),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budget.progress,
              minHeight: 8,
              backgroundColor: AppColors.bg(context),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),

          // Amount info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${fmtRp(budget.spent)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: sub,
                ),
              ),
              Text(
                over
                    ? 'Lebih ${fmtRp(budget.spent - budget.amount)}'
                    : 'Sisa ${fmtRp(budget.remaining)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: over ? AppColors.expense : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Budget: ${fmtRp(budget.amount)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════
class _EmptyBudget extends StatelessWidget {
  const _EmptyBudget({required this.sub, required this.onAdd});
  final Color sub;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                color: AppColors.incomeContainer, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings_outlined,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Belum ada budget',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.bodyText(context),
                )),
            const SizedBox(height: 6),
            Text('Tap + untuk tambah limit pengeluaran per kategori',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: sub, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Tambah Budget',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: Colors.white,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
