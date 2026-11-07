import 'package:catat_keuangan/data/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryModel Tests', () {
    test('serialization and deserialization works correctly', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final category = CategoryModel(
        id: 1,
        name: 'Makanan',
        iconCode: 58746,
        colorValue: 0xFF4CAF50,
        type: 'expense',
        createdAt: now,
      );

      final map = category.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Makanan');
      expect(map['type'], 'expense');
      expect(map['icon_code'], 58746);
      expect(map['color_value'], 0xFF4CAF50);

      final fromMap = CategoryModel.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'Makanan');
      expect(fromMap.type, 'expense');
      expect(fromMap.isExpense, isTrue);
      expect(fromMap.createdAt, now);
    });
  });
}

