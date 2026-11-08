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
  final String? categorySuggestion;
  final String rawText;

  const ReceiptScanResult({
    this.amount,
    this.date,
    this.merchant,
    this.categorySuggestion,
    required this.rawText,
  });

  bool get foundAnything =>
      amount != null ||
      date != null ||
      merchant != null ||
      categorySuggestion != null;
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
      imageQuality: 92,
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

    final merchant = _extractMerchant(lines);
    final category = _inferCategory(merchant, rawText);

    return ReceiptScanResult(
      amount: _extractTotal(lines),
      date: _extractDate(lines),
      merchant: merchant,
      categorySuggestion: category,
      rawText: rawText,
    );
  }

  // ── Total ──────────────────────────────────────────

  static const _highPriorityTotalKeywords = [
    'grand total',
    'total bayar',
    'total belanja',
    'total tagihan',
    'total akhir',
    'total harga',
    'harga total',
    'total amount',
    'yang harus dibayar',
    'amount due',
    'balance due',
    'net total',
    'total net',
    'netto',
    'nett',
  ];

  static const _standardTotalKeywords = [
    'total',
    'tagihan',
    'jumlah',
    'ttl',
    'tot',
    'g.total',
    'g-total',
  ];

  static const _subtotalKeywords = [
    'subtotal',
    'sub total',
    'sub-total',
  ];

  /// Baris yang angkanya BUKAN total belanja, melainkan pembayaran atau kembalian.
  static const _ignoreKeywords = [
    'kembali',
    'kembalian',
    'change',
    'kembali anda',
    'diskon',
    'discount',
    'potongan',
    'ppn',
    'pajak',
    'tax',
    'service charge',
    'service',
    'uang diterima',
    'diterima',
  ];

  static int? _extractTotal(List<String> lines) {
    // 1. Cek High-Priority Keywords (dari bawah ke atas)
    for (var i = lines.length - 1; i >= 0; i--) {
      final lineLower = lines[i].toLowerCase();
      if (_hasIgnoreKeywords(lineLower)) continue;
      if (_highPriorityTotalKeywords.any(lineLower.contains)) {
        final amount = _findMoneyNearLine(lines, i);
        if (amount != null && amount >= 500) return amount;
      }
    }

    // 2. Cek Standard Total Keywords (dari bawah ke atas)
    for (var i = lines.length - 1; i >= 0; i--) {
      final lineLower = lines[i].toLowerCase();
      if (_hasIgnoreKeywords(lineLower)) continue;
      if (_standardTotalKeywords.any((kw) => _matchesKeyword(lineLower, kw))) {
        final amount = _findMoneyNearLine(lines, i);
        if (amount != null && amount >= 500) return amount;
      }
    }

    // 3. Fallback Subtotal (jika grand total terpotong/buram di struk)
    for (var i = lines.length - 1; i >= 0; i--) {
      final lineLower = lines[i].toLowerCase();
      if (_subtotalKeywords.any(lineLower.contains)) {
        final amount = _findMoneyNearLine(lines, i);
        if (amount != null && amount >= 500) return amount;
      }
    }

    // 4. Fallback Terakhir: cari nominal terbesar di paruh bawah struk
    // (pada struk, total hampir selalu berada di bagian bawah)
    int? biggest;
    final startIndex = (lines.length * 0.35).floor();
    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();
      if (_hasIgnoreKeywords(lineLower)) continue;
      if (lineLower.contains('cash') || lineLower.contains('tunai')) continue;
      if (_parseDateLine(line) != null) continue;
      if (_looksLikePhone(line)) continue;

      for (final m in _extractAllMoneys(line)) {
        if (m >= 500 && (biggest == null || m > biggest)) {
          biggest = m;
        }
      }
    }

    // Jika paruh bawah tidak menemukan angka sama sekali, scan seluruh baris
    if (biggest == null) {
      for (final line in lines) {
        final lineLower = line.toLowerCase();
        if (_hasIgnoreKeywords(lineLower)) continue;
        if (lineLower.contains('cash') || lineLower.contains('tunai')) continue;
        if (_parseDateLine(line) != null) continue;
        if (_looksLikePhone(line)) continue;

        for (final m in _extractAllMoneys(line)) {
          if (m >= 500 && (biggest == null || m > biggest)) {
            biggest = m;
          }
        }
      }
    }

    return biggest;
  }

  static bool _hasIgnoreKeywords(String text) {
    // Jika mengandung 'total', jangan abaikan (misal 'total diskon' vs 'total')
    if (text.contains('total') || text.contains('tagihan')) {
      return text.contains('kembali') ||
          text.contains('kembalian') ||
          text.contains('change') ||
          text.contains('diskon') ||
          text.contains('discount');
    }
    return _ignoreKeywords.any(text.contains);
  }

  static bool _matchesKeyword(String text, String keyword) {
    if (keyword.length <= 3) {
      // Kata pendek seperti 'tot' atau 'ttl' harus berupa batas kata
      final regex = RegExp('\\b$keyword\\b|\\b$keyword[:= ]');
      return regex.hasMatch(text);
    }
    return text.contains(keyword);
  }

  /// Mencari nominal uang di baris target, atau jika kosong memeriksa baris berikutnya (i+1, i+2)
  static int? _findMoneyNearLine(List<String> lines, int index) {
    // 1. Cek di baris yang sama
    final currentLineMoney = _lastMoneyOnLine(lines[index]);
    if (currentLineMoney != null) return currentLineMoney;

    // 2. Cek di baris setelahnya (misal 'TOTAL' di baris i, '45,000' di baris i+1)
    if (index + 1 < lines.length) {
      final nextLine = lines[index + 1];
      final nextMoney = _lastMoneyOnLine(nextLine);
      if (nextMoney != null) return nextMoney;

      // Jika baris i+1 hanya berisi tanda 'Rp' atau ':', cek i+2
      final stripped = nextLine.replaceAll(RegExp(r'[\s:=-]|rp|idr', caseSensitive: false), '');
      if (stripped.isEmpty && index + 2 < lines.length) {
        final nextNextMoney = _lastMoneyOnLine(lines[index + 2]);
        if (nextNextMoney != null) return nextNextMoney;
      }
    }

    return null;
  }

  static List<int> _extractAllMoneys(String rawLine) {
    // Normalisasi OCR: ganti huruf 'O' atau 'o' yang salah dibaca sebagai nol
    var line = rawLine
        .replaceAll(RegExp(r'(?<=\d|[.,]|\brp|\bidr)\s*[Oo]+', caseSensitive: false), '000')
        .replaceAll(RegExp(r'[Oo]+\s*(?=\d|[.,])', caseSensitive: false), '0')
        .replaceAll(RegExp(r'[,\.]\s*-[^\d]*$'), ''); // buang trailing ",-"

    final results = <int>[];
    // Regex fleksibel mencakup angka ribuan dengan pemisah titik/koma/spasi
    final regex = RegExp(
      r'(?:rp|idr)?\.?\s*(\d{1,3}(?:[\s.,]\d{3})+(?:[.,]\d{2})?|\d{4,})',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(line)) {
      final val = _parseMoney(match.group(1)!);
      if (val != null) results.add(val);
    }
    return results;
  }

  static int? _lastMoneyOnLine(String line) {
    final list = _extractAllMoneys(line);
    return list.isNotEmpty ? list.last : null;
  }

  /// Parser uang cerdas yang mengenali format Indonesia & format POS internasional
  /// serta tahan terhadap noise OCR (misal huruf O, spasi di antara digit).
  static int? _parseMoney(String raw) {
    // Normalisasi huruf 'O' atau 'o' yang sering salah dibaca OCR sebagai nol
    var s = raw.replaceAll(RegExp(r'(?<=\d|[.,])[Oo]|[Oo](?=\d|[.,])'), '0');

    // Buang simbol mata uang dan whitespace
    s = s.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (s.isEmpty) return null;

    // Jika mengandung titik DAN koma, misal "45.000,00" atau "45,000.00"
    if (s.contains('.') && s.contains(',')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Format Indonesia: 45.000,00 -> koma adalah desimal
        s = s.substring(0, lastComma).replaceAll('.', '');
      } else {
        // Format POS Barat: 45,000.00 -> titik adalah desimal
        s = s.substring(0, lastDot).replaceAll(',', '');
      }
    }
    // Jika hanya mengandung koma, misal "45,000" atau "45000,00"
    else if (s.contains(',')) {
      final parts = s.split(',');
      if (parts.length > 2) {
        // Multi koma: "1,250,000" -> pemisah ribuan
        s = s.replaceAll(',', '');
      } else if (parts.length == 2) {
        if (parts.last.length == 3) {
          // 3 digit di belakang koma: "45,000" -> ribuan
          s = s.replaceAll(',', '');
        } else if (parts.last.length <= 2 && parts.first.length >= 3) {
          // 2 digit di belakang koma: "45000,00" -> desimal
          s = parts.first;
        } else {
          s = s.replaceAll(',', '');
        }
      }
    }
    // Jika hanya mengandung titik, misal "45.000" atau "45000.00"
    else if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length == 2 && parts.last.length == 2 && parts.first.length >= 3) {
        // 2 digit di belakang titik: "45000.00" -> desimal
        s = parts.first;
      } else {
        // Format umum Indonesia: "45.000" -> ribuan
        s = s.replaceAll('.', '');
      }
    }

    if (s.isEmpty) return null;
    final value = int.tryParse(s);
    if (value == null || value <= 0) return null;
    return value;
  }

  static bool _looksLikePhone(String line) {
    return RegExp(r'(?:\+62|08|021|\(0\d{2,3}\))[0-9\s-]{6,}').hasMatch(line);
  }

  // ── Tanggal ────────────────────────────────────────

  static DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      final date = _parseDateLine(line);
      if (date != null) return date;
    }
    return null;
  }

  static DateTime? _parseDateLine(String rawLine) {
    // Buang nama hari Indonesia di awal baris: "Rabu, 24 Mei 2023" -> "24 Mei 2023"
    final line = rawLine.replaceAll(
      RegExp(r'\b(senin|selasa|rabu|kamis|jumat|sabtu|minggu|monday|tuesday|wednesday|thursday|friday|saturday|sunday)[,\s]*', caseSensitive: false),
      '',
    ).trim();

    // 1. Format ISO: YYYY-MM-DD atau YYYY/MM/DD
    final isoMatch = RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})').firstMatch(line);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      final parsed = _validDate(day, month, year);
      if (parsed != null) return parsed;
    }

    // 2. Format numerik Indonesia: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, DD/MM/YY
    final numeric = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(line);
    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      final parsed = _validDate(day, month, year);
      if (parsed != null) return parsed;
    }

    // 3. Format nama bulan: "24 Mei 2023", "24-May-2023", "24/Mei/2023"
    final named = RegExp(
      r'(\d{1,2})[\s/\-.](jan|feb|mar|apr|mei|may|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)[a-z]*[\s/\-.](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(line);
    if (named != null) {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
        'mei': 5, 'may': 5, 'jun': 6, 'jul': 7,
        'agu': 8, 'aug': 8, 'sep': 9, 'okt': 10,
        'oct': 10, 'nov': 11, 'des': 12, 'dec': 12,
      };
      final month = months[named.group(2)!.toLowerCase()];
      if (month != null) {
        var year = int.parse(named.group(3)!);
        if (year < 100) year += 2000;
        final parsed = _validDate(
          int.parse(named.group(1)!),
          month,
          year,
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
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (date.isAfter(today)) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  // ── Nama Toko & Kategori ───────────────────────────

  static const _merchantSkipKeywords = [
    'struk', 'receipt', 'bill', 'order', 'table', 'meja',
    'npwp', 'telp', 'phone', 'fax', 'jalan', 'jl.',
    'terima kasih', 'thank you', 'selamat datang', 'welcome',
    'customer copy', 'merchant copy', 'duplicate', 'reprint',
    'kasir', 'cashier', 'pos', 'nomor', 'invoice', 'no.',
    'tanggal', 'date', 'total', 'bayar', 'tunai', 'kembali',
    'diskon', 'ppn', 'tax', 'service',
  ];

  static String? _extractMerchant(List<String> lines) {
    // Cari nama toko di 8 baris pertama
    final maxCheck = lines.length > 8 ? 8 : lines.length;
    for (var i = 0; i < maxCheck; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (_merchantSkipKeywords.any(lower.contains)) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(line)) continue;
      if (line.length < 3 || line.length > 40) continue;
      final cleaned = line
          .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '')
          .trim();
      if (cleaned.length < 3) continue;
      return cleaned;
    }
    return null;
  }

  /// Prediksi kategori otomatis berdasarkan nama toko dan teks struk
  static String? _inferCategory(String? merchant, String rawText) {
    // 1. Prioritaskan pengecekan nama toko / merchant langsung
    if (merchant != null && merchant.isNotEmpty) {
      final m = merchant.toLowerCase();
      // Transportasi
      if (m.contains('spbu') || m.contains('pertamina') || m.contains('shell') || m.contains('bp ') || m.contains('parkir') || m.contains('grab') || m.contains('gojek') || m.contains('kai')) {
        return 'Transportasi';
      }
      // Belanja (Supermarket, Minimarket, Fashion)
      if (m.contains('indomaret') || m.contains('alfamart') || m.contains('alfamidi') || m.contains('superindo') || m.contains('hypermart') || m.contains('transmart') || m.contains('lotte') || m.contains('market') || m.contains('mart') || m.contains('swalayan')) {
        return 'Belanja';
      }
      // Makanan & Minuman
      if (m.contains('cafe') || m.contains('kafe') || m.contains('kopi') || m.contains('coffee') || m.contains('resto') || m.contains('restaurant') || m.contains('restoran') || m.contains('bakery') || m.contains('dapur') || m.contains('warung') || m.contains('kedai') || m.contains('mie') || m.contains('bakso') || m.contains('ayam') || m.contains('sate') || m.contains('pizza') || m.contains('burger') || m.contains('steak')) {
        return 'Makanan';
      }
      // Kesehatan
      if (m.contains('apotek') || m.contains('apotik') || m.contains('kimia farma') || m.contains('k24') || m.contains('k-24') || m.contains('klinik') || m.contains('clinic') || m.contains('rs ') || m.contains('rumah sakit') || m.contains('optik')) {
        return 'Kesehatan';
      }
      // Hiburan
      if (m.contains('cinema') || m.contains('xxi') || m.contains('cgv') || m.contains('cinepolis') || m.contains('bioskop') || m.contains('karaoke')) {
        return 'Hiburan';
      }
      // Pendidikan
      if (m.contains('gramedia') || m.contains('buku') || m.contains('book') || m.contains('stationery') || m.contains('fotocopy') || m.contains('atk')) {
        return 'Pendidikan';
      }
      // Rumah
      if (m.contains('pln') || m.contains('pdam') || m.contains('ace hardware') || m.contains('informa') || m.contains('ikea') || m.contains('mr. diy') || m.contains('mitra10')) {
        return 'Rumah';
      }
    }

    // 2. Jika nama toko belum spesifik, cek konten keseluruhan struk
    final search = '${merchant ?? ''} $rawText'.toLowerCase();

    // Makanan & Minuman
    final foodKeywords = [
      'cafe', 'kafe', 'kopi', 'coffee', 'resto', 'restaurant', 'restoran',
      'bakery', 'roti', 'dapur', 'warung', 'kedai', 'mie', 'bakso', 'ayam',
      'sate', 'pizza', 'burger', 'beverage', 'tea', 'boba', 'juice', 'makan',
      'minum', 'snack', 'diner', 'bistro', 'food', 'steak', 'canteen', 'kantin',
      'soto', 'pecel', 'gudeg', 'seblak', 'nasgor', 'ice cream', 'gelato',
    ];
    if (foodKeywords.any(search.contains)) return 'Makanan';

    // Transportasi
    final transportKeywords = [
      'spbu', 'pertamina', 'shell', 'bp ', 'bensin', 'solar', 'pertalite',
      'pertamax', 'parkir', 'parking', 'toll', 'tol', 'grab', 'gojek',
      'maxim', 'indrive', 'kai', 'kereta', 'tiket', 'travel', 'bengkel',
      'tambal ban', 'cuci motor', 'cuci mobil',
    ];
    if (transportKeywords.any(search.contains)) return 'Transportasi';

    // Belanja
    final shoppingKeywords = [
      'indomaret', 'alfamart', 'alfamidi', 'supermarket', 'hypermart',
      'transmart', 'superindo', 'lotte', 'mart', 'swalayan', 'minimarket',
      'pasar', 'mall', 'fashion', 'clothing', 'distro', 'miniso', 'uniqlo',
      'h&m', 'zara', 'watsons', 'guardian', 'belanja', 'toko',
    ];
    if (shoppingKeywords.any(search.contains)) return 'Belanja';

    // Kesehatan
    final healthKeywords = [
      'apotek', 'apotik', 'kimia farma', 'k24', 'k-24', 'farmasi', 'klinik',
      'clinic', 'rumah sakit', 'rs ', 'dokter', 'optik', 'laboratorium', 'obat',
    ];
    if (healthKeywords.any(search.contains)) return 'Kesehatan';

    // Hiburan
    final entKeywords = [
      'cinema', 'xxi', 'cgv', 'cinepolis', 'bioskop', 'game', 'playstation',
      'billiard', 'karaoke', 'netflix', 'spotify', 'wisata', 'taman', 'rekreasi',
    ];
    if (entKeywords.any(search.contains)) return 'Hiburan';

    // Rumah & Utilitas
    final homeKeywords = [
      'pln', 'listrik', 'pdam', 'air', 'wifi', 'indihome', 'biznet',
      'myrepublic', 'gas', 'lpg', 'ace hardware', 'informa', 'ikea',
      'mr. diy', 'mitra10', 'hardware',
    ];
    if (homeKeywords.any(search.contains)) return 'Rumah';

    // Pendidikan
    final eduKeywords = [
      'gramedia', 'buku', 'book', 'stationery', 'fotocopy', 'atk', 'kursus',
      'les', 'sekolah', 'kuliah', 'kampus',
    ];
    if (eduKeywords.any(search.contains)) return 'Pendidikan';

    return null;
  }
}
