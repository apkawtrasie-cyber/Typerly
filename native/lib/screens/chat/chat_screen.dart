import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await ChatService.getMyRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Błąd ładowania czatów: $e');
      }
    }
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

  Future<void> _showCreateGroupDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Nowa grupa', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nazwa grupy',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Utwórz', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      final username = profile['username'] as String? ?? user.email ?? 'Użytkownik';

      final room = await ChatService.createRoom(result, user.id, username);
      await _loadRooms();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              roomId: room['id'] as String,
              roomName: room['name'] as String,
              inviteCode: room['invite_code'] as String,
            ),
          ),
        ).then((_) => _loadRooms());
      }
    } catch (e) {
      _showError('Błąd tworzenia grupy: $e');
    }
  }

  Future<void> _showJoinByCodeDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Dołącz do grupy', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Podaj 8-znakowy kod zaproszenia',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 8,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                letterSpacing: 4,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'XXXXXXXX',
                counterText: '',
              ),
              onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Dołącz', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      final username = profile['username'] as String? ?? user.email ?? 'Użytkownik';

      final room = await ChatService.joinRoomByCode(result, user.id, username);
      await _loadRooms();
      _showSuccess('Dołączono do grupy "${room['name']}"!');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              roomId: room['id'] as String,
              roomName: room['name'] as String,
              inviteCode: room['invite_code'] as String,
            ),
          ),
        ).then((_) => _loadRooms());
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Czat'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Dołącz przez kod',
              onPressed: _showJoinByCodeDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nowa grupa',
              onPressed: _showCreateGroupDialog,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _rooms.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: AppTheme.cardColor,
                    onRefresh: _loadRooms,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _rooms.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppTheme.dividerColor, indent: 72),
                      itemBuilder: (context, index) => _buildRoomTile(_rooms[index]),
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateGroupDialog,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.backgroundColor,
          icon: const Icon(Icons.group_add),
          label: const Text('Nowa grupa', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: AppTheme.textTertiary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Brak czatów.',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Utwórz grupę lub dołącz do istniejącej.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final lastMessage = room['last_message'] as Map<String, dynamic>?;
    final unreadCount = room['unread_count'] as int? ?? 0;
    final name = room['name'] as String? ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15),
      ),
      subtitle: lastMessage != null
          ? Text(
              '${lastMessage['username']}: ${lastMessage['content']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            )
          : const Text(
              'Brak wiadomości',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
      trailing: unreadCount > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                    color: AppTheme.backgroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              roomId: room['id'] as String,
              roomName: name,
              inviteCode: room['invite_code'] as String? ?? '',
            ),
          ),
        ).then((_) => _loadRooms());
      },
    );
  }
}
