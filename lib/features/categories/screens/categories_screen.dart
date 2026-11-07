import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/category_repository.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = CategoryRepository();
  List<CategoryModel> _expenses = [];
  List<CategoryModel> _incomes = [];
  bool _loading = true;

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
    final expenses = await _repo.getByType('expense');
    final incomes = await _repo.getByType('income');
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _incomes = incomes;
        _loading = false;
      });
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
    );
    if (added == true) _loadData();
  }

  Future<void> _deleteCategory(CategoryModel cat) async {
    await _repo.delete(cat.id!);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: AppColors.bg(context),
        elevation: 0,
        title: Text(
          'Kategori',
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
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 14),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF9CA3AF),
          tabs: const [Tab(text: 'Pengeluaran'), Tab(text: 'Pemasukan')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _CategoryList(
                  categories: _expenses,
                  type: 'Pengeluaran',
                  onAdd: _openAdd,
                  onDelete: _deleteCategory,
                ),
                _CategoryList(
                  categories: _incomes,
                  type: 'Pemasukan',
                  onAdd: _openAdd,
                  onDelete: _deleteCategory,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'cat_fab',
        onPressed: _openAdd,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  Category List
// ══════════════════════════════════════════
class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.type,
    required this.onAdd,
    required this.onDelete,
  });

  final List<CategoryModel> categories;
  final String type;
  final VoidCallback onAdd;
  final Future<void> Function(CategoryModel) onDelete;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.incomeContainer, shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_rounded,
                    size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada kategori $type',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.bodyText(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tambahkan kategori untuk\nmulai mencatat transaksi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF9CA3AF), height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Tambah Kategori',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CategoryTile(
        category: categories[i],
        onDelete: () => onDelete(categories[i]),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  Category Tile
// ══════════════════════════════════════════
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onDelete});
  final CategoryModel category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = category.color;

    return Container(
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: AppColors.bodyText(context),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFF9CA3AF), size: 20),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Hapus Kategori',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                  content: Text(
                    'Hapus kategori "${category.name}"?',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
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
              );
              if (ok == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}
