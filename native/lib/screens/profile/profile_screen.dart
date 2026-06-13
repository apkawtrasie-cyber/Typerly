import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth.dart';
import '../../models/profile.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loadingStats = true;

  // Odznaki
  List<Map<String, dynamic>> _badges = [];

  // Statystyki z bazy (predictions / profiles)
  int _totalPoints = 0;
  int _weekPoints = 0;
  int _totalPredictions = 0;
  int _calculatedPredictions = 0;
  int _exactHits = 0; // 3 pkt — dokładny wynik
  int _accuracyPct = 0; // % typów z min. 1 pkt
  int _streak = 0; // trafione typy z rzędu
  int? _rankPosition;
  int _totalPlayers = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      setState(() => _loadingStats = false);
      return;
    }
    final userId = state.profile.id;

    try {
      final db = Supabase.instance.client;
      final now = DateTime.now().toUtc();
      final weekStart = now
          .subtract(Duration(days: now.weekday - 1))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

      final results = await Future.wait([
        // Moje typy (z datą — do serii i punktów tygodnia)
        db.from('predictions')
            .select('points_earned, is_calculated, updated_at')
            .eq('user_id', userId)
            .order('updated_at', ascending: false),
        // Punkty wszystkich graczy — do pozycji w rankingu
        db.from('predictions')
            .select('user_id, points_earned')
            .eq('is_calculated', true),
        // Liczba wszystkich graczy
        db.from('profiles').select('id'),
        // Moje odznaki z definicjami
        db.from('user_badges')
            .select('badge_id, awarded_at, badge_definitions(name, icon, rarity)')
            .eq('user_id', userId)
            .order('awarded_at', ascending: false),
      ]);

      final mine = (results[0] as List).cast<Map<String, dynamic>>();
      final allPreds = (results[1] as List).cast<Map<String, dynamic>>();
      final allProfiles = (results[2] as List);
      final badgesRaw = (results[3] as List).cast<Map<String, dynamic>>();

      var points = 0, weekPts = 0, calculated = 0, exact = 0, hits = 0;
      var streak = 0;
      var streakBroken = false;
      for (final p in mine) {
        if (p['is_calculated'] != true) continue;
        calculated++;
        final pts = (p['points_earned'] as int?) ?? 0;
        points += pts;
        if (pts == 3) exact++;
        if (pts > 0) hits++;
        final updated = DateTime.tryParse(p['updated_at'] as String? ?? '');
        if (updated != null && updated.isAfter(weekStart)) weekPts += pts;
        // Seria: kolejne trafione typy od najnowszego
        if (!streakBroken) {
          if (pts > 0) {
            streak++;
          } else {
            streakBroken = true;
          }
        }
      }

      // Pozycja w globalnym rankingu (suma punktów per gracz)
      final pointsByUser = <String, int>{};
      for (final p in allPreds) {
        final uid = p['user_id'] as String;
        pointsByUser[uid] =
            (pointsByUser[uid] ?? 0) + ((p['points_earned'] as int?) ?? 0);
      }
      final sorted = pointsByUser.values.toList()..sort((a, b) => b.compareTo(a));
      final myTotal = pointsByUser[userId] ?? 0;
      final position = pointsByUser.containsKey(userId)
          ? sorted.indexOf(myTotal) + 1
          : null;

      if (!mounted) return;
      setState(() {
        _totalPoints = points;
        _weekPoints = weekPts;
        _totalPredictions = mine.length;
        _calculatedPredictions = calculated;
        _exactHits = exact;
        _accuracyPct =
            calculated > 0 ? ((hits / calculated) * 100).round() : 0;
        _streak = streak;
        _rankPosition = position;
        _totalPlayers = allProfiles.length;
        _badges = badgesRaw;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            final profile = state.profile;
            return RefreshIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardColor,
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Profil',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    _buildProfileHeader(profile),
                    const SizedBox(height: 24),
                    _buildGlobalStatistics(),
                    const SizedBox(height: 20),
                    _buildBadgesSection(),
                    const SizedBox(height: 20),
                    _buildPremiumCard(profile),
                    const SizedBox(height: 20),
                    _buildAccountSettings(context),
                    const SizedBox(height: 20),
                    SecondaryButton(
                      text: 'Wyloguj się',
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthSignOutRequested());
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      icon: const Icon(Icons.logout, size: 18),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.primaryColor));
        },
      ),
    );
  }

  Widget _buildProfileHeader(Profile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: profile.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: profile.avatarUrl!, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      profile.username[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.username,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    profile.isPremiumActive ? 'PREMIUM' : 'GRACZ',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('$_totalPoints',
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const Text('pkt',
                  style: TextStyle(
                      color: AppTheme.textTertiary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatistics() {
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
              const Icon(Icons.bar_chart,
                  color: AppTheme.primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'STATYSTYKI GLOBALNE',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_loadingStats)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile(
                  Icons.emoji_events,
                  AppTheme.primaryColor,
                  'Ranking',
                  _rankPosition != null ? '#$_rankPosition' : '—',
                  _totalPlayers > 0 ? 'na $_totalPlayers graczy' : 'brak danych'),
              const SizedBox(width: 10),
              _statTile(Icons.star, Colors.amber, 'Punkty', '$_totalPoints pkt',
                  '+$_weekPoints w tym tygodniu'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(Icons.check_circle, AppTheme.successColor,
                  'Trafione wyniki', '$_exactHits', 'dokładne wyniki'),
              const SizedBox(width: 10),
              _statTile(Icons.analytics, Colors.blueAccent, 'Celność',
                  '$_accuracyPct%', 'z $_calculatedPredictions obliczonych'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(Icons.sports_soccer, AppTheme.primaryColor,
                  'Wszystkie typy', '$_totalPredictions', 'łącznie'),
              const SizedBox(width: 10),
              _statTile(Icons.local_fire_department, Colors.orange, 'Seria',
                  '$_streak', 'trafionych z rzędu'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(
      IconData icon, Color color, String label, String value, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    // Zlicz puchary (rare/epic/legendary) i gwiazdy (common)
    final trophies = _badges.where((b) {
      final def = b['badge_definitions'] as Map<String, dynamic>?;
      final r = def?['rarity'] as String? ?? 'common';
      return r == 'rare' || r == 'epic' || r == 'legendary';
    }).toList();
    final stars = _badges.where((b) {
      final def = b['badge_definitions'] as Map<String, dynamic>?;
      final r = def?['rarity'] as String? ?? 'common';
      return r == 'common';
    }).toList();

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
          // Nagłówek z licznikami
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFF5C400), size: 18),
              const SizedBox(width: 8),
              const Text('MOJE NAGRODY',
                  style: TextStyle(
                    color: Color(0xFFF5C400),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  )),
              const Spacer(),
              // Licznik pucharów
              _rewardCounter('🏆', trophies.length, const Color(0xFFF5C400)),
              const SizedBox(width: 10),
              // Licznik gwiazdek
              _rewardCounter('⭐', stars.length, const Color(0xFF88CCFF)),
            ],
          ),

          const SizedBox(height: 16),

          if (_loadingStats)
            const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFF5C400), strokeWidth: 2),
            )
          else if (_badges.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text('🎯', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  const Text('Zacznij typować — zdobywaj nagrody!',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _badges.map((b) {
                final def = b['badge_definitions'] as Map<String, dynamic>?;
                final name   = def?['name'] as String? ?? '?';
                final icon   = def?['icon'] as String? ?? '🎖️';
                final rarity = def?['rarity'] as String? ?? 'common';
                return _badgePill(icon, name, rarity);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _rewardCounter(String emoji, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _badgePill(String icon, String name, String rarity) {
    Color color;
    switch (rarity) {
      case 'legendary': color = const Color(0xFFFF9500); break;
      case 'epic':      color = const Color(0xFFAA44FF); break;
      case 'rare':      color = const Color(0xFFF5C400); break;
      default:          color = const Color(0xFF88CCFF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(name,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(Profile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plan: ${profile.isPremiumActive ? 'Premium' : 'Darmowy'}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (profile.isPremiumActive && profile.premiumUntil != null)
                Text(
                  'Ważny do ${profile.premiumUntil!.day}.${profile.premiumUntil!.month}.${profile.premiumUntil!.year}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: profile.isPremiumActive
                ? 'Zarządzaj planem'
                : 'Przejdź na Premium',
            onPressed: () {
              // TODO: Navigate to premium upgrade
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
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
          const Text(
            'USTAWIENIA KONTA',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            icon: Icons.email_outlined,
            title: 'Zmień Email',
            onTap: () => _showChangeEmailDialog(context),
          ),
          const Divider(height: 28, color: AppTheme.dividerColor),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Zmień Hasło',
            onTap: () => _showChangePasswordDialog(context),
          ),
          const Divider(height: 28, color: AppTheme.dividerColor),
          _buildSettingItem(
            icon: Icons.security_outlined,
            title: 'Bezpieczeństwo konta',
            onTap: () => _showInfoDialog(context, 'Bezpieczeństwo',
                'Twoje konto jest chronione przez Supabase Auth.\nWeryfikacja dwuetapowa (2FA) wkrótce dostępna.'),
          ),
          const Divider(height: 28, color: AppTheme.dividerColor),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: 'Pomoc / Support',
            onTap: () => _showInfoDialog(context, 'Pomoc',
                'W razie problemów napisz na:\nsupport@typerly.app\n\nLub odwiedź: typerly.app/help'),
          ),
        ],
      ),
    );
  }

  void _showChangeEmailDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Zmień Email',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Nowy adres email',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.dividerColor)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(email: email),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Link weryfikacyjny wysłany na nowy email')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd: $e')),
                  );
                }
              }
            },
            child: const Text('Zapisz',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Zmień Hasło',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Nowe hasło',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Powtórz hasło',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.dividerColor)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final pass = controller.text;
              if (pass != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hasła nie są takie same')),
                );
                return;
              }
              if (pass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Hasło musi mieć min. 6 znaków')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: pass),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hasło zostało zmienione')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd: $e')),
                  );
                }
              }
            },
            child: const Text('Zmień',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content:
            Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
