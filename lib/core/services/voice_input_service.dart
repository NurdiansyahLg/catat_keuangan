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
    bool isExpense = true;
    final incomeKeywords = ['pemasukan', 'gaji', 'dapat', 'terima', 'masuk', 'bonus', 'hasil'];
    for (final kw in incomeKeywords) {
      if (text.contains(kw)) {
        isExpense = false;
        break;
      }
    }

    // 2. Tentukan Jumlah (Amount)
    int? amount = _extractAmountFromText(text);

    return VoiceTransactionResult(
      amount: amount,
      isExpense: isExpense,
      rawText: speechText,
    );
  }

  int? _extractAmountFromText(String text) {
    // Cari angka numerik langsung (cth: "50000", "150.000")
    final numReg = RegExp(r'(\d+[\d\.]*)');
    final numMatch = numReg.firstMatch(text);
    if (numMatch != null) {
      final rawNum = numMatch.group(1)!.replaceAll('.', '');
      final parsed = int.tryParse(rawNum);
      if (parsed != null && parsed > 0) {
        // Cek jika diikuti "ribu" atau "juta"
        if (text.contains('juta')) {
          return parsed < 1000 ? parsed * 1000000 : parsed;
        } else if (text.contains('ribu') || text.contains('rb')) {
          return parsed < 1000 ? parsed * 1000 : parsed;
        }
        return parsed;
      }
    }

    // Kata-kata jumlah dasar Bahasa Indonesia

    final wordsMap = {
      'satu': 1, 'se': 1, 'dua': 2, 'tiga': 3, 'empat': 4,
      'lima': 5, 'enam': 6, 'tujuh': 7, 'delapan': 8, 'sembilan': 9, 'sepuluh': 10,
      'sebelas': 11, 'seratus': 100, 'seribu': 1000, 'sejuta': 1000000,
    };

    if (text.contains('juta')) {
      final beforeJuta = text.split('juta').first;
      final num = _parseNumberWords(beforeJuta, wordsMap);
      if (num != null) return num * 1000000;
    }

    if (text.contains('ribu') || text.contains('rb')) {
      final beforeRibu = text.split(text.contains('ribu') ? 'ribu' : 'rb').first;
      final num = _parseNumberWords(beforeRibu, wordsMap);
      if (num != null) return num * 1000;
    }

    return null;
  }

  int? _parseNumberWords(String text, Map<String, int> wordsMap) {
    final numReg = RegExp(r'(\d+)');
    final match = numReg.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    for (final entry in wordsMap.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
