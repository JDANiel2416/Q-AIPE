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
  final VoidCallback? onConfirmOrder;
  final Function(ChatMessage) onCompleteTyping;

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
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Scroll notification logic handled by controller in parent?
              // Or we can expose a callback if needed.
              // Parent handles onScroll via _scrollController.addListener, so this might be redundant unless we want specific events.
              return false;
            },
            child: !isChatStarted
                ? _buildWelcomeView(context)
                : _buildChatList(context),
          ),
        ),
      ],
    );
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
            // Texto dinámico según si tenemos ubicación
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
    return RepaintBoundary(
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top:
              MediaQuery.of(context).padding.top + 80, // Espacio para el AppBar
          bottom: 100, // Espacio para el Input Area
        ),
        itemCount: messages.length,
        itemBuilder: (context, index) =>
            _buildMessageItem(context, messages[index]),
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage msg) {
    return RepaintBoundary(
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Opacity(opacity: value.clamp(0.0, 1.0), child: child);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _contentForMessage(context, msg),
        ),
      ),
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
                color: HomeColors.primary(context).withOpacity(0.2),
                blurRadius: 8,
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
      return Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HomeColors.primary(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Consultando bodegas cercanas...",
            style: TextStyle(
              color: HomeColors.textMuted(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (msg.type == MessageType.orderSummary) {
      return UnifiedOrderCard(
        results: msg.results ?? [],
        onConfirmAll: onConfirmOrder ?? () {},
        onChangeSelection: onViewMap,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.text != null && msg.text!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HomeColors.surface(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: HomeColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: HomeColors.shadowLight(context),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.isAnimated
                  ? Text(
                      msg.text!,
                      style: TextStyle(
                        color: HomeColors.textPrimary(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  : TypingMessage(
                      text: msg.text!,
                      style: TextStyle(
                        color: HomeColors.textPrimary(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      onComplete: () => onCompleteTyping(msg),
                    ),
            ),

          if (msg.isAnimated && msg.results != null && msg.results!.isNotEmpty)
            ...msg.results!.asMap().entries.map((entry) {
              return StaggeredItem(
                index: entry.key,
                child: BodegaCard(
                  bodega: entry.value,
                  onReserve: () => onReserve(entry.value),
                  onViewMap: () => onViewMap(entry.value),
                ),
              );
            }),
        ],
      );
    }
  }
}
