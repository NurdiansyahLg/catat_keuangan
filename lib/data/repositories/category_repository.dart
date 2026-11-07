import '../local/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final _db = DatabaseHelper.instance;

  Future<List<CategoryModel>> getAll() async {
    final rows = await _db.query('categories', orderBy: 'created_at ASC');
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<List<CategoryModel>> getByType(String type) async {
    final rows = await _db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel?> getById(int id) async {
    final rows =
        await _db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  Future<CategoryModel> insert(CategoryModel category) async {
    final id = await _db.insert('categories', category.toMap());
    return category.copyWith(id: id);
  }

  Future<void> update(CategoryModel category) async {
    await _db.update('categories', category.toMap());
  }

  Future<void> delete(int id) async {
    await _db.delete('categories', id);
  }
}
