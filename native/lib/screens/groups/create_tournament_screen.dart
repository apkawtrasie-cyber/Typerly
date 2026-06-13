import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../services/tournament_service.dart';
import 'package:uuid/uuid.dart';

class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final _prizeController = TextEditingController();
  bool _isSaving = false;

  String _generateCode() {
    final uuid = const Uuid().v4().replaceAll('-', '').toUpperCase();
    return uuid.substring(0, 8);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _isSaving = true);
    try {
      final code = _generateCode();
      final t = await TournamentService.createTournament(
        name: name,
        adminId: authState.profile.id,
        inviteCode: code,
        prizeDescription: _prizeController.text.trim().isEmpty
            ? null
            : _prizeController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, t);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorColor),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Nowy turniej', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('NAZWA TURNIEJU', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('np. Turniej Osiedlowy 2026'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          const Text('NAGRODA (opcjonalnie)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: _prizeController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: _inputDecoration('np. Obiad w restauracji dla zwycięzcy'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nagroda widoczna tylko dla zaproszonych członków',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Utwórz turniej', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textTertiary),
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
    );
  }
}
