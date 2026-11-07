import 'dart:io';
import 'package:http/http.dart' as http;

class TelegramService {
  TelegramService._internal();
  static final TelegramService instance = TelegramService._internal();

  static const String _baseUrl = 'https://api.telegram.org/bot';

  /// Test bot token validity via getMe endpoint
  Future<bool> testBotToken(String botToken) async {
    if (botToken.trim().isEmpty) return false;
    try {
      final uri = Uri.parse('$_baseUrl${botToken.trim()}/getMe');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Test connection by sending a test message to chatId
  Future<bool> testConnection({
    required String botToken,
    required String chatId,
  }) async {
    if (botToken.trim().isEmpty || chatId.trim().isEmpty) return false;
    return sendTextMessage(
      botToken: botToken,
      chatId: chatId,
      text: '🤖 *Catat Keuangan*\\n\\n'
          '✅ Tes koneksi berhasil\\! Aplikasi Anda telah terhubung ke bot Telegram ini\\.',
      parseMode: 'MarkdownV2',
    );
  }

  /// Send a text message to Telegram Chat
  Future<bool> sendTextMessage({
    required String botToken,
    required String chatId,
    required String text,
    String? parseMode,
  }) async {
    final token = botToken.trim();
    final chat = chatId.trim();
    if (token.isEmpty || chat.isEmpty) return false;

    try {
      final uri = Uri.parse('$_baseUrl$token/sendMessage');
      final body = <String, String>{
        'chat_id': chat,
        'text': text,
      };
      if (parseMode != null) {
        body['parse_mode'] = parseMode;
      }

      final response = await http
          .post(uri, body: body)
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Send a file/document (e.g. backup JSON or DB) to Telegram Chat
  Future<bool> sendDocument({
    required String botToken,
    required String chatId,
    required String filePath,
    String? caption,
    String? parseMode,
  }) async {
    final token = botToken.trim();
    final chat = chatId.trim();
    if (token.isEmpty || chat.isEmpty) return false;

    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final uri = Uri.parse('$_baseUrl$token/sendDocument');
      final request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = chat;
      if (caption != null) {
        request.fields['caption'] = caption;
      }
      if (parseMode != null) {
        request.fields['parse_mode'] = parseMode;
      }

      final multipartFile = await http.MultipartFile.fromPath('document', filePath);
      request.files.add(multipartFile);

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
