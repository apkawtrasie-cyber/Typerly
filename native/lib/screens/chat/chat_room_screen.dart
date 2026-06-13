import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../../widgets/qr_invite_dialog.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String inviteCode;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.inviteCode,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _channel;
  bool _loading = true;
  int _memberCount = 0;
  String _myUserId = '';
  String _myUsername = '';

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadMessages();
    _subscribeRealtime();
    _loadMemberCount();
    _markRead();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _myUserId = user.id;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      _myUsername = profile['username'] as String? ?? user.email ?? 'Użytkownik';
    } catch (_) {
      _myUsername = user.email ?? 'Użytkownik';
    }
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ChatService.getMessages(widget.roomId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Błąd ładowania wiadomości: $e');
      }
    }
  }

  Future<void> _loadMemberCount() async {
    try {
      final count = await ChatService.getMemberCount(widget.roomId);
      if (mounted) setState(() => _memberCount = count);
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _channel = ChatService.subscribeToMessages(widget.roomId, (newMsg) {
      if (mounted) {
        setState(() => _messages.add(newMsg));
        _scrollToBottom();
        _markRead();
      }
    });
  }

  void _markRead() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      ChatService.markRead(widget.roomId, userId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;
    _inputController.clear();
    try {
      await ChatService.sendMessage(widget.roomId, content, _myUsername);
    } catch (e) {
      _showError('Błąd wysyłania: $e');
    }
  }

  void _shareInviteCode() {
    Share.share(
      'Dołącz do grupy "${widget.roomName}" w Typerly!\nKod: ${widget.inviteCode}',
      subject: 'Zaproszenie do grupy Typerly',
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AppTheme.errorColor,
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AppTheme.successColor,
    ));
  }

  Future<void> _showAddMemberDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Dodaj osobę', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Nazwa użytkownika'),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Dodaj', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await ChatService.addMemberByUsername(widget.roomId, result);
      await _loadMemberCount();
      _showSuccess('Dodano użytkownika "$result"!');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.roomName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              if (_memberCount > 0)
                Text(
                  '$_memberCount członków',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Dodaj osobę',
              onPressed: _showAddMemberDialog,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'Pokaż kod QR',
              onPressed: () => showQrInviteDialog(
                context: context,
                code: widget.inviteCode,
                name: widget.roomName,
                shareText: 'Dołącz do grupy "${widget.roomName}" w Typerly!\nKod: ${widget.inviteCode}',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Udostępnij kod',
              onPressed: _shareInviteCode,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Brak wiadomości. Napisz pierwszą!',
                            style: TextStyle(color: AppTheme.textTertiary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _buildMessageBubble(_messages[index]),
                        ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['user_id'] == _myUserId;
    final username = message['username'] as String? ?? 'Użytkownik';
    final content = message['content'] as String? ?? '';
    final createdAt = message['created_at'] as String? ?? '';
    final time = _formatTime(createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      username,
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryColor
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isMe
                          ? AppTheme.backgroundColor
                          : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    time,
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border(top: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Napisz wiadomość...',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.backgroundColor, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
