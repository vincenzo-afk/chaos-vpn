import 'package:flutter/material.dart';

/// Onboarding screen shown on first launch to explain platform limitations,
/// routing modes, and permission requirements.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  'SKIP >',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: _pages.map((page) => _buildPage(page)).toList(),
              ),
            ),

            // ── Dots + Next / Start ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? const Color(0xFFFF4500)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _currentPage < _pages.length - 1
                          ? _nextPage
                          : _skip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4500),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'NEXT'
                            : 'GET STARTED',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: page.color.withOpacity(0.2)),
            ),
            child: Icon(page.icon, color: page.color, size: 32),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.6),
              fontSize: 13,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Bullet points
          ...page.points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '> ',
                    style: TextStyle(
                      color: page.color,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.8),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> points;

  const OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.points,
  });
}

final _pages = [
  const OnboardingPage(
    icon: Icons.mic,
    color: Color(0xFFFF4500),
    title: 'HOW IT WORKS',
    subtitle:
        'ChaosVoice intercepts your microphone and applies a brutal 10-layer DSP chain in real time.',
    points: [
      'Gain → Bandpass → Bit Crush → Soft Clip → Hard Clip',
      '→ Echo → Reverb → Crackle → Dropout → Pitch Wobble',
      'Processed audio is routed to VoIP/communication apps',
      'Toggle ON/OFF from the notification or home screen',
    ],
  ),
  const OnboardingPage(
    icon: Icons.phonelink_rounded,
    color: Color(0xFFFF4500),
    title: 'COVERAGE & LIMITS',
    subtitle:
        'ChaosVoice works best with apps that use VoIP audio routing.',
    points: [
      '✅ Works with: WhatsApp, Telegram, Zoom, Google Meet',
      '⚠️ Discord: enable "Use Legacy Audio Subsystem"',
      '❌ Phone calls (GSM/VoLTE) — not interceptable',
      '❌ Games using AudioSource.MIC directly',
      '❌ System-wide injection requires root',
    ],
  ),
  const OnboardingPage(
    icon: Icons.battery_std,
    color: Color(0xFF00FF41),
    title: 'BATTERY OPTIMIZATION',
    subtitle:
        'Android OEMs aggressively kill background services. You must disable battery optimization.',
    points: [
      'Samsung (One UI): Settings > Battery > Unrestricted',
      'Xiaomi (MIUI): Settings > Battery > No restrictions',
      'OPPO/OnePlus: Settings > Battery > Allow background',
      'Huawei: Settings > Apps > Launch > Manage manually',
      'Tap "Disable Battery Optimization" in Settings',
      'See: dontkillmyapp.com for your device',
    ],
  ),
  const OnboardingPage(
    icon: Icons.security,
    color: Color(0xFFFF0033),
    title: 'ROOT MODE (ADVANCED)',
    subtitle:
        'Root access enables system-wide mic injection via HAL-level routing. Requires a Magisk module.',
    points: [
      'With root: ALL apps receive processed audio',
      'Phone calls, games, and all audio sources work',
      'Root voids warranty and can cause instability',
      'Root mode is clearly labeled — never auto-activated',
      'See README Phase 5 for Magisk module details',
      'Without root: limited to VoIP apps (see previous)',
    ],
  ),
];
