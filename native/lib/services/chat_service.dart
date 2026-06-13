import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class ChatService {
  static SupabaseClient get _client => SupabaseConfig.client;

  static Future<List<Map<String, dynamic>>> getMyRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rooms = await _client
        .from('chat_rooms')
        .select('*, chat_members!inner(user_id, last_read_at)')
        .eq('chat_members.user_id', userId);

    final result = <Map<String, dynamic>>[];

    for (final room in rooms) {
      final roomId = room['id'] as String;
      final members = room['chat_members'] as List<dynamic>;
      final myMember = members.firstWhere(
        (m) => m['user_id'] == userId,
        orElse: () => {'last_read_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String()},
      );
      final lastReadAt = myMember['last_read_at'] as String?;

      final messages = await _client
          .from('chat_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1);

      final unreadCount = await _client
          .from('chat_messages')
          .select('id')
          .eq('room_id', roomId)
          .gt('created_at', lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String());

      result.add({
        'id': room['id'],
        'name': room['name'],
        'invite_code': room['invite_code'],
        'created_by': room['created_by'],
        'avatar_url': room['avatar_url'],
        'created_at': room['created_at'],
        'last_message': messages.isNotEmpty ? messages.first : null,
        'unread_count': (unreadCount as List).length,
      });
    }

    result.sort((a, b) {
      final aMsg = a['last_message'];
      final bMsg = b['last_message'];
      if (aMsg == null && bMsg == null) return 0;
      if (aMsg == null) return 1;
      if (bMsg == null) return -1;
      return (bMsg['created_at'] as String).compareTo(aMsg['created_at'] as String);
    });

    return result;
  }

  static Future<List<Map<String, dynamic>>> getMessages(String roomId) async {
    final messages = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(messages);
  }

  static Future<void> sendMessage(String roomId, String content, String username) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'user_id': userId,
      'username': username,
      'content': content,
    });
  }

  static Future<Map<String, dynamic>> createRoom(
      String name, String creatorId, String creatorUsername) async {
    final room = await _client
        .from('chat_rooms')
        .insert({'name': name, 'created_by': creatorId})
        .select()
        .single();

    await _client.from('chat_members').insert({
      'room_id': room['id'],
      'user_id': creatorId,
      'role': 'admin',
    });

    return room;
  }

  static Future<Map<String, dynamic>> joinRoomByCode(
      String code, String userId, String username) async {
    final rooms = await _client
        .from('chat_rooms')
        .select()
        .eq('invite_code', code.toUpperCase());

    if (rooms.isEmpty) throw Exception('Nie znaleziono grupy o podanym kodzie.');

    final room = rooms.first as Map<String, dynamic>;
    final roomId = room['id'] as String;

    final existing = await _client
        .from('chat_members')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId);

    if (existing.isEmpty) {
      await _client.from('chat_members').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'member',
      });
    }

    return room;
  }

  /// Czat meczu: pokój per mecz W OBRĘBIE kontekstu.
  /// leagueId == null → czat globalny (zakładka Mecze);
  /// leagueId != null → osobny czat prywatnej ligi, widoczny tylko dla osób,
  /// które wchodzą w mecz z poziomu tej ligi.
  /// Pokój powstaje przy pierwszym otwarciu; użytkownik jest automatycznie
  /// dołączany jako członek (żeby działały nieprzeczytane i lista czatów).
  static Future<Map<String, dynamic>> getOrCreateMatchRoom(
      String matchId, String roomName, String userId,
      {String? leagueId}) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> scoped() {
      var q = _client.from('chat_rooms').select().eq('match_id', matchId);
      return leagueId == null
          ? q.isFilter('league_id', null)
          : q.eq('league_id', leagueId);
    }

    var room = await scoped().maybeSingle();

    if (room == null) {
      try {
        room = await _client
            .from('chat_rooms')
            .insert({
              'name': roomName,
              'created_by': userId,
              'match_id': matchId,
              'league_id': leagueId,
            })
            .select()
            .single();
      } on PostgrestException {
        // Wyścig: ktoś utworzył pokój równolegle — unikalny indeks
        // (match_id, league_id) odrzucił nasz insert, czytamy istniejący.
        room = await scoped().single();
      }
    }

    final roomId = room['id'] as String;
    final existing = await _client
        .from('chat_members')
        .select('user_id')
        .eq('room_id', roomId)
        .eq('user_id', userId);
    if ((existing as List).isEmpty) {
      await _client.from('chat_members').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'member',
      });
    }

    return room;
  }

  static Future<void> addMemberByUsername(String roomId, String username) async {
    final profiles = await _client
        .from('profiles')
        .select()
        .eq('username', username);

    if (profiles.isEmpty) throw Exception('Nie znaleziono użytkownika o nazwie "$username".');

    final profile = profiles.first as Map<String, dynamic>;
    final targetUserId = profile['id'] as String;

    final existing = await _client
        .from('chat_members')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', targetUserId);

    if (existing.isNotEmpty) throw Exception('Użytkownik jest już członkiem tej grupy.');

    await _client.from('chat_members').insert({
      'room_id': roomId,
      'user_id': targetUserId,
      'role': 'member',
    });
  }

  static Future<int> getMemberCount(String roomId) async {
    final members = await _client
        .from('chat_members')
        .select('user_id')
        .eq('room_id', roomId);
    return (members as List).length;
  }

  static RealtimeChannel subscribeToMessages(
      String roomId, void Function(Map<String, dynamic>) callback) {
    return _client
        .channel('room-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            callback(payload.newRecord);
          },
        )
        .subscribe();
  }

  static Future<void> markRead(String roomId, String userId) async {
    await _client
        .from('chat_members')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }
}
