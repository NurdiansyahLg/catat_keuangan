class BudgetModel {
  const BudgetModel({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.month,
    required this.year,
    this.spent = 0,
    required this.createdAt,
  });

  final int? id;
  final int categoryId;
  final String categoryName;
  final int amount;
  final int month;
  final int year;
  final int spent; // runtime: actual spending this month
  final DateTime createdAt;

  double get progress => amount == 0 ? 0 : (spent / amount).clamp(0.0, 1.0);
  bool get isOverBudget => spent > amount;
  int get remaining => amount - spent;

  BudgetModel copyWith({int? id, int? spent}) => BudgetModel(
        id: id ?? this.id,
        categoryId: categoryId,
        categoryName: categoryName,
        amount: amount,
        month: month,
        year: year,
        spent: spent ?? this.spent,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'amount': amount,
        'month': month,
        'year': year,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> m, String catName) =>
      BudgetModel(
        id: m['id'] as int?,
        categoryId: m['category_id'] as int,
        categoryName: catName,
        amount: m['amount'] as int,
        month: m['month'] as int,
        year: m['year'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
