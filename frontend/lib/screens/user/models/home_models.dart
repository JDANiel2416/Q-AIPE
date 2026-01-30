import '../../../models/search_models.dart';

// --- ENUMS ---
enum MessageType { user, botThinking, botResponse, orderSummary }

enum AppMode { chat, store }

// --- CLASES ---
class ChatMessage {
  final MessageType type;
  final String? text;
  final List<BodegaSearchResult>? results;
  final String? audioPath; // Nuevo: Para mensajes de voz
  bool isAnimated;

  ChatMessage({
    required this.type,
    this.text,
    this.results,
    this.audioPath,
    this.isAnimated = false,
  });
}
