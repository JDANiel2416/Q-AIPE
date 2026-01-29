import '../../../models/search_models.dart';

// --- ENUMS ---
enum MessageType { user, botThinking, botResponse }

enum AppMode { chat, store }

// --- CLASES ---
class ChatMessage {
  final MessageType type;
  final String? text;
  final List<BodegaSearchResult>? results;
  bool isAnimated; // Nuevo: Para controlar estado de animación

  ChatMessage({
    required this.type,
    this.text,
    this.results,
    this.isAnimated = false,
  });
}
