import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../models/match.dart';
import '../../widgets/widgets.dart';

class CustomGroupScreen extends StatefulWidget {
  const CustomGroupScreen({super.key});

  @override
  State<CustomGroupScreen> createState() => _CustomGroupScreenState();
}

class _CustomGroupScreenState extends State<CustomGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _homeTeamController = TextEditingController();
  final _awayTeamController = TextEditingController();
  final _matchTimeController = TextEditingController();
  DateTime? _selectedDateTime;

  // Mock custom matches
  final List<Match> _customMatches = [];

  @override
  void dispose() {
    _homeTeamController.dispose();
    _awayTeamController.dispose();
    _matchTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _matchTimeController.text =
              '${picked.day}/${picked.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
        });
      }
    }
  }

  void _handleAddCustomMatch() {
    if (_formKey.currentState!.validate()) {
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) {
        if (!state.profile.isPremiumActive) {
          _showPremiumRequiredDialog();
          return;
        }

        // Add custom match
        setState(() {
          _customMatches.add(
            Match(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sportType: 'custom',
              homeTeamName: _homeTeamController.text.trim(),
              awayTeamName: _awayTeamController.text.trim(),
              matchTime: _selectedDateTime ?? DateTime.now().add(const Duration(days: 1)),
              status: 'NS',
              isCustom: true,
              creatorId: state.profile.id,
              createdAt: DateTime.now(),
            ),
          );
          _homeTeamController.clear();
          _awayTeamController.clear();
          _matchTimeController.clear();
          _selectedDateTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Custom match added successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text(
          'Premium Feature',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Custom matches are available for Premium users only. Upgrade to create your own matches.',
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
        title: const Text('Custom Matches'),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated && !state.profile.isPremiumActive) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: AppTheme.backgroundColor),
                      const SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: const TextStyle(
                          color: AppTheme.backgroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Add custom match form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add Custom Match',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Home Team',
                          hint: 'Team name',
                          controller: _homeTeamController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Away Team',
                          hint: 'Team name',
                          controller: _awayTeamController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Match Time',
                    hint: 'Select date and time',
                    controller: _matchTimeController,
                    onTap: _selectDateTime,
                    prefixIcon: const Icon(Icons.calendar_today),
                    validator: (value) {
                      if (_selectedDateTime == null) {
                        return 'Please select match time';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Add Match',
                    onPressed: _handleAddCustomMatch,
                    isFullWidth: false,
                  ),
                ],
              ),
            ),
          ),
          // Custom matches list
          Expanded(
            child: _customMatches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 64,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No custom matches yet',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first custom match above',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _customMatches.length,
                    itemBuilder: (context, index) {
                      return MatchCard(
                        match: _customMatches[index],
                        onTap: () {
                          // TODO: Navigate to match detail
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
