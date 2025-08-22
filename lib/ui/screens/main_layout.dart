import 'package:flutter/material.dart';
import 'package:hybrid_storage_app/ui/screens/dashboard/dashboard_screen.dart';
import 'package:hybrid_storage_app/ui/screens/file_explorer/file_explorer_screen.dart';
import 'package:hybrid_storage_app/ui/screens/transfers/transfers_screen.dart';
import 'package:hybrid_storage_app/ui/screens/settings/settings_screen.dart';

// Ce widget est la structure principale de l'application après l'authentification.
// Il contient la barre de navigation inférieure et gère l'affichage des écrans principaux.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Contrôleur pour gérer la page affichée.
  final PageController _pageController = PageController();
  // Index de la page actuellement sélectionnée.
  int _selectedIndex = 0;

  // Liste des écrans principaux de l'application.
  final List<Widget> _screens = [
    const DashboardScreen(),
    const FileExplorerScreen(),
    const TransfersScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Fonction appelée lorsque l'utilisateur tape sur un élément de la barre de navigation.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Change de page avec une animation fluide.
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        // Empêche le défilement par geste (swipe) entre les pages.
        // La navigation se fait uniquement via la barre inférieure.
        physics: const NeverScrollableScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Explorateur',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transferts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
