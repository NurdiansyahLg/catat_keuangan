import '../../core/services/wallet_settings_service.dart';
import '../local/database_helper.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final _db = DatabaseHelper.instance;

  // ── CRUD ─────────────────────────────────────────────
  Future<List<TransactionModel>> getAll() async {
    final rows =
        await _db.query('transactions', orderBy: 'date DESC, created_at DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel> insert(TransactionModel tx) async {
    final id = await _db.insert('transactions', tx.toMap());
    return tx.copyWith(id: id);
  }

  Future<void> update(TransactionModel tx) async {
    await _db.update('transactions', tx.toMap());
  }

  Future<void> delete(int id) async {
    await _db.delete('transactions', id);
  }

  // ── Summary helpers ──────────────────────────────────

  /// Total pemasukan & pengeluaran bulan [year]-[month]
  Future<Map<String, int>> getMonthlySummary(int year, int month) async {
    final start =
        DateTime(year, month).millisecondsSinceEpoch;
    final end =
        DateTime(year, month + 1).millisecondsSinceEpoch;

    final rows = await _db.rawQuery(
      '''
      SELECT type, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY type
      ''',
      [start, end],
    );

    int income = 0;
    int expense = 0;
    for (final row in rows) {
      if (row['type'] == 'income') {
        income = (row['total'] as int?) ?? 0;
      } else {
        expense = (row['total'] as int?) ?? 0;
      }
    }
    return {'income': income, 'expense': expense};
  }

  /// Total saldo per dompet (Dompet Utama, Bank, E-Wallet, Tunai) + saldo awal
  Future<Map<String, int>> getWalletBalances() async {
    final rows = await _db.rawQuery(
      '''
      SELECT wallet, type, SUM(amount) as total
      FROM transactions
      GROUP BY wallet, type
      ''',
    );
    // Ambil saldo awal dari settings
    final initialBalances = await WalletSettingsService.instance.getAllInitialBalances();
    final map = <String, int>{
      'Dompet Utama': initialBalances['Dompet Utama'] ?? 0,
      'Bank': initialBalances['Bank'] ?? 0,
      'E-Wallet': initialBalances['E-Wallet'] ?? 0,
      'Tunai': initialBalances['Tunai'] ?? 0,
    };
    for (final r in rows) {
      final wallet = r['wallet'] as String? ?? 'Dompet Utama';
      final type = r['type'] as String?;
      final total = (r['total'] as int?) ?? 0;
      map[wallet] = (map[wallet] ?? 0) + (type == 'income' ? total : -total);
    }
    return map;
  }

  /// Total saldo keseluruhan (semua waktu) + saldo awal
  Future<int> getTotalBalance() async {
    final rows = await _db.rawQuery(
      '''
      SELECT type, SUM(amount) as total
      FROM transactions
      GROUP BY type
      ''',
    );
    int income = 0;
    int expense = 0;
    for (final row in rows) {
      if (row['type'] == 'income') {
        income = (row['total'] as int?) ?? 0;
      } else {
        expense = (row['total'] as int?) ?? 0;
      }
    }
    // Tambahkan total saldo awal dari semua dompet
    final initialTotal = await WalletSettingsService.instance.getTotalInitialBalance();
    return (income - expense) + initialTotal;
  }

  /// 5 transaksi terbaru
  Future<List<TransactionModel>> getRecent({int limit = 5}) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM transactions ORDER BY date DESC, created_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Transaksi dalam rentang tanggal
  Future<List<TransactionModel>> getByDateRange(
      DateTime start, DateTime end) async {
    final rows = await _db.rawQuery(
      '''SELECT * FROM transactions
         WHERE date >= ? AND date < ?
         ORDER BY date DESC''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Ringkasan income & expense untuk 6 bulan terakhir
  /// Returns list of {month, income, expense} ordered oldest→newest
  Future<List<Map<String, dynamic>>> getLast6MonthsSummary() async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      final rows = await _db.rawQuery(
        '''SELECT type, SUM(amount) as total
           FROM transactions
           WHERE date >= ? AND date < ?
           GROUP BY type''',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );
      int income = 0, expense = 0;
      for (final r in rows) {
        if (r['type'] == 'income') { income = (r['total'] as int?) ?? 0; }
        else { expense = (r['total'] as int?) ?? 0; }
      }
      result.add({
        'month': month,
        'income': income,
        'expense': expense,
      });
    }
    return result;
  }

  /// Top pengeluaran per kategori dalam rentang tanggal
  Future<List<Map<String, dynamic>>> getCategoryExpenses(
      DateTime start, DateTime end) async {
    return _db.rawQuery(
      '''SELECT category_id, title, SUM(amount) as total
         FROM transactions
         WHERE type = 'expense' AND date >= ? AND date < ?
         GROUP BY category_id
         ORDER BY total DESC
         LIMIT 6''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
  }
}

