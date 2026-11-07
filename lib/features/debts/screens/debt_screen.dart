import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/debt_model.dart';
import '../../../data/repositories/debt_repository.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = DebtRepository();

  List<DebtModel> _hutangs = [];
  List<DebtModel> _piutangs = [];
  int _totalHutang = 0;
  int _totalPiutang = 0;
  bool _loading = true;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final hutangs = await _repo.getByType('hutang');
    final piutangs = await _repo.getByType('piutang');
    final totalHutang = await _repo.getTotalUnpaid('hutang');
    final totalPiutang = await _repo.getTotalUnpaid('piutang');

    if (mounted) {
      setState(() {
        _hutangs = hutangs;
        _piutangs = piutangs;
        _totalHutang = totalHutang;
        _totalPiutang = totalPiutang;
        _loading = false;
      });
    }
  }

  Future<void> _togglePaid(DebtModel item) async {
    await _repo.togglePaid(item);
    _loadData();
  }

  Future<void> _delete(DebtModel item) async {
    await _repo.delete(item.id!);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.bg(context);
    final text = AppColors.bodyText(context);

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
          'Hutang & Piutang',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          tabs: const [
            Tab(text: 'Hutang Saya'),
            Tab(text: 'Piutang Orang'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Summary Cards ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total Hutang Belum Lunas',
                      amount: _currencyFmt.format(_totalHutang),
                      color: AppColors.expense,
                      bgColor: AppColors.expenseContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total Piutang Belum Lunas',
                      amount: _currencyFmt.format(_totalPiutang),
                      color: AppColors.income,
                      bgColor: AppColors.incomeContainer,
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Views ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _DebtList(
                          items: _hutangs,
                          type: 'Hutang',
                          onTogglePaid: _togglePaid,
                          onDelete: _delete,
                          onAdd: () => _openAddDialog(isHutang: true),
                        ),
                        _DebtList(
                          items: _piutangs,
                          type: 'Piutang',
                          onTogglePaid: _togglePaid,
                          onDelete: _delete,
                          onAdd: () => _openAddDialog(isHutang: false),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'debt_fab',
        onPressed: () => _openAddDialog(isHutang: _tabController.index == 0),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Catat Record',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _openAddDialog({required bool isHutang}) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? selectedDueDate;

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
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(builder: (ctx, ss) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHutang ? 'Catat Hutang Baru' : 'Catat Piutang Baru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bodyText(context),
                ),
              ),
              const SizedBox(height: 16),

              // Name Field
              Text(
                isHutang ? 'Hutang Kepada (Nama Orang)' : 'Piutang Oleh (Nama Orang)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText(context),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'cth: Budi / Toko Maju',
                  filled: true,
                  fillColor: AppColors.bg(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Amount Field
              Text(
                'Jumlah Rp',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText(context),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'cth: 150000',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: AppColors.bg(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Due Date Field
              Text(
                'Jatuh Tempo (Opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subText(context),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) ss(() => selectedDueDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bg(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        selectedDueDate != null
                            ? DateFormat('dd/MM/yyyy').format(selectedDueDate!)
                            : 'Pilih Tanggal Jatuh Tempo',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final amount = int.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0;

                    if (name.isEmpty || amount <= 0) return;

                    await _repo.insert(DebtModel(
                      name: name,
                      amount: amount,
                      type: isHutang ? 'hutang' : 'piutang',
                      dueDate: selectedDueDate,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    ));

                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Simpan Data',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
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
//  SUMMARY TILE
// ══════════════════════════════════════════
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
  });

  final String label, amount;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
//  DEBT LIST
// ══════════════════════════════════════════
class _DebtList extends StatelessWidget {
  const _DebtList({
    required this.items,
    required this.type,
    required this.onTogglePaid,
    required this.onDelete,
    required this.onAdd,
  });

  final List<DebtModel> items;
  final String type;
  final Function(DebtModel) onTogglePaid;
  final Function(DebtModel) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final text = AppColors.bodyText(context);
    final sub = AppColors.subText(context);

    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_outlined, size: 54, color: sub.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Belum ada data $type',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah $type', style: GoogleFonts.plusJakartaSans()),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = items[i];
        final isLunas = item.isPaid;

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: item.isOverdue
                ? Border.all(color: AppColors.expense, width: 1.5)
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onTogglePaid(item),
                icon: Icon(
                  isLunas ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isLunas ? AppColors.income : sub,
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: text,
                        decoration: isLunas ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currencyFmt.format(item.amount),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isLunas ? sub : AppColors.primary,
                      ),
                    ),
                    if (item.dueDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Jatuh Tempo: ${DateFormat('dd/MM/yyyy').format(item.dueDate!)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: item.isOverdue ? AppColors.expense : sub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: sub,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Hapus Data',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                      content: Text(
                        'Hapus catatan "${item.name}"?',
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
                  if (ok == true) onDelete(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
