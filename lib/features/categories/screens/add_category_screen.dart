import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';

// ══════════════════════════════════════════
//  Icon pilihan kategori
// ══════════════════════════════════════════
const _categoryIcons = [
  (icon: Icons.restaurant_outlined,      label: 'Makanan'),
  (icon: Icons.directions_car_outlined,  label: 'Transport'),
  (icon: Icons.shopping_bag_outlined,    label: 'Belanja'),
  (icon: Icons.local_hospital_outlined,  label: 'Kesehatan'),
  (icon: Icons.school_outlined,          label: 'Pendidikan'),
  (icon: Icons.home_outlined,            label: 'Rumah'),
  (icon: Icons.movie_outlined,           label: 'Hiburan'),
  (icon: Icons.fitness_center_outlined,  label: 'Olahraga'),
  (icon: Icons.phone_outlined,           label: 'Telepon'),
  (icon: Icons.wifi_outlined,            label: 'Internet'),
  (icon: Icons.electric_bolt_outlined,   label: 'Listrik'),
  (icon: Icons.water_drop_outlined,      label: 'Air'),
  (icon: Icons.coffee_outlined,          label: 'Kafe'),
  (icon: Icons.pets_outlined,            label: 'Hewan'),
  (icon: Icons.flight_outlined,          label: 'Perjalanan'),
  (icon: Icons.account_balance_outlined, label: 'Bank'),
  (icon: Icons.card_giftcard_outlined,   label: 'Hadiah'),
  (icon: Icons.work_outline_rounded,     label: 'Kerja'),
  (icon: Icons.savings_outlined,         label: 'Tabungan'),
  (icon: Icons.attach_money_rounded,     label: 'Gaji'),
  (icon: Icons.business_center_outlined, label: 'Bisnis'),
  (icon: Icons.more_horiz_rounded,       label: 'Lainnya'),
];

// Pilihan warna kategori
const _categoryColors = [
  Color(0xFF1A7A68), // teal (primary)
  Color(0xFF2563EB), // blue
  Color(0xFF7C3AED), // purple
  Color(0xFFDB2777), // pink
  Color(0xFFDC2626), // red
  Color(0xFFD97706), // amber
  Color(0xFF16A34A), // green
  Color(0xFF0891B2), // cyan
];

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  bool _isExpense = true;
  bool _isSaving = false;
  int _selectedIconIndex = 0;
  int _selectedColorIndex = 0;
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _repo = CategoryRepository();

  Color get _activeColor => _categoryColors[_selectedColorIndex];
  IconData get _activeIcon => _categoryIcons[_selectedIconIndex].icon;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final category = CategoryModel(
      name: _nameController.text.trim(),
      iconCode: _activeIcon.codePoint,
      colorValue: _activeColor.toARGB32(),
      type: _isExpense ? 'expense' : 'income',
      createdAt: DateTime.now(),
    );
    await _repo.insert(category);
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
          'Tambah Kategori',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Toggle Tipe ──
                  _TypeToggle(
                    isExpense: _isExpense,
                    onChanged: (v) => setState(() => _isExpense = v),
                  ),
                  const SizedBox(height: 20),

                  // ── Preview Kategori ──
                  _CategoryPreview(
                    icon: _activeIcon,
                    color: _activeColor,
                    name: _nameController.text.isEmpty
                        ? 'Nama Kategori'
                        : _nameController.text,
                    isExpense: _isExpense,
                  ),
                  const SizedBox(height: 20),

                  // ── Nama Kategori ──
                  _FieldLabel('Nama Kategori'),
                  const SizedBox(height: 6),
                  _NameField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // ── Pilih Warna ──
                  _FieldLabel('Warna'),
                  const SizedBox(height: 10),
                  _ColorPicker(
                    selected: _selectedColorIndex,
                    onChanged: (i) => setState(() => _selectedColorIndex = i),
                  ),
                  const SizedBox(height: 20),

                  // ── Pilih Ikon ──
                  _FieldLabel('Ikon'),
                  const SizedBox(height: 10),
                  _IconPicker(
                    selectedIndex: _selectedIconIndex,
                    activeColor: _activeColor,
                    onChanged: (i) => setState(() => _selectedIconIndex = i),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_nameController.text.trim().isEmpty || _isSaving)
                    ? null
                    : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Kategori',
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

// ══════════════════════════════════════════
//  TYPE TOGGLE (sama persis dgn AddTransaction)
// ══════════════════════════════════════════
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
          _Btn('Pengeluaran', isExpense, () => onChanged(true)),
          _Btn('Pemasukan', !isExpense, () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.selected, this.onTap);
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
              fontSize: 14, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  CATEGORY PREVIEW
// ══════════════════════════════════════════
class _CategoryPreview extends StatelessWidget {
  const _CategoryPreview({
    required this.icon,
    required this.color,
    required this.name,
    required this.isExpense,
  });
  final IconData icon;
  final Color color;
  final String name;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Pratinjau',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.bodyText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpense ? 'Pengeluaran' : 'Pemasukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExpense ? 'Pengeluaran' : 'Pemasukan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color,
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

// ══════════════════════════════════════════
//  NAME FIELD
// ══════════════════════════════════════════
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15, color: AppColors.bodyText(context),
        ),
        decoration: InputDecoration(
          hintText: 'Contoh: Makan Siang, Gaji...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15, color: const Color(0xFF9CA3AF),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 12),
            child: Icon(Icons.label_outline_rounded,
                color: AppColors.primary, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 0),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  COLOR PICKER
// ══════════════════════════════════════════
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_categoryColors.length, (i) {
        final color = _categoryColors[i];
        final isSelected = selected == i;
        return GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: AppColors.bodyText(context), width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════
//  ICON PICKER
// ══════════════════════════════════════════
class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selectedIndex,
    required this.activeColor,
    required this.onChanged,
  });
  final int selectedIndex;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: _categoryIcons.length,
        itemBuilder: (_, i) {
          final item = _categoryIcons[i];
          final isSelected = selectedIndex == i;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.15)
                    : AppColors.bg(context),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: activeColor, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon, size: 22,
                    color: isSelected ? activeColor : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? activeColor : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════
//  FIELD LABEL (helper)
// ══════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280),
      ),
    );
  }
}
