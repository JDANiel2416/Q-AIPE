import '../../../models/search_models.dart';

// --- ENUMS ---
enum MessageType { user, botThinking, botResponse, orderSummary }

enum AppMode { chat, store }

// --- CLASES ---
class ChatMessage {
  final String? id; // Nuevo: Identificador único del mensaje
  final MessageType type;
  final String? text;
  final List<BodegaSearchResult>? results;
  final String? audioPath;
  bool isAnimated;
  bool isReserved;
  String? selectedBodegaId;
  Map<String, dynamic>? ticketData;

  ChatMessage({
    this.id,
    required this.type,
    this.text,
    this.results,
    this.audioPath,
    this.isAnimated = false,
    this.isReserved = false,
    this.selectedBodegaId,
    this.ticketData,
  });
}
