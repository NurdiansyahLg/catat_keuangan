import '../local/database_helper.dart';
import '../models/debt_model.dart';

class DebtRepository {
  final _db = DatabaseHelper.instance;

  /// Ambil semua hutang/piutang: belum lunas dulu (urut due_date), lalu yang sudah lunas
  Future<List<DebtModel>> getAll() async {
    final rows = await _db.query(
      'debts',
      orderBy: 'is_paid ASC, due_date ASC, created_at DESC',
    );
    return rows.map(DebtModel.fromMap).toList();
  }

  /// Ambil berdasar tipe: 'hutang' atau 'piutang'
  Future<List<DebtModel>> getByType(String type) async {
    final rows = await _db.query(
      'debts',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'is_paid ASC, due_date ASC, created_at DESC',
    );
    return rows.map(DebtModel.fromMap).toList();
  }

  /// Total nominal belum lunas untuk tipe ('hutang' / 'piutang')
  Future<int> getTotalUnpaid(String type) async {
    final rows = await _db.rawQuery(
      '''
      SELECT SUM(amount) as total
      FROM debts
      WHERE type = ? AND is_paid = 0
      ''',
      [type],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Hanya yang belum lunas
  Future<List<DebtModel>> getUnpaid() async {
    final rows = await _db.query(
      'debts',
      where: 'is_paid = 0',
      orderBy: 'due_date ASC, created_at DESC',
    );
    return rows.map(DebtModel.fromMap).toList();
  }

  /// Tambah baru
  Future<int> insert(DebtModel debt) async {
    return _db.insert('debts', debt.toMap());
  }

  /// Edit
  Future<void> update(DebtModel debt) async {
    await _db.update('debts', debt.toMap());
  }

  /// Toggle status lunas
  Future<void> togglePaid(DebtModel item) async {
    if (item.id == null) return;
    await markPaid(item.id!, paid: !item.isPaid);
  }

  /// Tandai lunas / batalkan lunas
  Future<void> markPaid(int id, {bool paid = true}) async {
    final db = await _db.database;
    await db.update(
      'debts',
      {
        'is_paid': paid ? 1 : 0,
        'paid_at': paid ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus
  Future<void> delete(int id) async {
    await _db.delete('debts', id);
  }
}
