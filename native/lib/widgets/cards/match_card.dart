import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../models/match.dart';

class MatchCard extends StatelessWidget {
  static const Map<String, String> _flagUrls = {
    'Polska': 'https://flagcdn.com/w80/pl.png',
    'Poland': 'https://flagcdn.com/w80/pl.png',
    'Holandia': 'https://flagcdn.com/w80/nl.png',
    'Netherlands': 'https://flagcdn.com/w80/nl.png',
    'Francja': 'https://flagcdn.com/w80/fr.png',
    'France': 'https://flagcdn.com/w80/fr.png',
    'Niemcy': 'https://flagcdn.com/w80/de.png',
    'Germany': 'https://flagcdn.com/w80/de.png',
    'Hiszpania': 'https://flagcdn.com/w80/es.png',
    'Spain': 'https://flagcdn.com/w80/es.png',
    'Anglia': 'https://flagcdn.com/w80/gb-eng.png',
    'England': 'https://flagcdn.com/w80/gb-eng.png',
    'Włochy': 'https://flagcdn.com/w80/it.png',
    'Italy': 'https://flagcdn.com/w80/it.png',
    'Belgia': 'https://flagcdn.com/w80/be.png',
    'Belgium': 'https://flagcdn.com/w80/be.png',
    'Portugalia': 'https://flagcdn.com/w80/pt.png',
    'Portugal': 'https://flagcdn.com/w80/pt.png',
    'Austria': 'https://flagcdn.com/w80/at.png',
    'Chorwacja': 'https://flagcdn.com/w80/hr.png',
    'Croatia': 'https://flagcdn.com/w80/hr.png',
    'Albania': 'https://flagcdn.com/w80/al.png',
    'Serbia': 'https://flagcdn.com/w80/rs.png',
    'Słowacja': 'https://flagcdn.com/w80/sk.png',
    'Slovakia': 'https://flagcdn.com/w80/sk.png',
    'Rumunia': 'https://flagcdn.com/w80/ro.png',
    'Romania': 'https://flagcdn.com/w80/ro.png',
    'Ukraina': 'https://flagcdn.com/w80/ua.png',
    'Ukraine': 'https://flagcdn.com/w80/ua.png',
    'Czechy': 'https://flagcdn.com/w80/cz.png',
    'Czech Republic': 'https://flagcdn.com/w80/cz.png',
    'Turcja': 'https://flagcdn.com/w80/tr.png',
    'Turkey': 'https://flagcdn.com/w80/tr.png',
    'Gruzja': 'https://flagcdn.com/w80/ge.png',
    'Georgia': 'https://flagcdn.com/w80/ge.png',
    'Dania': 'https://flagcdn.com/w80/dk.png',
    'Denmark': 'https://flagcdn.com/w80/dk.png',
    'Słowenia': 'https://flagcdn.com/w80/si.png',
    'Slovenia': 'https://flagcdn.com/w80/si.png',
    'Szkocja': 'https://flagcdn.com/w80/gb-sct.png',
    'Scotland': 'https://flagcdn.com/w80/gb-sct.png',
    'Argentyna': 'https://flagcdn.com/w80/ar.png',
    'Argentina': 'https://flagcdn.com/w80/ar.png',
  };

  static String? _getFlagUrl(String teamName) {
    return _flagUrls[teamName];
  }
  final Match match;
  final VoidCallback? onTap;
  final String? userPrediction;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.userPrediction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: match.isLive ? AppTheme.liveColor : AppTheme.dividerColor,
            width: match.isLive ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header with status and time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (match.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.liveColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Text(
                      _formatDate(match.matchTime),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                  ),
                  if (match.isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textTertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Teams
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Home team
                  Expanded(
                    child: Column(
                      children: [
                        CachedNetworkImage(
                          imageUrl: match.homeTeamLogoUrl ?? _getFlagUrl(match.homeTeamName) ?? '',
                          height: 48,
                          width: 48,
                          placeholder: (context, url) => const SizedBox(
                            height: 48,
                            width: 48,
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.sports_soccer,
                            size: 48,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.homeTeamName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Score or VS
                  Column(
                    children: [
                      if (match.homeScore != null && match.awayScore != null)
                        Text(
                          '${match.homeScore} : ${match.awayScore}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        const Text(
                          'VS',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (userPrediction != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Your tip: $userPrediction',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Away team
                  Expanded(
                    child: Column(
                      children: [
                        CachedNetworkImage(
                          imageUrl: match.awayTeamLogoUrl ?? _getFlagUrl(match.awayTeamName) ?? '',
                          height: 48,
                          width: 48,
                          placeholder: (context, url) => const SizedBox(
                            height: 48,
                            width: 48,
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.sports_soccer,
                            size: 48,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.awayTeamName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow, ${_formatTime(date)}';
    } else if (difference.inDays == -1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
