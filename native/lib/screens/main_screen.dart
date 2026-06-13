import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/auth.dart';
import '../widgets/widgets.dart';
import 'home/home_screen.dart';
import 'matches/matches_screen.dart';
import 'groups/groups_screen.dart';
import 'profile/profile_screen.dart';
import 'chat/chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFFFC83D);
  static const Color _dim = Color(0xFF707070);

  // Zakładki: 0 Home, 1 Mecze, 2 Ligi, 3 Czat, 4 Profil
  late final List<Widget> _screens = [
    HomeScreen(
      onNavigateToTab: (index) => setState(() => _currentIndex = index),
    ),
    const MatchesScreen(),
    const GroupsScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        // FAB na zakładkach 1-2 (Mecze, Ligi), ukryty na Home, Czat, Profil
        floatingActionButton: (_currentIndex == 1 || _currentIndex == 2)
            ? TyperlyFab(
                onChatTap: () => setState(() => _currentIndex = 3),
              )
            : null,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: _bg,
            border: Border(
              top: BorderSide(color: Color(0xFF1E1E1E)),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: _gold,
            unselectedItemColor: _dim,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_soccer_outlined),
                activeIcon: Icon(Icons.sports_soccer),
                label: 'Mecze',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined),
                activeIcon: Icon(Icons.emoji_events),
                label: 'Ligi',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Czat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
