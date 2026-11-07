import 'package:shared_preferences/shared_preferences.dart';

/// Service untuk menyimpan saldo awal per dompet.
/// Saldo awal disimpan di SharedPreferences.
class WalletSettingsService {
  WalletSettingsService._internal();
  static final WalletSettingsService instance = WalletSettingsService._internal();

  static const _prefix = 'wallet_initial_';
  static const wallets = ['Dompet Utama', 'Bank', 'E-Wallet', 'Tunai'];

  /// Ambil saldo awal untuk dompet tertentu
  Future<int> getInitialBalance(String walletName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$walletName') ?? 0;
  }

  /// Simpan saldo awal untuk dompet tertentu
  Future<void> setInitialBalance(String walletName, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$walletName', amount);
  }

  /// Ambil semua saldo awal sekaligus
  Future<Map<String, int>> getAllInitialBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, int>{};
    for (final wallet in wallets) {
      map[wallet] = prefs.getInt('$_prefix$wallet') ?? 0;
    }
    return map;
  }

  /// Hitung total saldo awal keseluruhan
  Future<int> getTotalInitialBalance() async {
    final all = await getAllInitialBalances();
    int total = 0;
    for (final v in all.values) {
      total += v;
    }
    return total;
  }
}
