import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/transaction_repository.dart';

/// Helper untuk export transaksi ke CSV dan share.
class CsvExporter {
  const CsvExporter._();

  static const _header =
      'Tanggal,Waktu,Judul,Tipe,Jumlah,Catatan\n';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _escape(String s) =>
      '"${s.replaceAll('"', '""')}"';

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// Export semua transaksi ke CSV lalu tampilkan share sheet.
  static Future<void> exportAndShare(BuildContext context) async {
    final repo = TransactionRepository();
    final txs = await repo.getAll();

    if (txs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada transaksi untuk diekspor.')),
        );
      }
      return;
    }

    final buf = StringBuffer(_header);
    for (final tx in txs) {
      buf.write('${_fmtDate(tx.date)},');
      buf.write('${_fmtTime(tx.date)},');
      buf.write('${_escape(tx.title)},');
      buf.write('${tx.isExpense ? "Pengeluaran" : "Pemasukan"},');
      buf.write('${tx.amount},');
      buf.write('${_escape(tx.notes ?? '')}\n');
    }

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fname =
        'catat_keuangan_${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fname');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Export Transaksi - Catat Keuangan',
        text: 'Data transaksi dari Catat Keuangan',
      ),
    );
  }
}
