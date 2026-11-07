import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil pemindaian struk belanja.
///
/// Semua field boleh null: OCR tidak selalu berhasil membaca setiap bagian.
/// [foundAnything] false berarti tidak ada satu pun data yang terbaca.
class ReceiptScanResult {
  final int? amount;
  final DateTime? date;
  final String? merchant;
  final String rawText;

  const ReceiptScanResult({
    this.amount,
    this.date,
    this.merchant,
    required this.rawText,
  });

  bool get foundAnything =>
      amount != null || date != null || merchant != null;
}

class ReceiptScanService {
  ReceiptScanService._internal();
  static final ReceiptScanService instance = ReceiptScanService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Pindai struk dari kamera atau galeri.
  ///
  /// Mengembalikan null kalau pengguna membatalkan pemilihan gambar.
  /// Melempar [Exception] kalau OCR gagal berjalan (mis. model ML Kit
  /// belum terunduh atau gambar tidak bisa dibaca).
  Future<ReceiptScanResult?> scanReceipt(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 90,
    );
    if (image == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await recognizer.processImage(inputImage);
      return parseReceiptText(recognizedText.text);
    } finally {
      await recognizer.close();
    }
  }

  /// Parser murni: mengubah teks mentah hasil OCR menjadi [ReceiptScanResult].
  ///
  /// Dipisah sebagai static supaya bisa diuji tanpa kamera atau ML Kit.
  static ReceiptScanResult parseReceiptText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const ReceiptScanResult(rawText: '');
    }

    return ReceiptScanResult(
      amount: _extractTotal(lines),
      date: _extractDate(lines),
      merchant: _extractMerchant(lines),
      rawText: rawText,
    );
  }

  // ── Total ──────────────────────────────────────────

  static const _totalKeywords = [
    'grand total',
    'total bayar',
    'total belanja',
    'yang harus dibayar',
    'total',
    'jumlah',
    'bayar',
  ];

  /// Baris yang angkanya BUKAN total belanja, jadi harus dilewati.
  /// "Tunai" dan "Kembali" terutama: itu uang yang dibayarkan dan
  /// kembaliannya, sering lebih besar dari total belanja.
  static const _ignoreAmountKeywords = [
    'tunai',
    'cash',
    'kembali',
    'kembalian',
    'change',
    'diskon',
    'discount',
    'ppn',
    'pajak',
    'service',
    'subtotal',
    'sub total',
  ];

  static int? _extractTotal(List<String> lines) {
    // 1. Cari baris TOTAL, dari bawah ke atas supaya dapat TOTAL terakhir
    //    (struk kadang punya "Subtotal" lalu "Total"). Angka terakhir di
    //    baris itu yang dipakai.
    for (var i = lines.length - 1; i >= 0; i--) {
      final lower = lines[i].toLowerCase();
      if (_ignoreAmountKeywords.any(lower.contains)) continue;
      if (_totalKeywords.any(lower.contains)) {
        final amount = _lastMoneyOnLine(lines[i]);
        if (amount != null && amount >= 500) return amount;
      }
    }

    // 2. Fallback: angka uang terbesar di seluruh struk, di luar baris
    //    yang diabaikan dan di luar baris tanggal.
    int? biggest;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_ignoreAmountKeywords.any(lower.contains)) continue;
      if (_parseDateLine(line) != null) continue;
      if (_looksLikePhone(line)) continue;
      for (final m in _moneyPattern.allMatches(line)) {
        final value = _parseMoney(m.group(0)!);
        if (value != null &&
            value >= 500 &&
            (biggest == null || value > biggest)) {
          biggest = value;
        }
      }
    }
    return biggest;
  }

  /// Angka uang: "1.250.000", "50.000", "12500", "125.000,00".
  static final _moneyPattern =
      RegExp(r'\d{1,3}(?:[.,]\d{3})+(?:,\d{2})?|\d+');

  static int? _lastMoneyOnLine(String line) {
    int? last;
    for (final m in _moneyPattern.allMatches(line)) {
      final value = _parseMoney(m.group(0)!);
      if (value != null) last = value;
    }
    return last;
  }

  /// Ubah teks angka format Indonesia menjadi rupiah (bilangan bulat).
  /// '.' dianggap pemisah ribuan, ',' dianggap desimal dan dibuang.
  static int? _parseMoney(String raw) {
    var s = raw.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty) return null;
    if (s.contains(',')) s = s.split(',').first;
    s = s.replaceAll('.', '');
    if (s.isEmpty) return null;
    final value = int.tryParse(s);
    if (value == null || value <= 0) return null;
    return value;
  }

  static bool _looksLikePhone(String line) {
    return RegExp(r'0\d{2,3}[- ]?\d{3,}').hasMatch(line);
  }

  // ── Tanggal ────────────────────────────────────────

  static DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final date = _parseDateLine(line);
      if (date != null) return date;
    }
    return null;
  }

  static DateTime? _parseDateLine(String line) {
    // 12/11/2026, 12-11-2026, 12.11.2026 (format Indonesia: hari/bulan/tahun)
    final numeric =
        RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(line);
    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      final parsed = _validDate(day, month, year);
      if (parsed != null) return parsed;
    }

    // 12 Nov 2026 / 12 November 2026
    final named = RegExp(
      r'(\d{1,2})\s+(jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)[a-z]*\s+(\d{4})',
      caseSensitive: false,
    ).firstMatch(line);
    if (named != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'mei': 5,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'agu': 8,
        'aug': 8,
        'sep': 9,
        'okt': 10,
        'oct': 10,
        'nov': 11,
        'des': 12,
        'dec': 12,
      };
      final month = months[named.group(2)!.toLowerCase()];
      if (month != null) {
        final parsed = _validDate(
          int.parse(named.group(1)!),
          month,
          int.parse(named.group(3)!),
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _validDate(int day, int month, int year) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2020 || year > DateTime.now().year + 1) return null;
    try {
      final date = DateTime(year, month, day);
      // DateTime menormalisasi tanggal mustahil (30 Feb jadi 2 Mar),
      // jadi pastikan hasil bulat-baliknya sama.
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      // Tolak tanggal di masa depan (biasanya salah baca OCR).
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (date.isAfter(today)) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  // ── Nama toko ──────────────────────────────────────

  static const _merchantSkipKeywords = [
    'struk',
    'receipt',
    'npwp',
    'telp',
    'phone',
    'jalan',
    'jl.',
    'terima kasih',
    'thank you',
    'selamat',
    'kasir',
    'cashier',
    'nomor',
    'invoice',
    'tanggal',
    'date',
    'total',
    'bayar',
    'tunai',
    'kembali',
    'diskon',
    'ppn',
  ];

  static String? _extractMerchant(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_merchantSkipKeywords.any(lower.contains)) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;
      if (line.length < 3 || line.length > 40) continue;
      final cleaned =
          line.replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '').trim();
      if (cleaned.length < 3) continue;
      return cleaned;
    }
    return null;
  }
}
