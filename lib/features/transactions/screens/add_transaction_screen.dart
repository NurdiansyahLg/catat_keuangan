import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

import '../../../core/services/receipt_scan_service.dart';
import '../../../core/services/voice_input_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.initial});
  final TransactionModel? initial;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  bool _isExpense = true;
  bool _isSaving = false;
  late final TextEditingController _amountController;
  final _amountFocus = FocusNode();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  String _selectedWallet = 'Dompet Utama';

  final _txRepo = TransactionRepository();
  final _catRepo = CategoryRepository();

  bool _isScanning = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _isExpense = init?.isExpense ?? true;
    _selectedDate = init?.date ?? DateTime.now();
    _selectedWallet = init?.wallet ?? 'Dompet Utama';
    _amountController = TextEditingController(
      text: init != null ? init.amount.toString() : '0',
    );
    _notesController.text = init?.notes ?? '';
    _loadCategories();
    _amountFocus.addListener(() {
      if (_amountFocus.hasFocus && _amountController.text == '0') {
        _amountController.clear();
      } else if (!_amountFocus.hasFocus && _amountController.text.isEmpty) {
        _amountController.text = '0';
      }
    });
  }

  Future<void> _loadCategories() async {
    final type = _isExpense ? 'expense' : 'income';
    final cats = await _catRepo.getByType(type);
    if (mounted) {
      setState(() {
        _categories = cats;
        // Pre-select category if editing
        if (widget.initial?.categoryId != null && _selectedCategory == null) {
          _selectedCategory = cats
              .where((c) => c.id == widget.initial!.categoryId)
              .firstOrNull;
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const days = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<CategoryModel>(
      context: context,
      backgroundColor: AppColors.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        categories: _categories,
        selected: _selectedCategory,
      ),
    );
    if (result != null) setState(() => _selectedCategory = result);
  }

  Future<void> _pickWallet() async {
    final wallets = ['Dompet Utama', 'Bank', 'E-Wallet', 'Tunai'];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Dompet / Akun',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.bodyText(context),
              ),
            ),
            const SizedBox(height: 14),
            ...wallets.map((w) {
              final isSel = _selectedWallet == w;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isSel
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                leading: Icon(
                  w == 'Bank'
                      ? Icons.account_balance_rounded
                      : w == 'E-Wallet'
                          ? Icons.smartphone_rounded
                          : w == 'Tunai'
                              ? Icons.payments_rounded
                              : Icons.account_balance_wallet_rounded,
                  color: isSel ? AppColors.primary : AppColors.subText(context),
                ),
                title: Text(
                  w,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.bodyText(context),
                  ),
                ),
                trailing: isSel
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, w),
              );
            }),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _selectedWallet = result);
  }

  Future<void> _startVoiceInput() async {
    String spokenText = '';
    bool listening = true;
    StateSetter? bsState;

    // Start listening BEFORE showing bottom sheet
    VoiceInputService.instance.startListening(
      onResult: (text) async {
        spokenText = text;
        final parsed = VoiceInputService.instance.parseIndonesianSpeech(text);
        if (!mounted) return;

        final wasExpense = _isExpense;
        final typeChanged = wasExpense != parsed.isExpense;

        if (typeChanged) {
          setState(() {
            _isExpense = parsed.isExpense;
            _selectedCategory = null;
          });
          await _loadCategories();
        }

        // Auto-match kategori
        CategoryModel? matched;
        if (_categories.isNotEmpty) {
          if (parsed.categoryKeyword != null) {
            final kw = parsed.categoryKeyword!.toLowerCase();
            matched = _categories
                .where((c) => c.name.toLowerCase() == kw)
                .firstOrNull ??
                _categories
                    .where((c) =>
                        c.name.toLowerCase().contains(kw) ||
                        kw.contains(c.name.toLowerCase()))
                    .firstOrNull;
          }

          // Fallback: cek jika ada nama kategori dari _categories yang ada di ucapan
          if (matched == null) {
            final textLower = text.toLowerCase();
            for (final cat in _categories) {
              final catNameLower = cat.name.toLowerCase();
              if (textLower.contains(catNameLower)) {
                matched = cat;
                break;
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _isExpense = parsed.isExpense;
            if (matched != null) {
              _selectedCategory = matched;
            }
            if (parsed.amount != null && parsed.amount! > 0) {
              _amountController.text = parsed.amount.toString();
            }
            if (text.isNotEmpty) {
              _notesController.text = text;
            }
          });
        }
        bsState?.call(() {});
      },
      onListeningStatusChanged: (status) {
        listening = status;
        bsState?.call(() {});
      },
    );

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBsState) {
          bsState = setBsState;
          final currentAmount = int.tryParse(_amountController.text) ?? 0;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: listening
                        ? AppColors.expenseContainer
                        : AppColors.incomeContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 36,
                    color: listening ? AppColors.expense : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  listening ? 'Sedang Mendengarkan...' : 'Selesai',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bodyText(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  spokenText.isEmpty
                      ? 'Katakan sesuatu seperti:\n"beli makan 10000"\natau "bayar internet 250 ribu"'
                      : '"$spokenText"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.subText(context),
                  ),
                ),
                if (spokenText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isExpense
                          ? AppColors.expenseContainer.withValues(alpha: 0.5)
                          : AppColors.incomeContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isExpense
                            ? AppColors.expense.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          _isExpense ? 'Pengeluaran' : 'Pemasukan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isExpense
                                ? AppColors.expense
                                : AppColors.primary,
                          ),
                        ),
                        if (_selectedCategory != null) ...[
                          const Text('•',
                              style: TextStyle(color: Colors.grey)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedCategory!.icon,
                                size: 14,
                                color: _selectedCategory!.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedCategory!.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.bodyText(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (currentAmount > 0) ...[
                          const Text('•',
                              style: TextStyle(color: Colors.grey)),
                          Text(
                            'Rp ${_formatThousands(currentAmount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.bodyText(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    VoiceInputService.instance.stopListening();
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    spokenText.isEmpty ? 'Tutup' : 'Gunakan Data Suara',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Ensure listening stopped when sheet is dismissed
    VoiceInputService.instance.stopListening();

    if (mounted && spokenText.isNotEmpty) {
      final info = <String>[
        _isExpense ? 'Pengeluaran' : 'Pemasukan',
      ];
      if (_selectedCategory != null) info.add(_selectedCategory!.name);
      final amt = int.tryParse(_amountController.text) ?? 0;
      if (amt > 0) info.add('Rp ${_formatThousands(amt)}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Suara terbaca: ${info.join(' • ')}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatThousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _startReceiptScan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Struk',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.bodyText(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Foto struk belanja, total dan tanggalnya akan terisi otomatis.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.subText(context),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(
                'Kamera',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(
                'Galeri / Upload',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _isScanning = true);
    try {
      final result = await ReceiptScanService.instance.scanReceipt(source);
      if (!mounted) return;
      if (result == null) return; // Pengguna membatalkan pemilihan gambar.
      if (!result.foundAnything) {
        if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada data terbaca dari struk. Coba foto yang lebih jelas dan terang.',
            ),
          ),
        );
        return;
      }

      final wasIncome = !_isExpense;
      setState(() {
        // Struk belanja selalu pengeluaran.
        _isExpense = true;
        if (wasIncome) _selectedCategory = null;
        if (result.amount != null && result.amount! > 0) {
          _amountController.text = result.amount.toString();
        }
        if (result.date != null) _selectedDate = result.date!;
        if (result.merchant != null && _notesController.text.trim().isEmpty) {
          _notesController.text = 'Struk: ${result.merchant}';
        }
      });
      if (wasIncome) {
        await _loadCategories();
      }

      if (result.categorySuggestion != null && _categories.isNotEmpty) {
        final suggestionLower = result.categorySuggestion!.toLowerCase();
        final matchedCategory = _categories
                .where((c) => c.name.toLowerCase() == suggestionLower)
                .firstOrNull ??
            _categories
                .where((c) =>
                    c.name.toLowerCase().contains(suggestionLower) ||
                    suggestionLower.contains(c.name.toLowerCase()))
                .firstOrNull;
        if (matchedCategory != null && mounted) {
          setState(() {
            _selectedCategory = matchedCategory;
          });
        }
      }

      final found = <String>[];
      if (result.amount != null) {
        found.add('Rp ${_formatThousands(result.amount!)}');
      }
      if (result.merchant != null) found.add(result.merchant!);
      if (_selectedCategory != null) found.add(_selectedCategory!.name);
      if (result.date != null) found.add(_formatDate(result.date!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Struk terbaca: ${found.join(' â€¢ ')}.'
            '${result.amount == null ? ' Total tidak terbaca, isi manual ya.' : ''}'
            ' Cek lagi sebelum disimpan.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memindai struk. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah harus lebih dari 0')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final tx = TransactionModel(
      id: widget.initial?.id,
      title: _selectedCategory?.name ?? (_isExpense ? 'Pengeluaran' : 'Pemasukan'),
      amount: amount,
      categoryId: _selectedCategory?.id,
      date: _selectedDate,
      wallet: _selectedWallet,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      type: _isExpense ? 'expense' : 'income',
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
    );
    if (_isEditing) {
      await _txRepo.update(tx);
    } else {
      await _txRepo.insert(tx);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.bodyText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Transaksi' : 'Tambah Transaksi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.bodyText(context),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _startReceiptScan,
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.incomeContainer,
                shape: BoxShape.circle,
              ),
              child: _isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.document_scanner_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
            tooltip: 'Scan Struk',
          ),
          IconButton(
            onPressed: _startVoiceInput,
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.incomeContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            tooltip: 'Input Suara',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // â”€â”€ Toggle Type â”€â”€
                  _TypeToggle(
                    isExpense: _isExpense,
                    onChanged: (v) {
                      setState(() {
                        _isExpense = v;
                        _selectedCategory = null;
                      });
                      _loadCategories();
                    },
                  ),
                  const SizedBox(height: 16),

                  // â”€â”€ Amount Card â”€â”€
                  _AmountCard(
                    controller: _amountController,
                    focusNode: _amountFocus,
                  ),
                  const SizedBox(height: 20),

                  // â”€â”€ Kategori â”€â”€
                  _FieldLabel('Kategori'),
                  const SizedBox(height: 6),
                  _TapField(
                    icon: _selectedCategory != null
                        ? _selectedCategory!.icon
                        : Icons.apps_rounded,
                    text: _selectedCategory?.name ?? 'Pilih Kategori',
                    isPlaceholder: _selectedCategory == null,
                    iconColor: _selectedCategory != null
                        ? _selectedCategory!.color
                        : AppColors.primary,
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF9CA3AF)),
                    onTap: _pickCategory,
                  ),
                  const SizedBox(height: 14),

                  // â”€â”€ Tanggal â”€â”€
                  _FieldLabel('Tanggal'),
                  const SizedBox(height: 6),
                  _TapField(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(_selectedDate),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 14),

                  // â”€â”€ Dompet â”€â”€
                  _FieldLabel('Dompet / Akun'),
                  const SizedBox(height: 6),
                  _TapField(
                    icon: _selectedWallet == 'Bank'
                        ? Icons.account_balance_rounded
                        : _selectedWallet == 'E-Wallet'
                            ? Icons.smartphone_rounded
                            : _selectedWallet == 'Tunai'
                                ? Icons.payments_rounded
                                : Icons.account_balance_wallet_outlined,
                    text: _selectedWallet,
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF)),
                    onTap: _pickWallet,
                  ),
                  const SizedBox(height: 14),

                  // â”€â”€ Catatan â”€â”€
                  _FieldLabel('Catatan'),
                  const SizedBox(height: 6),
                  _NotesField(controller: _notesController),
                ],
              ),
            ),
          ),

          // â”€â”€ Save Button â”€â”€
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? 'Menyimpan...' : (_isEditing ? 'Perbarui Transaksi' : 'Simpan Transaksi'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFB0C4C1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  CATEGORY PICKER BOTTOM SHEET
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selected,
  });
  final List<CategoryModel> categories;
  final CategoryModel? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pilih Kategori',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.bodyText(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: categories.isEmpty ? 1 : categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (categories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Belum ada kategori. Tambahkan dulu di menu Kategori.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: const Color(0xFF9CA3AF),
                    ),
                  ),
                );
              }
              final cat = categories[i];
              final isSelected = selected?.id == cat.id;
              return GestureDetector(
                onTap: () => Navigator.pop(context, cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.color.withValues(alpha: 0.1)
                        : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: cat.color, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat.icon, size: 20, color: cat.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.bodyText(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: cat.color, size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  TYPE TOGGLE
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.isExpense, required this.onChanged});
  final bool isExpense;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: 'Pengeluaran',
            selected: isExpense,
            onTap: () => onChanged(true),
          ),
          _ToggleBtn(
            label: 'Pemasukan',
            selected: !isExpense,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  AMOUNT CARD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller, required this.focusNode});
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              'Jumlah',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rp',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  FIELD LABEL
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6B7280),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  TAP FIELD (Kategori, Tanggal, Dompet)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _TapField extends StatelessWidget {
  const _TapField({
    required this.icon,
    required this.text,
    this.trailing,
    this.onTap,
    this.isPlaceholder = false,
    this.iconColor,
  });
  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isPlaceholder;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.bg(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isPlaceholder
                      ? const Color(0xFF9CA3AF)
                      : AppColors.bodyText(context),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}


// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  NOTES FIELD
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 3,
        style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppColors.bodyText(context)),
        decoration: InputDecoration(
          hintText: 'Tambahkan deskripsi...',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF9CA3AF), fontSize: 15,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 12, top: 14),
            child: Icon(Icons.description_outlined,
                color: AppColors.primary, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
        ),
      ),
    );
  }
}
