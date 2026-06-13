import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_room_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _processing = true);
    await _ctrl.stop();

    final code = raw.trim().toUpperCase();
    await _joinByCode(code);
  }

  Future<void> _joinByCode(String code) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _error('Musisz być zalogowany');
      return;
    }

    try {
      // Szukaj turnieju
      final res = await supabase
          .from('custom_tournaments')
          .select('id, name')
          .eq('invite_code', code)
          .maybeSingle();

      if (res != null) {
        final tId = res['id'] as String;
        final tName = res['name'] as String;

        // Sprawdź czy już jest członkiem
        final existing = await supabase
            .from('tournament_members')
            .select('id')
            .eq('tournament_id', tId)
            .eq('user_id', userId)
            .maybeSingle();

        if (existing == null) {
          await supabase.from('tournament_members').insert({
            'tournament_id': tId,
            'user_id': userId,
            'role': 'member',
          });
        }

        if (!mounted) return;
        Navigator.of(context).pop(); // zamknij skaner
        Navigator.of(context).pushNamed('/tournament-detail', arguments: res);
        return;
      }

      // Sprawdź czy to kod grupy czatu
      final chatRes = await supabase
          .from('chat_rooms')
          .select('id, name, invite_code')
          .eq('invite_code', code)
          .maybeSingle();

      if (chatRes != null) {
        final rId = chatRes['id'] as String;
        final rName = chatRes['name'] as String;
        final rCode = chatRes['invite_code'] as String;

        // Dołącz jeśli nie jest już członkiem
        final existingMember = await supabase
            .from('chat_members')
            .select('user_id')
            .eq('room_id', rId)
            .eq('user_id', userId)
            .maybeSingle();

        if (existingMember == null) {
          await supabase.from('chat_members').insert({
            'room_id': rId,
            'user_id': userId,
          });
        }

        if (!mounted) return;
        Navigator.of(context).pop(); // zamknij skaner
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: rId,
            roomName: rName,
            inviteCode: rCode,
          ),
        ));
        return;
      }

      // Nie znaleziono ani turnieju, ani czatu
      _error('Nie znaleziono turnieju ani grupy z kodem: $code');
    } catch (e) {
      _error('Błąd: $e');
    }
  }

  void _error(String msg) {
    if (!mounted) return;
    setState(() => _processing = false);
    _ctrl.start();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.errorColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Skanuj kod QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // Ramka nakładki
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Opis
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Column(
              children: [
                if (_processing)
                  const CircularProgressIndicator(color: AppTheme.primaryColor)
                else
                  const Text(
                    'Nakieruj aparat na kod QR turnieju',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                // Ręczne wpisanie kodu
                if (!_processing)
                  TextButton(
                    onPressed: _enterManually,
                    child: const Text(
                      'Wpisz kod ręcznie',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _enterManually() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Wpisz kod zaproszenia',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 12,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            hintText: 'np. AB12CD34',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Anuluj',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final code = ctrl.text.trim().toUpperCase();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                setState(() => _processing = true);
                _ctrl.stop();
                _joinByCode(code);
              }
            },
            child: const Text('Dołącz',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
