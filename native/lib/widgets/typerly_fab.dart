import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';

/// Globalny FAB Typerly z menu podakcji (Ranking / Udostępnij / Czat).
/// Używany na wszystkich zakładkach (MainScreen) i w szczegółach meczu.
class TyperlyFab extends StatelessWidget {
  /// Tekst wysyłany przez systemowe udostępnianie.
  final String shareText;

  /// Etykieta pozycji udostępniania (np. "Udostępnij mecz").
  final String shareLabel;

  /// Akcja po wybraniu "Czat". Gdy null — pozycja oznaczona "Wkrótce".
  final VoidCallback? onChatTap;

  const TyperlyFab({
    super.key,
    this.shareText = 'Typuj wyniki meczów i rywalizuj ze znajomymi w Typerly!',
    this.shareLabel = 'Udostępnij Typerly',
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.sports_soccer, color: Colors.black, size: 30),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Stwórz ligę',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/create-group');
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Stwórz turniej',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/create-tournament');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.emoji_events, color: AppTheme.primaryColor),
              title: const Text('Ranking',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/leaderboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.primaryColor),
              title: Text(shareLabel,
                  style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(shareText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor),
              title: const Text('Czat',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: onChatTap == null
                  ? const Text('Wkrótce',
                      style:
                          TextStyle(color: AppTheme.textTertiary, fontSize: 11))
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onChatTap?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
