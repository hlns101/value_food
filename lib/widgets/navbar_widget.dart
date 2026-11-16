import 'dart:ui';
import 'package:flutter/material.dart';
import '../dashboard_page.dart';
import '../budget_page.dart';
import '../goals_page.dart';
import '../profile_page.dart';
import '../label_page.dart';
import '../utils/app_haptics.dart';
import '../utils/page_transitions.dart';

enum NavbarTab { home, budget, goals, profile, scan }

/// Place directly in a Stack. Shared floating navigation for the main pages.
class NavbarWidget extends StatelessWidget {
  final String userId;
  final NavbarTab activeTab;
  final VoidCallback? onScan;
  final bool scanEnabled;
  const NavbarWidget({
    super.key,
    required this.userId,
    required this.activeTab,
    this.onScan,
    this.scanEnabled = true,
  });
  static const _green = Color(0xFF287D35);
  static const _lightGreen = Color(0xFF7DB848);
  @override
  Widget build(BuildContext context) => Positioned(
    left: 15,
    right: 15,
    bottom: 12 + MediaQuery.of(context).padding.bottom,
    child: SizedBox(
      height: 96,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Main transparent glass capsule
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 68,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF287D35).withOpacity(0.10),
                    blurRadius: 22,
                    spreadRadius: -5,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(38),

                      // Translucent highlights retain the glass effect while
                      // softening the green cards underneath the navigation.
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.82),
                          const Color(0xFFDFF1E5).withValues(alpha: 0.52),
                          Colors.white.withValues(alpha: 0.58),
                        ],
                      ),

                      // Subtle reflective glass edge
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            _navItem(
                              Icons.home_rounded,
                              'home',
                              activeTab == NavbarTab.home,
                              () => _navigate(
                                context,
                                DashboardPage(userId: userId),
                              ),
                            ),

                            _navItem(
                              Icons.savings_rounded,
                              'budget',
                              activeTab == NavbarTab.budget,
                              () => _navigate(
                                context,
                                BudgetPage(userId: userId),
                              ),
                            ),

                            const Expanded(child: SizedBox()),

                            _navItem(
                              Icons.flag_rounded,
                              'goals',
                              activeTab == NavbarTab.goals,
                              () =>
                                  _navigate(context, GoalsPage(userId: userId)),
                            ),

                            _navItem(
                              Icons.person_rounded,
                              'profile',
                              activeTab == NavbarTab.profile,
                              () => _navigate(
                                context,
                                ProfilePage(userId: userId),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Floating Scan Label button
          Positioned(
            top: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  !scanEnabled
                      ? null
                      : onScan ??
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LabelPage(userId: userId),
                            ),
                          ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 61,
                    height: 61,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.85),
                          const Color(0xFFDEF3E6).withOpacity(0.55),
                        ],
                      ),
                      border: Border.all(color: _green, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF287D35).withOpacity(0.10),
                          blurRadius: 22,
                          spreadRadius: -5,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/scan_icon.png',
                        height: 29,
                        color: _green,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: _green,
                              size: 29,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'SCAN LABEL',
                    style: TextStyle(
                      fontSize: 8,
                      color: _green,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback action,
  ) => Expanded(
    child: InkWell(
      onTap: active ? null : action,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          gradient:
              active
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .9),
                      _lightGreen.withValues(alpha: .25),
                    ],
                  )
                  : null,
          boxShadow:
              active
                  ? [
                    BoxShadow(
                      color: _green.withValues(alpha: .12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                active
                    ? Colors.white.withValues(alpha: 0.65)
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? _green : const Color(0xFF416B3B),
              size: 23,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _green : const Color(0xFF416B3B),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _navigate(BuildContext context, Widget page) {
    AppHaptics.selection();
    Navigator.of(context).pushReplacement(SmoothPageRoute(page: page));
  }
}
