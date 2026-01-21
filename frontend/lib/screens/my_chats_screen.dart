import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class MyChatsScreen extends StatefulWidget {
  const MyChatsScreen({super.key});

  @override
  State<MyChatsScreen> createState() => _MyChatsScreenState();
}

class _MyChatsScreenState extends State<MyChatsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final userId = await SessionService().getUserId();
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    _userId = userId;
    final chats = await _apiService.getUserChats(userId);
    
    if (mounted) {
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChat(String chatId, bool isCurrent) async {
    // Mostrar confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[400], size: 28),
            const SizedBox(width: 12),
            const Text("Eliminar chat", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          isCurrent 
            ? "Este es tu chat actual. Al eliminarlo se creará uno nuevo automáticamente. ¿Continuar?"
            : "¿Seguro que quieres eliminar este chat? Esta acción no se puede deshacer.",
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancelar", style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    
    if (confirm != true || _userId == null) return;
    
    // Mostrar loading
    setState(() => _isLoading = true);
    
    final result = await _apiService.deleteChatSession(_userId!, chatId);
    
    if (result['deleted'] == true) {
      // Recargar lista
      await _loadChats();
      
      // Si era el chat activo y se creó uno nuevo, retornar con el nuevo ID
      if (result['was_active'] == true && result['new_session_id'] != null) {
        if (mounted) {
          Navigator.pop(context, {
            'action': 'deleted_current',
            'new_session_id': result['new_session_id'],
          });
        }
      } else {
        // Mostrar snackbar de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Chat eliminado"),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error al eliminar el chat"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectChat(Map<String, dynamic> chat) async {
    if (_userId == null) return;
    
    final isCurrent = chat['is_current'] == true;
    
    if (isCurrent) {
      // Ya es el chat actual, solo regresar
      Navigator.pop(context, {
        'action': 'selected',
        'session_id': chat['id'],
        'title': chat['title'],
        'is_current': true,
      });
      return;
    }
    
    // Activar este chat como el actual
    setState(() => _isLoading = true);
    
    final result = await _apiService.activateChatSession(_userId!, chat['id']);
    
    if (result.isNotEmpty) {
      if (mounted) {
        Navigator.pop(context, {
          'action': 'selected',
          'session_id': chat['id'],
          'title': result['title'] ?? chat['title'],
          'is_current': false, // Indica que cambió
        });
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error al cargar el chat"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createNewChat() async {
    if (_userId == null) return;
    
    setState(() => _isLoading = true);
    
    final result = await _apiService.createNewChatSession(_userId!);
    
    if (result.isNotEmpty && result['session_id'] != null) {
      if (mounted) {
        Navigator.pop(context, {
          'action': 'new',
          'session_id': result['session_id'],
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Mis Chats",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Botón nuevo chat
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _isLoading ? null : _createNewChat,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Color(0xFF00D9FF), size: 20),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D9FF)))
          : _chats.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  color: const Color(0xFF00D9FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chats.length,
                    itemBuilder: (context, index) => _buildChatItem(_chats[index], index),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            "No tienes chats",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            "Inicia una conversación para pedir productos",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _createNewChat,
            icon: const Icon(Icons.add),
            label: const Text("Nuevo Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, int index) {
    final isCurrent = chat['is_current'] == true;
    final hasProducts = chat['has_products'] == true;
    final messageCount = chat['message_count'] ?? 0;
    final title = chat['title'] ?? "Chat ${index + 1}";
    
    return Dismissible(
      key: Key(chat['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        await _deleteChat(chat['id'], isCurrent);
        return false; // No permitir que Dismissible elimine, lo manejamos manualmente
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _selectChat(chat),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isCurrent
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF00D9FF).withOpacity(0.15),
                          const Color(0xFF00D9FF).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCurrent ? null : const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrent 
                      ? const Color(0xFF00D9FF).withOpacity(0.4) 
                      : Colors.white.withOpacity(0.05),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Icono con estado
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isCurrent 
                          ? const Color(0xFF00D9FF).withOpacity(0.2)
                          : hasProducts
                              ? Colors.green.withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasProducts ? Icons.shopping_cart_outlined : Icons.chat_bubble_outline,
                      color: isCurrent 
                          ? const Color(0xFF00D9FF)
                          : hasProducts
                              ? Colors.green[400]
                              : Colors.white54,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Info del chat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D9FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "ACTUAL",
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 9, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.message_outlined, 
                              size: 12, 
                              color: Colors.white.withOpacity(0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$messageCount mensaje${messageCount == 1 ? '' : 's'}",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4), 
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (chat['last_message'] != null) ...[
                              Expanded(
                                child: Text(
                                  "• ${chat['last_message']}",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35), 
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Botón eliminar
                  IconButton(
                    onPressed: () => _deleteChat(chat['id'], isCurrent),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.white.withOpacity(0.3),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
