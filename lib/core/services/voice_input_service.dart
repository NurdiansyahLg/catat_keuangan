import 'package:speech_to_text/speech_to_text.dart';

class VoiceTransactionResult {
  final int? amount;
  final bool isExpense;
  final String? categoryKeyword;
  final String rawText;

  const VoiceTransactionResult({
    this.amount,
    this.isExpense = true,
    this.categoryKeyword,
    required this.rawText,
  });
}

class VoiceInputService {
  VoiceInputService._internal();
  static final VoiceInputService instance = VoiceInputService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (val) {},
      onStatus: (val) {},
    );
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onListeningStatusChanged,
  }) async {
    final available = await init();
    if (!available) {
      onListeningStatusChanged(false);
      return;
    }

    onListeningStatusChanged(true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'id_ID'),
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onListeningStatusChanged(false);
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Parser pintar untuk mengurai ucapan Bahasa Indonesia menjadi data transaksi
  VoiceTransactionResult parseIndonesianSpeech(String speechText) {
    final text = speechText.toLowerCase().trim();
    if (text.isEmpty) {
      return VoiceTransactionResult(rawText: speechText);
    }

    // 1. Tentukan Tipe (Pemasukan vs Pengeluaran)
    final isExpense = _detectIsExpense(text);

    // 2. Tentukan Jumlah (Amount)
    final amount = _extractAmountFromText(text);

    // 3. Tentukan Kategori Otomatis berdasarkan kata kunci
    final category = _extractCategory(text, isExpense);

    return VoiceTransactionResult(
      amount: amount,
      isExpense: isExpense,
      categoryKeyword: category,
      rawText: speechText,
    );
  }

  /// Mendeteksi apakah ucapan mengindikasikan pengeluaran atau pemasukan
  static bool _detectIsExpense(String text) {
    final incomeVerbs = [
      'gaji', 'gajian', 'salary', 'payroll', 'upah', 'honor', 'thr',
      'omset', 'omzet', 'dividen', 'profit', 'untung', 'pendapatan',
      'transferan', 'kiriman', 'cuan', 'reksadana', 'saham', 'pemasukan',
      'dapat uang', 'terima uang', 'dapat', 'terima', 'masuk'
    ];
    final expenseVerbs = [
      'beli', 'bayar', 'belanja', 'ongkir', 'jajan', 'biaya', 'ongkos',
      'habis', 'tarif', 'sewa', 'tagihan', 'top up', 'topup', 'keluar',
      'pengeluaran', 'isi bensin', 'makan', 'minum', 'ngopi'
    ];

    bool hasIncome = incomeVerbs.any((w) => _containsWord(text, w));
    bool hasExpense = expenseVerbs.any((w) => _containsWord(text, w));

    if (hasIncome && !hasExpense) {
      return false;
    } else if (hasExpense && !hasIncome) {
      return true;
    } else if (hasIncome && hasExpense) {
      // Bandingkan posisi mana yang muncul lebih awal
      int firstInc = 999999;
      for (final w in incomeVerbs) {
        final idx = text.indexOf(w);
        if (idx != -1 && idx < firstInc) firstInc = idx;
      }
      int firstExp = 999999;
      for (final w in expenseVerbs) {
        final idx = text.indexOf(w);
        if (idx != -1 && idx < firstExp) firstExp = idx;
      }
      return firstExp <= firstInc;
    }

    return true; // Default pengeluaran
  }

  /// Ekstraksi kategori dari ucapan Bahasa Indonesia
  static String? _extractCategory(String text, bool isExpense) {
    if (isExpense) {
      // 1. Internet & Paket Data (diprioritaskan)
      const internetKeywords = [
        'internet', 'paket internet', 'wifi', 'wi-fi', 'paket data', 'data',
        'kuota', 'pulsa', 'indihome', 'biznet', 'first media', 'iconnet',
        'myrepublic', 'telkomsel', 'indosat', 'tri', 'xl', 'smartfren',
        'by.u', 'byu',
      ];
      if (internetKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Internet';
      }

      // 2. Makanan & Minuman
      const foodKeywords = [
        'makan', 'makanan', 'minum', 'minuman', 'sarapan', 'lunch', 'dinner',
        'jajan', 'jajanan', 'cemilan', 'camilan', 'snack', 'kopi', 'coffee',
        'ngopi', 'cafe', 'kafe', 'resto', 'restoran', 'restaurant', 'warung',
        'warteg', 'kedai', 'kantin', 'bakso', 'mie', 'nasi', 'ayam', 'sate',
        'soto', 'pecel', 'bebek', 'seblak', 'padang', 'martabak', 'roti',
        'kue', 'bakery', 'pizza', 'burger', 'steak', 'boba', 'jus',
        'ice cream', 'eskrim', 'gofood', 'grabfood', 'shopeefood', 'kfc',
        'mcd', 'dapur', 'sarap', 'kuliner', 'lauk', 'sayur', 'buah',
      ];
      if (foodKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Makanan';
      }

      // 3. Rumah & Properti (Listrik, Air, Gas, Sewa Rumah)
      const homeKeywords = [
        'listrik', 'pln', 'token', 'token listrik', 'air', 'pdam', 'gas',
        'lpg', 'elpiji', 'galon', 'aqua galon', 'kontrakan', 'kos', 'kost',
        'kostan', 'sewa rumah', 'iuran', 'kebersihan', 'sampah', 'keamanan',
        'renovasi', 'pompa air', 'pajak bumi', 'pbb', 'genteng', 'cat rumah',
        'ledeng', 'rumah',
      ];
      if (homeKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Rumah';
      }

      // 3. Transportasi & Kendaraan
      const transportKeywords = [
        'transport', 'transportasi', 'bensin', 'pertalite', 'pertamax', 'solar',
        'dexlite', 'spbu', 'pertamina', 'shell', 'ojol', 'gojek', 'goride',
        'gocar', 'grab', 'grabcar', 'maxim', 'indrive', 'taksi', 'taxi',
        'angkot', 'bus', 'transjakarta', 'kereta', 'krl', 'mrt', 'lrt',
        'tiket', 'pesawat', 'travel', 'parkir', 'tol', 'tambal ban',
        'bengkel', 'servis', 'service', 'cuci motor', 'cuci mobil', 'oli',
        'ganti oli', 'helm', 'stnk',
      ];
      if (transportKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Transportasi';
      }

      // 4. Kesehatan
      const healthKeywords = [
        'sehat', 'kesehatan', 'obat', 'apotek', 'apotik', 'dokter', 'klinik',
        'clinic', 'puskesmas', 'rumah sakit', 'rs ', 'vitamin', 'suplemen',
        'tensi', 'periksa', 'dokter gigi', 'dental', 'rontgen', 'pcr',
        'antigen', 'tes darah', 'perban', 'betadine', 'bpjs', 'kimia farma',
        'k24', 'k-24', 'jamu', 'masuk angin', 'paracetamol', 'panadol',
      ];
      if (healthKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Kesehatan';
      }

      // 5. Pendidikan
      const eduKeywords = [
        'pendidikan', 'edukasi', 'buku', 'atk', 'alat tulis', 'fotocopy',
        'fotokopi', 'print', 'kursus', 'les', 'spp', 'sekolah', 'kuliah',
        'semester', 'uang gedung', 'seragam', 'pensil', 'pulpen', 'ujian',
        'modul', 'bimbel', 'seminar', 'workshop', 'skripsi', 'wisuda',
      ];
      if (eduKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Pendidikan';
      }

      // 6. Hiburan
      const entertainKeywords = [
        'hiburan', 'nonton', 'bioskop', 'cinema', 'xxi', 'cgv', 'cinepolis',
        'film', 'movie', 'game', 'games', 'gaming', 'topup', 'top up',
        'diamond', 'mlbb', 'mobile legend', 'free fire', 'pubg', 'genshin',
        'steam', 'playstation', 'ps5', 'netflix', 'spotify', 'youtube premium',
        'disney', 'karaoke', 'liburan', 'rekreasi', 'wisata', 'jalan-jalan',
        'holiday', 'staycation', 'hotel', 'villa', 'konser', 'tiket konser',
      ];
      if (entertainKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Hiburan';
      }

      // 7. Belanja (Supermarket, Pakaian, Kebutuhan)
      const shoppingKeywords = [
        'belanja', 'indomaret', 'alfamart', 'alfamidi', 'superindo', 'hypermart',
        'transmart', 'minimarket', 'supermarket', 'pasar', 'mall', 'baju',
        'kaos', 'celana', 'kemeja', 'jaket', 'sepatu', 'sandal', 'tas',
        'dompet', 'shopee', 'tokopedia', 'lazada', 'tiktok shop', 'sabun',
        'sampo', 'shampoo', 'pasta gigi', 'odol', 'deterjen', 'skincare',
        'kosmetik', 'makeup', 'parfum', 'belanjaan', 'beli',
      ];
      if (shoppingKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Belanja';
      }

      // 8. Lainnya
      const otherKeywords = [
        'sedekah', 'infaq', 'infak', 'zakat', 'donasi', 'sumbangan', 'tips',
        'tip', 'denda', 'pajak', 'admin', 'biaya admin',
      ];
      if (otherKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Lainnya';
      }
    } else {
      // PEMASUKAN (INCOME)
      // 1. Gaji
      const salaryKeywords = [
        'gaji', 'gajian', 'salary', 'payroll', 'upah', 'honor', 'honorer',
        'thr', 'lembur', 'lemburan', 'tunjangan', 'pesangon',
      ];
      if (salaryKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Gaji';
      }

      // 2. Bisnis / Usaha
      const businessKeywords = [
        'bisnis', 'omzet', 'omset', 'jualan', 'dagang', 'orderan', 'proyek',
        'project', 'klien', 'client', 'tender', 'fee', 'komisi', 'toko',
        'usaha', 'untung', 'profit', 'invoice',
      ];
      if (businessKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Bisnis';
      }

      // 3. Investasi
      const investKeywords = [
        'investasi', 'invest', 'saham', 'dividen', 'reksadana', 'reksa dana',
        'crypto', 'kripto', 'bitcoin', 'btc', 'obligasi', 'sukuk', 'bunga',
        'deposito', 'trading', 'cuan',
      ];
      if (investKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Investasi';
      }

      // 4. Lainnya
      const otherIncomeKeywords = [
        'transfer', 'transferan', 'kiriman', 'hadiah', 'kado', 'gift',
        'cashback', 'bonus', 'undian', 'pinjaman', 'piutang', 'kembalian',
      ];
      if (otherIncomeKeywords.any((kw) => _containsWord(text, kw))) {
        return 'Lainnya';
      }
    }

    return null;
  }

  /// Pengecekan kata dengan pembatas kata (word boundary) agar tidak salah deteksi
  static bool _containsWord(String text, String keyword) {
    if (keyword.contains(' ') || keyword.contains('-')) {
      return text.contains(keyword);
    }
    return RegExp(r'\b' + RegExp.escape(keyword) + r'\b').hasMatch(text);
  }

  /// Ekstraksi jumlah uang (nominal) dari teks numerik atau kata-kata Bahasa Indonesia
  static int? _extractAmountFromText(String text) {
    // 1. Normalisasi teks:
    // a. Hapus prefix mata uang seperti 'rp', 'rp.', 'idr' yang menempel langsung ke angka
    //    cth: "rp20.000" -> " 20.000", "rp.20000" -> " 20000"
    String normalized = text.replaceAll(
      RegExp(r'\b(rp|idr)\.?\s*', caseSensitive: false),
      ' ',
    );

    // b. Bersihkan desimal sen rupiah di akhir nominal (cth: ",00" atau ".00" di akhir angka)
    //    cth: "20.000,00" -> "20.000"
    normalized = normalized.replaceAll(RegExp(r'(?<=\d)[,\.]00(?!\d)'), '');

    // 2. Pola Angka dengan Suffix: cth "10 ribu", "2.5 juta", "50rb", "100k", "1.5jt"
    final suffixReg = RegExp(
      r'(\d+(?:[,\.]\d+)?)\s*(juta|jt|ribu|rb|k)\b',
      caseSensitive: false,
    );
    final suffixMatch = suffixReg.firstMatch(normalized);
    if (suffixMatch != null) {
      final numStr = suffixMatch.group(1)!.replaceAll(',', '.');
      final unit = suffixMatch.group(2)!.toLowerCase();
      final numVal = double.tryParse(numStr);
      if (numVal != null && numVal > 0) {
        if (unit == 'juta' || unit == 'jt') {
          return (numVal * 1000000).round();
        } else if (unit == 'ribu' || unit == 'rb' || unit == 'k') {
          return (numVal * 1000).round();
        }
      }
    }

    // 3. Pola Angka Berformat Ribuan: cth "10.000", "250.000", "1.500.000"
    final formattedReg = RegExp(r'(?:^|[^\d])(\d{1,3}(?:\.\d{3})+)(?:[^\d]|$)');
    final formattedMatch = formattedReg.firstMatch(normalized);
    if (formattedMatch != null) {
      final cleanNum = formattedMatch.group(1)!.replaceAll('.', '');
      final parsed = int.tryParse(cleanNum);
      if (parsed != null && parsed > 0) return parsed;
    }

    // 4. Pola Angka Numerik Biasa: cth "10000", "50000"
    final numReg = RegExp(r'(?:^|[^\d])(\d+)(?:[^\d]|$)');
    final matches = numReg.allMatches(normalized);
    for (final match in matches) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) {
        // Cek jika teks secara umum mengandung kata pengali
        if (normalized.contains('juta') || normalized.contains('jt')) {
          return parsed < 1000 ? parsed * 1000000 : parsed;
        } else if (normalized.contains('ribu') || normalized.contains('rb') || normalized.contains('k')) {
          return parsed < 1000 ? parsed * 1000 : parsed;
        }
        return parsed;
      }
    }

    // 5. Pola Kata-Kata Angka Bahasa Indonesia: cth "sepuluh ribu", "dua puluh lima ribu"
    return _parseIndonesianWordNumbers(normalized);
  }

  /// Parser kata-kata numerik Bahasa Indonesia (misal: "dua puluh lima ribu" -> 25000)
  static int? _parseIndonesianWordNumbers(String text) {
    final t = text.toLowerCase();
    if (t.contains('setengah juta')) return 500000;
    if (t.contains('sejuta')) return 1000000;
    if (t.contains('seratus ribu')) return 100000;
    if (t.contains('sepuluh ribu')) return 10000;
    if (t.contains('sebelas ribu')) return 11000;
    if (t.contains('seribu')) return 1000;

    const unitMap = {
      'nol': 0, 'kosong': 0,
      'satu': 1, 'se': 1, 'dua': 2, 'tiga': 3, 'empat': 4,
      'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9,
      'sepuluh': 10, 'sebelas': 11,
    };

    int total = 0;
    int currentGroup = 0;
    int currentVal = 0;
    bool foundAnyNumber = false;

    final words = t.replaceAll(RegExp(r'[^a-z\s]'), ' ').split(RegExp(r'\s+'));

    for (final w in words) {
      if (unitMap.containsKey(w)) {
        currentVal += unitMap[w]!;
        foundAnyNumber = true;
      } else if (w == 'belas') {
        currentVal = currentVal > 0 && currentVal < 10 ? 10 + currentVal : 10;
        foundAnyNumber = true;
      } else if (w == 'puluh') {
        if (currentVal == 0) currentVal = 1;
        currentGroup += currentVal * 10;
        currentVal = 0;
        foundAnyNumber = true;
      } else if (w == 'ratus') {
        if (currentVal == 0) currentVal = 1;
        currentGroup += currentVal * 100;
        currentVal = 0;
        foundAnyNumber = true;
      } else if (w == 'seratus') {
        currentGroup += 100;
        foundAnyNumber = true;
      } else if (w == 'ribu') {
        if (currentVal == 0 && currentGroup == 0) currentVal = 1;
        total += (currentGroup + currentVal) * 1000;
        currentGroup = 0;
        currentVal = 0;
        foundAnyNumber = true;
      } else if (w == 'seribu') {
        total += 1000;
        currentVal = 0;
        foundAnyNumber = true;
      } else if (w == 'juta') {
        if (currentVal == 0 && currentGroup == 0) currentVal = 1;
        total += (currentGroup + currentVal) * 1000000;
        currentGroup = 0;
        currentVal = 0;
        foundAnyNumber = true;
      } else if (w == 'sejuta') {
        total += 1000000;
        currentVal = 0;
        foundAnyNumber = true;
      }
    }

    total += currentGroup + currentVal;
    return foundAnyNumber && total > 0 ? total : null;
  }
}
