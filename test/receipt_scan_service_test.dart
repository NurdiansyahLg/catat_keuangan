import 'package:flutter_test/flutter_test.dart';
import 'package:catat_keuangan/core/services/receipt_scan_service.dart';

void main() {
  group('ReceiptScanService Tests', () {
    test('parses Cafe Bee receipt with comma thousand separators and multi-line total', () {
      const receipt = '''
CAFE BEE
Jl. Kemang Raya No. 45
Rabu, 24 Mei 2023 15:45

1x Caramel Macchiato     38,000
1x Croissant Butter      27,000

SUBTOTAL                 65,000
PB1 10%                   6,500
TOTAL
71,500
CASH                     100,000
CHANGE                    28,500
Terima kasih atas kunjungan Anda
''';

      final result = ReceiptScanService.parseReceiptText(receipt);
      expect(result.merchant, 'CAFE BEE');
      expect(result.amount, 71500);
      expect(result.date, DateTime(2023, 5, 24));
      expect(result.categorySuggestion, 'Makanan');
    });

    test('parses Indomaret receipt with dot thousand separators and single-line total', () {
      const receipt = '''
INDOMARET KEMANG
JL. KEMANG SELATAN 1
NPWP: 01.334.567.8-012.000
24.05.23-14:20 2.1.45 9981/NUR/01

ROTI TAWAR SARI ROTI    15.000
ULTRA MILK COKLAT 250ML  7.500
INDOMIE GORENG 5X       15.500
--------------------------------
TOTAL BELANJA           38.000
TUNAI                   50.000
KEMBALIAN               12.000
--------------------------------
''';

      final result = ReceiptScanService.parseReceiptText(receipt);
      expect(result.merchant, 'INDOMARET KEMANG');
      expect(result.amount, 38000);
      expect(result.date, DateTime(2023, 5, 24));
      expect(result.categorySuggestion, 'Belanja');
    });

    test('parses SPBU Pertamina receipt for transport category', () {
      const receipt = '''
SPBU PERTAMINA 34.12345
JL. GATOT SUBROTO KAV 5
TANGGAL: 2023-05-24 08:30

PERTALITE
LITER: 30.00
HARGA/LTR: 10.000
TOTAL HARGA: Rp 300.000
BAYAR: Rp 300.000
''';

      final result = ReceiptScanService.parseReceiptText(receipt);
      expect(result.merchant, contains('SPBU PERTAMINA'));
      expect(result.amount, 300000);
      expect(result.date, DateTime(2023, 5, 24));
      expect(result.categorySuggestion, 'Transportasi');
    });

    test('handles OCR noise with letter O and spacing artifacts', () {
      const receipt = '''
WARUNG KOPI SEDAP
Tgl: 15-Mei-2023
TOTAL : Rp. 45. OOO ,-
TUNAI: 5O.OOO
''';

      final result = ReceiptScanService.parseReceiptText(receipt);
      expect(result.merchant, 'WARUNG KOPI SEDAP');
      expect(result.amount, 45000);
      expect(result.date, DateTime(2023, 5, 15));
      expect(result.categorySuggestion, 'Makanan');
    });
  });
}
