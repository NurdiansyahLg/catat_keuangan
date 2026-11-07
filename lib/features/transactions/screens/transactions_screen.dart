import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import 'add_transaction_screen.dart';
import '../../reports/screens/reports_screen.dart';

// ══════════════════════════════════════════
//  Data Model (dummy)
// ══════════════════════════════════════════
class _TxItem {
  const _TxItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    required this.icon,
    this.tx,
  });

  final int? id;
  final String title;
  final String subtitle;
  final int amount; // positif = pemasukan, negatif = pengeluaran
  final String time;
  final IconData icon;
  final TransactionModel? tx; // full model for edit
}

class _TxGroup {
  const _TxGroup({
    required this.label,
    required this.total,
    required this.items,
  });

  final String label;
  final int total;
  final List<_TxItem> items;
}

// Transaksi dimuat dari database
// Tidak ada data statis di sini

// ══════════════════════════════════════════
//  Helper: format Rupiah
// ══════════════════════════════════════════
String _formatRupiah(int amount) {
  final abs = amount.abs().toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = abs.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write('.');
    buffer.write(abs[i]);
    count++;
  }
  return 'Rp ${buffer.toString().split('').reversed.join('')}';
}

// ══════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.onOpenReports});

  final VoidCallback? onOpenReports;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _Period { all, today, week, month, year }

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  final _txRepo = TransactionRepository();
  List<_TxGroup> _groups = [];
  List<_TxGroup> _allGroups = []; // source of truth
  _Period _activePeriod = _Period.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _groups = List.from(_allGroups));
      return;
    }
    final filtered = _allGroups
        .map((g) {
          final items = g.items
              .where((i) =>
                  i.title.toLowerCase().contains(q) ||
                  i.subtitle.toLowerCase().contains(q))
              .toList();
          if (items.isEmpty) return null;
          final total = items.fold<int>(0, (s, i) => s + i.amount);
          return _TxGroup(label: g.label, total: total, items: items);
        })
        .whereType<_TxGroup>()
        .toList();
    setState(() => _groups = filtered);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _searchController.clear();
    final now = DateTime.now();

    // Build date range from period
    DateTime? start;
    DateTime? end;
    switch (_activePeriod) {
      case _Period.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      case _Period.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      case _Period.month:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case _Period.year:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
      case _Period.all:
        break;
    }

    final txList = start != null
        ? await _txRepo.getByDateRange(start, end!)
        : await _txRepo.getAll();

    // Group by date
    final Map<String, _TxGroup> groupMap = {};
    for (final tx in txList) {
      final key = _dateKey(tx.date);
      if (!groupMap.containsKey(key)) {
        groupMap[key] = _TxGroup(
          label: _dateLabel(tx.date),
          total: 0,
          items: [],
        );
      }
      final group = groupMap[key]!;
      final signed = tx.isExpense ? -tx.amount : tx.amount;
      groupMap[key] = _TxGroup(
        label: group.label,
        total: group.total + signed,
        items: [
          ...group.items,
          _TxItem(
            id: tx.id,
            title: tx.title,
            subtitle: tx.notes ?? '',
            amount: signed,
            time: '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}',
            icon: Icons.receipt_long_outlined,
            tx: tx,
          ),
        ],
      );
    }

    if (mounted) {
      setState(() {
        _allGroups = groupMap.values.toList();
        _groups = List.from(_allGroups);
        _loading = false;
      });
    }
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Hari Ini';
    if (diff == 1) return 'Kemarin';
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _deleteTransaction(int id) async {
    await _txRepo.delete(id);
    _loadData();
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initial: tx),
      ),
    );
    if (updated == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _TransactionHeader(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SearchBar(controller: _searchController),
            ),
            const SizedBox(height: 8),
            // ── Period filter chips ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _Period.values.map((p) {
                  final labels = {
                    _Period.all: 'Semua',
                    _Period.today: 'Hari Ini',
                    _Period.week: 'Minggu Ini',
                    _Period.month: 'Bulan Ini',
                    _Period.year: 'Tahun Ini',
                  };
                  final sel = p == _activePeriod;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _activePeriod = p);
                        _loadData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          labels[p]!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sel
                                ? Colors.white
                                : AppColors.subText(context),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _groups.isEmpty
                      ? _EmptyTransactions()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          children: [
                            ..._groups.map((g) => _TransactionGroup(
                              group: g,
                              onDelete: _deleteTransaction,
                              onEdit: _editTransaction,
                            )),
                            const SizedBox(height: 16),
                            _SummaryCard(onOpenReports: widget.onOpenReports),
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tx_fab',
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
//  EMPTY STATE
// ══════════════════════════════════════════
class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.incomeContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada transaksi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.bodyText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Catat pengeluaran atau pemasukan\npertama Anda hari ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
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

// ══════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════
class _TransactionHeader extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),

        // Title
        Text(
          'Transaksi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.bodyText(context),
          ),
        ),

        const Spacer(),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  SEARCH BAR
// ══════════════════════════════════════════
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.plusJakartaSans(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Cari transaksi...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF9CA3AF),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
          filled: true,
          fillColor: AppColors.surface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  TRANSACTION GROUP
// ══════════════════════════════════════════
class _TransactionGroup extends StatelessWidget {
  const _TransactionGroup({
    required this.group,
    required this.onDelete,
    required this.onEdit,
  });

  final _TxGroup group;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function(TransactionModel tx) onEdit;

  @override
  Widget build(BuildContext context) {
    final isPositive = group.total >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(group.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.bodyText(context),
                  )),
              const Spacer(),
              Text(
                '${isPositive ? '+' : '-'} ${_formatRupiah(group.total)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isPositive ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ),
        ...group.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TransactionTile(
            item: item,
            onDelete: item.id != null ? () => onDelete(item.id!) : null,
            onEdit: item.tx != null ? () => onEdit(item.tx!) : null,
          ),
        )),
      ],
    );
  }
}

// ══════════════════════════════════════════
//  TRANSACTION TILE
// ══════════════════════════════════════════
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.item,
    this.onDelete,
    this.onEdit,
  });

  final _TxItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.amount >= 0;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final prefix = isIncome ? '+' : '-';

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: isIncome ? AppColors.incomeContainer : AppColors.expenseContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 22,
                color: isIncome ? AppColors.income : AppColors.expense),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.bodyText(context),
                    )),
                if (item.subtitle.isNotEmpty) ...
                  [
                    const SizedBox(height: 3),
                    Text(item.subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF9CA3AF),
                        )),
                  ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$prefix ${_formatRupiah(item.amount)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: amountColor,
                  )),
              const SizedBox(height: 3),
              Text(item.time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: const Color(0xFF9CA3AF),
                  )),
            ],
          ),
          if (onDelete != null || onEdit != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                if (onEdit != null)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text('Edit', style: GoogleFonts.plusJakartaSans()),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Hapus',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.red)),
                      ],
                    ),
                  ),
              ],
              onSelected: (v) {
                if (v == 'delete') onDelete?.call();
                if (v == 'edit') onEdit?.call();
              },
            ),
        ],
      ),
    );

    if (onDelete == null) return tile;
    return Dismissible(
      key: Key('tx_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Hapus Transaksi',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700)),
            content: Text('Hapus "${item.title}"?',
                style: GoogleFonts.plusJakartaSans()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: tile,
    );
  }
}



// ══════════════════════════════════════════
//  SUMMARY BANNER CARD
// ══════════════════════════════════════════
class _SummaryCard extends StatefulWidget {
  const _SummaryCard({this.onOpenReports});

  final VoidCallback? onOpenReports;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  int _thisMonthIncome = 0;
  int _thisMonthExpense = 0;
  int _lastMonthIncome = 0;
  int _lastMonthExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final repo = TransactionRepository();
    final now = DateTime.now();
    final thisMonth = await repo.getMonthlySummary(now.year, now.month);
    final lastMonthDate = DateTime(now.year, now.month - 1);
    final lastMonth = await repo.getMonthlySummary(lastMonthDate.year, lastMonthDate.month);
    if (mounted) {
      setState(() {
        _thisMonthIncome = thisMonth['income'] ?? 0;
        _thisMonthExpense = thisMonth['expense'] ?? 0;
        _lastMonthIncome = lastMonth['income'] ?? 0;
        _lastMonthExpense = lastMonth['expense'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final thisNet = _thisMonthIncome - _thisMonthExpense;
    final lastNet = _lastMonthIncome - _lastMonthExpense;
    final isPositive = thisNet >= 0;

    String title;
    String subtitle;

    if (_thisMonthIncome == 0 && _thisMonthExpense == 0) {
      title = 'Belum Ada Transaksi';
      subtitle = 'Mulai catat transaksi pertama Anda bulan ini.';
    } else if (isPositive) {
      title = 'Surplus Bulan Ini 🎉';
      if (lastNet > 0 && thisNet > lastNet) {
        final pct = (((thisNet - lastNet) / lastNet) * 100).round();
        subtitle = 'Tabungan Anda meningkat $pct% dibanding bulan lalu. Pertahankan!';
      } else {
        subtitle = 'Saldo Anda positif ${_formatRupiah(thisNet)} bulan ini.';
      }
    } else {
      title = 'Pengeluaran Melebihi Pemasukan';
      subtitle = 'Kurangi pengeluaran untuk menjaga saldo tetap sehat.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: isPositive ? AppColors.primary : AppColors.expense,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -8,
            bottom: -16,
            child: Icon(
              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan Bulan Ini',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () {


                  if (widget.onOpenReports != null) {
                    widget.onOpenReports!();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReportsScreen(),
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isPositive ? AppColors.primary : AppColors.expense,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Lihat Laporan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
