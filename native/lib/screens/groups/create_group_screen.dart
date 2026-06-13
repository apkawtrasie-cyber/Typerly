import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../services/league_service.dart';
import '../../widgets/widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _entryFeeController = TextEditingController(text: '0');
  bool _isPremiumLeague = false;

  @override
  void dispose() {
    _nameController.dispose();
    _entryFeeController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _handleCreateGroup() async {
    if (!_formKey.currentState!.validate()) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    // Premium league toggle only for premium users
    if (_isPremiumLeague && !authState.profile.isPremiumActive) {
      _showPremiumUpgradeDialog();
      return;
    }

    // Check league limit for free users (max 1)
    if (!authState.profile.isPremiumActive) {
      try {
        final count = await LeagueService.getUserLeagueCount(authState.profile.id);
        if (count >= 1) {
          _showLeagueLimitDialog();
          return;
        }
      } catch (_) {}
    }

    setState(() => _isSaving = true);
    try {
      final inviteCode = _generateInviteCode();
      await LeagueService.createLeague(
        name: _nameController.text.trim(),
        adminId: authState.profile.id,
        entryFeeGemings: int.tryParse(_entryFeeController.text) ?? 0,
        inviteCode: inviteCode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liga utworzona! Kod zaproszenia: $inviteCode'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _generateInviteCode() {
    const uuid = Uuid();
    return uuid.v4().substring(0, 8).toUpperCase();
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'Premium Feature',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Custom leagues with entry fees are available for Premium users only. Upgrade to unlock this feature.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to premium upgrade
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showLeagueLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'League Limit Reached',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Free users can create only 1 private league. Upgrade to Premium to create unlimited leagues.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to premium upgrade
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Create League'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // League name
                    CustomTextField(
                      label: 'League Name',
                      hint: 'Enter league name',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a league name';
                        }
                        if (value.length < 3) {
                          return 'League name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Entry fee
                    CustomTextField(
                      label: 'Entry Fee (Gemingi)',
                      hint: '0',
                      controller: _entryFeeController,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.diamond_outlined),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter entry fee';
                        }
                        final fee = int.tryParse(value);
                        if (fee == null || fee < 0) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Premium league toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Premium League',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enable custom matches and advanced features',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isPremiumLeague,
                            onChanged: (value) {
                              setState(() {
                                _isPremiumLeague = value;
                              });
                            },
                            activeColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Info card
                    if (!state.profile.isPremiumActive)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.textTertiary),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Free users can create 1 league. Premium users can create unlimited leagues.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Create button
                    PrimaryButton(
                      text: 'Utwórz ligę',
                      onPressed: _isSaving ? null : _handleCreateGroup,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
