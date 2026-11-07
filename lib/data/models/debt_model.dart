class DebtModel {
  final int? id;
  final String name; // nama orang
  final int amount; // selalu positif
  final String type; // 'hutang' | 'piutang'
  final DateTime? dueDate; // jatuh tempo (opsional)
  final String? notes;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime createdAt;

  const DebtModel({
    this.id,
    required this.name,
    required this.amount,
    required this.type,
    this.dueDate,
    this.notes,
    this.isPaid = false,
    this.paidAt,
    required this.createdAt,
  });

  bool get isHutang => type == 'hutang';
  bool get isPiutang => type == 'piutang';

  /// Sudah jatuh tempo dan belum lunas
  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  DebtModel copyWith({
    int? id,
    String? name,
    int? amount,
    String? type,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? notes,
    bool? isPaid,
    DateTime? paidAt,
    DateTime? createdAt,
  }) =>
      DebtModel(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        notes: notes ?? this.notes,
        isPaid: isPaid ?? this.isPaid,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'type': type,
        'due_date': dueDate?.millisecondsSinceEpoch,
        'notes': notes,
        'is_paid': isPaid ? 1 : 0,
        'paid_at': paidAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory DebtModel.fromMap(Map<String, dynamic> m) => DebtModel(
        id: m['id'] as int?,
        name: m['name'] as String,
        amount: m['amount'] as int,
        type: m['type'] as String,
        dueDate: m['due_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int)
            : null,
        notes: m['notes'] as String?,
        isPaid: (m['is_paid'] as int) == 1,
        paidAt: m['paid_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['paid_at'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
