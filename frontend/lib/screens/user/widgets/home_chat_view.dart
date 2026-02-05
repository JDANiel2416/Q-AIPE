import 'package:flutter/material.dart';
import '../home_colors.dart';
import '../models/home_models.dart';
import '../../../widgets/common/chat_widgets.dart';
import 'bodega_card.dart';
import 'unified_order_card.dart';
import 'voice_message_bubble.dart';
import '../../../models/search_models.dart';

class HomeChatView extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isChatStarted;
  final bool hasLocation;
  final bool isLoading;
  final ScrollController scrollController;
  final Function(BodegaSearchResult) onViewMap;
  final Function(BodegaSearchResult) onReserve;
  final Function(List<BodegaSearchResult>)? onConfirmOrder;
  final Function(ChatMessage) onCompleteTyping;
  final Function(Map<String, dynamic>)? onViewTicket;
  final Function(String)? onRemoveItem; // Nuevo callback

  const HomeChatView({
    super.key,
    required this.messages,
    required this.isChatStarted,
    required this.hasLocation,
    required this.isLoading,
    required this.scrollController,
    required this.onViewMap,
    required this.onReserve,
    this.onConfirmOrder,
    required this.onCompleteTyping,
    this.onViewTicket,
    this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return !isChatStarted
        ? _buildWelcomeView(context)
        : _buildChatList(context);
  }

  Widget _buildWelcomeView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    HomeColors.primaryLight(context),
                    HomeColors.primary(context).withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HomeColors.primary(context).withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 40,
                color: HomeColors.primary(context),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasLocation ? Icons.location_on : Icons.location_searching,
                  color: hasLocation
                      ? HomeColors.primary(context)
                      : HomeColors.textMuted(context),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  hasLocation
                      ? "¡Ubicación detectada!"
                      : "Buscando satélites...",
                  style: TextStyle(
                    color: HomeColors.textSecondary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "¿Qué pedimos hoy?",
              style: TextStyle(
                color: HomeColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    // Lista invertida: index 0 = mensaje más reciente (aparece arriba visualmente)
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 100,
        bottom: MediaQuery.of(context).padding.top + 72,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        // index 0 = último mensaje de la lista (más reciente)
        final msg = messages[messages.length - 1 - index];
        return _buildMessageItem(context, msg);
      },
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _contentForMessage(context, msg),
    );
  }

  Widget _contentForMessage(BuildContext context, ChatMessage msg) {
    if (msg.type == MessageType.user) {
      if (msg.audioPath != null) {
        return Align(
          alignment: Alignment.centerRight,
          child: VoiceMessageBubble(audioPath: msg.audioPath!, isUser: true),
        );
      }
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: HomeColors.primary(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: HomeColors.primary(context).withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text ?? "",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    } else if (msg.type == MessageType.botThinking) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: HomeColors.textSecondary(context),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Pensando...",
                style: TextStyle(
                  color: HomeColors.textSecondary(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (msg.type == MessageType.orderSummary) {
      return UnifiedOrderCard(
        results: msg.results ?? [],
        onConfirmAll: () => onConfirmOrder?.call(msg.results ?? []),
        onChangeSelection: onViewMap,
        isReserved: msg.isReserved,
        onViewTicket: () => onViewTicket?.call(msg.ticketData ?? {}),
        onRemoveItem: onRemoveItem, // Pasamos el callback
      );
    } else {
      // Bot response - flat LLM style
      // Usamos AnimatedSize para que el crecimiento del texto sea fluido
      return Align(
        alignment: Alignment.centerLeft,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.text != null && msg.text!.isNotEmpty)
                msg.isAnimated
                    ? Text(
                        msg.text!,
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      )
                    : TypingMessage(
                        text: msg.text!,
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontSize: 15,
                          height: 1.6,
                        ),
                        onComplete: () => onCompleteTyping(msg),
                      ),

              if (msg.isAnimated &&
                  msg.results != null &&
                  msg.results!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...msg.results!
                    .where(
                      (bodega) =>
                          !msg.isReserved ||
                          bodega.bodegaId == msg.selectedBodegaId,
                    )
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                      return StaggeredItem(
                        index: entry.key,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BodegaCard(
                            bodega: entry.value,
                            onReserve: () {
                              if (msg.isReserved) {
                                onViewTicket?.call(msg.ticketData ?? {});
                              } else {
                                onReserve(entry.value);
                              }
                            },
                            onViewMap: () => onViewMap(entry.value),
                            isReserved:
                                msg.isReserved &&
                                entry.value.bodegaId == msg.selectedBodegaId,
                          ),
                        ),
                      );
                    }),
              ],
            ],
          ),
        ),
      );
    }
  }
}
