class TransactionModel {
  final int? id;
  final String title;
  final int amount; // always positive; type menentukan arah
  final int? categoryId;
  final DateTime date;
  final String? notes;
  final String type; // 'expense' | 'income'
  final String wallet;
  final DateTime createdAt;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    this.categoryId,
    required this.date,
    this.notes,
    required this.type,
    this.wallet = 'Dompet Utama',
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';

  /// Amount dengan tanda: negatif untuk pengeluaran
  int get signedAmount => isExpense ? -amount : amount;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'date': date.millisecondsSinceEpoch,
        'notes': notes,
        'type': type,
        'wallet': wallet,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) => TransactionModel(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: map['amount'] as int,
        categoryId: map['category_id'] as int?,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        notes: map['notes'] as String?,
        type: map['type'] as String,
        wallet: map['wallet'] as String? ?? 'Dompet Utama',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  TransactionModel copyWith({int? id}) => TransactionModel(
        id: id ?? this.id,
        title: title,
        amount: amount,
        categoryId: categoryId,
        date: date,
        notes: notes,
        type: type,
        wallet: wallet,
        createdAt: createdAt,
      );
}
