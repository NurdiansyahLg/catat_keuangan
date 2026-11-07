import 'package:flutter/material.dart';

class CategoryModel {
  final int? id;
  final String name;
  final int iconCode;
  final int colorValue;
  final String type; // 'expense' | 'income'
  final DateTime createdAt;

  const CategoryModel({
    this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    required this.type,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon_code': iconCode,
        'color_value': colorValue,
        'type': type,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        iconCode: map['icon_code'] as int,
        colorValue: map['color_value'] as int,
        type: map['type'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  CategoryModel copyWith({int? id}) => CategoryModel(
        id: id ?? this.id,
        name: name,
        iconCode: iconCode,
        colorValue: colorValue,
        type: type,
        createdAt: createdAt,
      );
}
