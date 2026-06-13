import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tournament_service.dart';

class SetupGroupPhaseScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final List<Map<String, dynamic>> teams;

  const SetupGroupPhaseScreen({
    super.key,
    required this.tournament,
    required this.teams,
  });

  @override
  State<SetupGroupPhaseScreen> createState() => _SetupGroupPhaseScreenState();
}

class _SetupGroupPhaseScreenState extends State<SetupGroupPhaseScreen> {
  int _groupCount = 2;
  late Map<String, List<String>> _groupAssignments;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initGroups();
  }

  void _initGroups() {
    _groupAssignments = {};
    for (var i = 0; i < _groupCount; i++) {
      _groupAssignments[String.fromCharCode(65 + i)] = [];
    }
    _autoDistribute();
  }

  void _autoDistribute() {
    final allTeams = widget.teams.map((t) => t['id'] as String).toList();
    final keys = _groupAssignments.keys.toList();
    for (var i = 0; i < allTeams.length; i++) {
      _groupAssignments[keys[i % keys.length]]!.add(allTeams[i]);
    }
  }

  List<String> get _unassigned {
    final assigned = _groupAssignments.values.expand((l) => l).toSet();
    return widget.teams
        .map((t) => t['id'] as String)
        .where((id) => !assigned.contains(id))
        .toList();
  }

  Map<String, dynamic>? _teamById(String id) {
    try {
      return widget.teams.firstWhere((t) => t['id'] == id);
    } catch (_) {
      return null;
    }
  }

  void _moveTeam(String teamId, String? fromGroup, String toGroup) {
    setState(() {
      if (fromGroup != null) {
        _groupAssignments[fromGroup]!.remove(teamId);
      }
      _groupAssignments[toGroup]!.add(teamId);
    });
  }

  void _removeFromGroup(String teamId, String group) {
    setState(() {
      _groupAssignments[group]!.remove(teamId);
    });
  }

  bool get _isValid {
    for (final entry in _groupAssignments.entries) {
      if (entry.value.length < 2) return false;
    }
    return _unassigned.isEmpty;
  }

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _saving = true);
    try {
      await TournamentService.setupGroupPhase(
        tournamentId: widget.tournament['id'] as String,
        groupTeams: _groupAssignments,
        allTeams: widget.teams,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: $e'), backgroundColor: AppTheme.errorColor),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Faza grupowa', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _isValid ? _save : null,
              child: Text(
                'GENERUJ',
                style: TextStyle(
                  color: _isValid ? AppTheme.primaryColor : AppTheme.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Liczba grup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: [
                const Text('Liczba grup:', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const Spacer(),
                _countButton('-', _groupCount > 2, () => setState(() { _groupCount--; _initGroups(); })),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_groupCount', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 22)),
                ),
                _countButton('+', _groupCount < 8 && widget.teams.length > _groupCount * 2, () => setState(() { _groupCount++; _initGroups(); })),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Dotknij drużynę w grupie żeby przenieść ją do innej. Każda grupa musi mieć min. 2 drużyny.',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Grupy
          ..._groupAssignments.entries.map((entry) => _buildGroupCard(entry.key, entry.value)),

          // Nieprzypisane drużyny
          if (_unassigned.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildUnassignedCard(),
          ],

          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(String groupName, List<String> teamIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: teamIds.length < 2 ? AppTheme.errorColor.withOpacity(0.5) : AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('$groupName', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Grupa $groupName', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${teamIds.length} drużyny', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          if (teamIds.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Brak drużyn', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            )
          else
            ...teamIds.map((tid) {
              final team = _teamById(tid);
              if (team == null) return const SizedBox.shrink();
              return _buildTeamTile(
                team: team,
                onTap: () => _showMoveDialog(tid, groupName),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary, size: 18),
                  onPressed: () => _removeFromGroup(tid, groupName),
                ),
              );
            }),
          // Drop zone: dodaj z nieprzypisanych
          if (_unassigned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: OutlinedButton.icon(
                onPressed: () => _showAddToGroupDialog(groupName),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dodaj drużynę', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnassignedCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('Nieprzypisane drużyny', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ..._unassigned.map((tid) {
            final team = _teamById(tid);
            if (team == null) return const SizedBox.shrink();
            return _buildTeamTile(
              team: team,
              onTap: () => _showAddToGroupDialog(null, preselectedTeam: tid),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTeamTile({
    required Map<String, dynamic> team,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.surfaceColor,
        child: Text(
          (team['name'] as String).substring(0, 1).toUpperCase(),
          style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      title: Text(team['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      trailing: trailing,
    );
  }

  void _showMoveDialog(String teamId, String currentGroup) {
    final team = _teamById(teamId);
    if (team == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Przenieś: ${team['name']}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            ..._groupAssignments.keys.where((g) => g != currentGroup).map((g) =>
              ListTile(
                title: Text('Grupa $g', style: const TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  _moveTeam(teamId, currentGroup, g);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToGroupDialog(String? targetGroup, {String? preselectedTeam}) {
    if (preselectedTeam != null && targetGroup == null) {
      // wybierz grupę
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dodaj do grupy', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              ..._groupAssignments.keys.map((g) =>
                ListTile(
                  title: Text('Grupa $g', style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    _moveTeam(preselectedTeam, null, g);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (targetGroup != null) {
      final unassigned = _unassigned;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dodaj do Grupy $targetGroup', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              ...unassigned.map((tid) {
                final t = _teamById(tid);
                if (t == null) return const SizedBox.shrink();
                return ListTile(
                  title: Text(t['name'] as String, style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    _moveTeam(tid, null, targetGroup);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      );
    }
  }

  Widget _countButton(String label, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? AppTheme.primaryColor.withOpacity(0.5) : AppTheme.dividerColor),
        ),
        child: Center(
          child: Text(label, style: TextStyle(
            color: enabled ? AppTheme.primaryColor : AppTheme.textTertiary,
            fontWeight: FontWeight.w800, fontSize: 20,
          )),
        ),
      ),
    );
  }
}
