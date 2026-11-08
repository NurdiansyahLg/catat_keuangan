import 'package:flutter_test/flutter_test.dart';
import 'package:catat_keuangan/core/services/voice_input_service.dart';

void main() {
  group('VoiceInputService Indonesian Speech Parser Tests', () {
    test('User test case: "aku beli makan 10000" should map to Makanan with amount 10000', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('aku beli makan 10000');
      expect(res.amount, 10000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Makanan');
    });

    test('User test case: "bayar internet 250000" should map to Rumah with amount 250000', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('bayar internet 250000');
      expect(res.amount, 250000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Rumah');
    });

    test('User test case: "bayar wifi indihome 350 ribu" should map to Rumah with amount 350000', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('bayar wifi indihome 350 ribu');
      expect(res.amount, 350000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Rumah');
    });

    test('Transport category: "isi bensin pertalite 50000"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('isi bensin pertalite 50000');
      expect(res.amount, 50000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Transportasi');
    });

    test('Health category: "beli obat flu 25 ribu"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('beli obat flu 25 ribu');
      expect(res.amount, 25000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Kesehatan');
    });

    test('Education category: "bayar spp sekolah 300rb"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('bayar spp sekolah 300rb');
      expect(res.amount, 300000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Pendidikan');
    });

    test('Entertainment category: "nonton bioskop xxi 50 ribu"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('nonton bioskop xxi 50 ribu');
      expect(res.amount, 50000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Hiburan');
    });

    test('Shopping category: "beli baju kaos di mall 120000"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('beli baju kaos di mall 120000');
      expect(res.amount, 120000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Belanja');
    });

    test('Income salary: "gaji bulanan 5 juta"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('gaji bulanan 5 juta');
      expect(res.amount, 5000000);
      expect(res.isExpense, false);
      expect(res.categoryKeyword, 'Gaji');
    });

    test('Income business: "omzet jualan online hari ini 500 ribu"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('omzet jualan online hari ini 500 ribu');
      expect(res.amount, 500000);
      expect(res.isExpense, false);
      expect(res.categoryKeyword, 'Bisnis');
    });

    test('Income investment: "dividen saham 150000"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('dividen saham 150000');
      expect(res.amount, 150000);
      expect(res.isExpense, false);
      expect(res.categoryKeyword, 'Investasi');
    });

    test('Spoken numbers in words: "beli makan dua puluh lima ribu"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('beli makan dua puluh lima ribu');
      expect(res.amount, 25000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Makanan');
    });

    test('Spoken numbers decimal: "bayar kos satu koma lima juta"', () {
      final res = VoiceInputService.instance.parseIndonesianSpeech('bayar kos 1.5 juta');
      expect(res.amount, 1500000);
      expect(res.isExpense, true);
      expect(res.categoryKeyword, 'Rumah');
    });
  });
}
