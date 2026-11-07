import '../local/database_helper.dart';
import '../models/budget_model.dart';

class BudgetRepository {
  final _db = DatabaseHelper.instance;

  /// Ambil semua budget bulan [month]/[year] beserta spending aktual
  Future<List<BudgetModel>> getMonthlyBudgets(int month, int year) async {
    // Budget rows joined dengan nama kategori
    final rows = await _db.rawQuery(
      '''
      SELECT b.*, c.name as cat_name
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      WHERE b.month = ? AND b.year = ?
      ORDER BY b.created_at DESC
      ''',
      [month, year],
    );

    if (rows.isEmpty) return [];

    // Hitung spending per kategori bulan ini
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    final spendRows = await _db.rawQuery(
      '''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' AND date >= ? AND date < ?
      GROUP BY category_id
      ''',
      [start, end],
    );
    final spendMap = <int, int>{};
    for (final r in spendRows) {
      spendMap[r['category_id'] as int] = (r['total'] as int?) ?? 0;
    }

    return rows.map((r) {
      final catId = r['category_id'] as int;
      final budget = BudgetModel.fromMap(r, r['cat_name'] as String);
      return budget.copyWith(spent: spendMap[catId] ?? 0);
    }).toList();
  }

  /// Upsert budget (insert or replace)
  Future<void> upsert(BudgetModel b) async {
    await _db.rawQuery(
      '''
      INSERT OR REPLACE INTO budgets
        (id, category_id, amount, month, year, created_at)
      VALUES (
        (SELECT id FROM budgets WHERE category_id=? AND month=? AND year=?),
        ?, ?, ?, ?, ?
      )
      ''',
      [
        b.categoryId, b.month, b.year,
        b.categoryId, b.amount, b.month, b.year,
        b.createdAt.millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> delete(int id) async => _db.delete('budgets', id);
}
