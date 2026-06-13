import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_theme.dart';
import '../services/chat_service.dart';

/// Osadzony czat meczu — sekcja w szczegółach meczu, wspólna dla wszystkich
/// typujących. Pokój tworzony leniwie (get-or-create po match_id), wiadomości
/// na żywo przez Supabase Realtime.
class MatchChatWidget extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String? userId;
  final String? username;

  /// Kontekst ligi: null = czat globalny, inaczej osobny czat prywatnej ligi.
  final String? leagueId;

  const MatchChatWidget({
    super.key,
    required this.matchId,
    required this.matchName,
    required this.userId,
    required this.username,
    this.leagueId,
  });

  @override
  State<MatchChatWidget> createState() => _MatchChatWidgetState();
}

class _MatchChatWidgetState extends State<MatchChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _roomId;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final room = await ChatService.getOrCreateMatchRoom(
          widget.matchId,
          widget.leagueId == null
              ? 'Czat: ${widget.matchName}'
              : 'Czat ligowy: ${widget.matchName}',
          widget.userId!,
          leagueId: widget.leagueId);
      final roomId = room['id'] as String;
      final messages = await ChatService.getMessages(roomId);

      if (!mounted) return;
      setState(() {
        _roomId = roomId;
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();

      _channel = ChatService.subscribeToMessages(roomId, (message) {
        if (!mounted) return;
        // Insert przychodzi też do nadawcy — pomijamy duplikaty
        if (_messages.any((m) => m['id'] == message['id'])) return;
        setState(() => _messages.add(message));
        _scrollToBottom();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nie udało się załadować czatu';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ChatService.sendMessage(
          _roomId!, text, widget.username ?? 'Gracz');
      _messageController.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się wysłać wiadomości')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.leagueId == null ? 'CZAT MECZU' : 'CZAT LIGI',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_messages.isNotEmpty)
                Text('${_messages.length}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppTheme.primaryColor, strokeWidth: 2),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12)),
              ),
            )
          else if (widget.userId == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Zaloguj się, aby pisać na czacie meczu',
                    style: TextStyle(
                        color: AppTheme.textTertiary, fontSize: 12)),
              ),
            )
          else ...[
            // Lista wiadomości — ograniczona wysokość, przewijana
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: _messages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Brak wiadomości — napisz pierwszy\ni zagadaj innych typujących!',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _buildMessage(_messages[i]),
                    ),
            ),
            const SizedBox(height: 12),
            // Pole wpisywania
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    maxLength: 280,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Napisz wiadomość…',
                      hintStyle: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.6)),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isMine = message['user_id'] == widget.userId;
    final username = (message['username'] as String?) ?? 'Gracz';
    final content = (message['content'] as String?) ?? '';
    final created =
        DateTime.tryParse(message['created_at'] as String? ?? '')?.toLocal();
    final time = created != null
        ? '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          // Jaśniejsze dymki — surface zlewał się z tłem karty czatu
          color: isMine
              ? AppTheme.primaryColor.withValues(alpha: 0.22)
              : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(username,
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            Text(content,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14)),
            const SizedBox(height: 2),
            Text(time,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
