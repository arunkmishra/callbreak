import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/theme.dart';
import '../../data/repositories/socket_repository.dart';

// ─── Tab definitions ───────────────────────────────────────────────────────────
enum _SettingsTab { gameplay, audio, visual, notifications, about }

class _TabInfo {
  final _SettingsTab tab;
  final IconData icon;
  final String label;
  const _TabInfo({required this.tab, required this.icon, required this.label});
}

const _tabs = [
  _TabInfo(tab: _SettingsTab.audio, icon: Icons.volume_up_outlined, label: 'Audio'),
  _TabInfo(tab: _SettingsTab.visual, icon: Icons.palette_outlined, label: 'Visual'),
  _TabInfo(tab: _SettingsTab.about, icon: Icons.info_outline, label: 'About'),
];

// ─── Main Dialog Widget ────────────────────────────────────────────────────────
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsTab _activeTab = _SettingsTab.audio;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1523),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 40, spreadRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(),
                    _buildDivider(),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.settings, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SETTINGS',
                style: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              Text(
                'Customize your game experience',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 170,
      color: const Color(0xFF0A1020),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._tabs.map((info) => _SidebarTab(
                        info: info,
                        isActive: _activeTab == info.tab,
                        onTap: () => setState(() => _activeTab = info.tab),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildRestoreDefaults(),
        ],
      ),
    );
  }

  Widget _buildRestoreDefaults() {
    return GestureDetector(
      onTap: () {
        context.read<SettingsCubit>().restoreDefaults();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.restore, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 8),
            Text(
              'Restore Defaults',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, color: Colors.white.withValues(alpha: 0.06));
  }

  // ── Content Router ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _pageFor(_activeTab, state, context),
        );
      },
    );
  }

  Widget _pageFor(_SettingsTab tab, SettingsState state, BuildContext context) {
    switch (tab) {
      case _SettingsTab.audio:
        return _AudioPage(state: state);
      case _SettingsTab.visual:
        return _VisualPage(state: state);
      case _SettingsTab.gameplay:
        return const SizedBox.shrink(); // hidden, tab removed from sidebar
      case _SettingsTab.notifications:
        return _TodoPage(key: const ValueKey('notifications'), icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Notification settings coming soon');
      case _SettingsTab.about:
        return const _AboutPage();
    }
  }

  // ── Footer ──────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.3), size: 12),
          const SizedBox(width: 6),
          Text(
            'Fair Play  •  Secure Game',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Sidebar Tab Button ────────────────────────────────────────────────────────
class _SidebarTab extends StatelessWidget {
  final _TabInfo info;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarTab({required this.info, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.18), AppColors.gold.withValues(alpha: 0.04)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppColors.gold.withValues(alpha: 0.35)) : null,
        ),
        child: Row(
          children: [
            Icon(info.icon, color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.4), size: 18),
            const SizedBox(width: 10),
            Text(
              info.label,
              style: TextStyle(
                color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.5),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio Page ─────────────────────────────────────────────────────────────
class _AudioPage extends StatefulWidget {
  final SettingsState state;
  const _AudioPage({required this.state});

  @override
  State<_AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<_AudioPage> {
  // Using cubit state for volume

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return _ContentScaffold(
      key: const ValueKey('audio'),
      sectionLabel: 'AUDIO',
      children: [
        // Sound Effects toggle card
        _SettingsCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  state.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sound Effects', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Card sliding & flipping sounds', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                  ],
                ),
              ),
              _GoldSwitch(
                value: state.soundEnabled,
                onChanged: (_) => context.read<SettingsCubit>().toggleSound(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Volume slider section
        _SectionLabel(label: 'VOLUME'),
        const SizedBox(height: 8),
        _SettingsCard(
          child: Row(
            children: [
              Icon(Icons.volume_mute, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.gold,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: AppColors.gold,
                    overlayColor: AppColors.gold.withValues(alpha: 0.1),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: state.soundVolume,
                    min: 0,
                    max: 1,
                    onChanged: (val) {
                      context.read<SettingsCubit>().setVolume(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.4), size: 18),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  '${(state.soundVolume * 100).round()}%',
                  style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Visual Page ─────────────────────────────────────────────────────────────
class _VisualPage extends StatelessWidget {
  final SettingsState state;
  const _VisualPage({required this.state});

  @override
  Widget build(BuildContext context) {
    return _ContentScaffold(
      key: const ValueKey('visual'),
      sectionLabel: 'VISUAL',
      children: [
        const Text(
          'Table Felt Color',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose your preferred table felt color',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ColorCard(
                color: AppColors.tableGreen,
                title: 'Classic Green',
                subtitle: 'Traditional poker\ntable look',
                isSelected: state.tableColor == TableColor.green,
                onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.green),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ColorCard(
                color: AppColors.tableRed,
                title: 'Casino Red',
                subtitle: 'Vibrant & bold\ngaming feel',
                isSelected: state.tableColor == TableColor.red,
                onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.red),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ColorCard(
                color: AppColors.tableBlue,
                title: 'Midnight Blue',
                subtitle: 'Easy on the eyes\n& modern',
                isSelected: state.tableColor == TableColor.blue,
                onTap: () => context.read<SettingsCubit>().setTableColor(TableColor.blue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Color Card Widget ────────────────────────────────────────────────────────
class _ColorCard extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCard({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, height: 1.3)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.black, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TODO Page ────────────────────────────────────────────────────────────────
class _TodoPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TodoPage({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: const Text('TODO', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

// ─── About Page ────────────────────────────────────────────────────────────────
class _AboutPage extends StatefulWidget {
  const _AboutPage();

  @override
  State<_AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<_AboutPage> {
  bool _showTerms = false;
  bool _showLicense = false;
  bool _showPrivacy = false;

  @override
  Widget build(BuildContext context) {
    return _ContentScaffold(
      key: const ValueKey('about'),
      sectionLabel: 'ABOUT',
      children: [
        // App Info Card
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.style, color: AppColors.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Callbreak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('The Classic Card Game', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('Version', SocketRepository.APP_PROTOCOL_VERSION.toString()),
              _infoRow('Build', 'Release'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Developer Card
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Developer', 'Arun Mishra'),
              const SizedBox(height: 4),
              _infoRow('Contact', 'arunkmishra4@gmail.com'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Terms & Conditions
        _ExpandableCard(
          icon: Icons.gavel_outlined,
          title: 'Terms & Conditions',
          isExpanded: _showTerms,
          onToggle: () => setState(() => _showTerms = !_showTerms),
          content: const _TermsContent(),
        ),
        const SizedBox(height: 12),

        // Privacy Policy
        _ExpandableCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          isExpanded: _showPrivacy,
          onToggle: () => setState(() => _showPrivacy = !_showPrivacy),
          content: const _PrivacyContent(),
        ),
        const SizedBox(height: 12),

        // Licensing
        _ExpandableCard(
          icon: Icons.verified_outlined,
          title: 'Licensing',
          isExpanded: _showLicense,
          onToggle: () => setState(() => _showLicense = !_showLicense),
          content: const _LicenseContent(),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Expandable Card ──────────────────────────────────────────────────────────
class _ExpandableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget content;

  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.4), size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: content,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─── Privacy Content ───────────────────────────────────────────────────────────
class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 12),
        ..._sections.map((s) => _TermsSection(title: s.$1, body: s.$2)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.gold, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For questions about your data, contact us at arunkmishra4@gmail.com',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _sections = [
    ('What We Collect',
     'When you sign in with Google, we receive your name, email address, and profile picture. Guest accounts generate an anonymous identifier with no personal data attached.'),
    ('How It Is Stored',
     'All user data is stored on our secured, encrypted servers. Data is protected both at rest and in transit using industry-standard encryption protocols.'),
    ('How It Is Used',
     'Your information is used solely for authentication, displaying your in-game profile, and tracking game statistics. We do not use it for advertising or profiling.'),
    ('Third-Party Sign-In',
     'We offer sign-in via Google for your convenience. When you use this option, Google shares limited profile information with us as per their own privacy policy. We encourage you to review Google\'s Privacy Policy at policies.google.com/privacy.'),
    ('Data Sharing',
     'We do not sell, rent, or share your personal data with any third parties for marketing or advertising purposes.'),
    ('Data Deletion',
     'You may request deletion of your account and all associated data at any time by contacting us. Guest data is not linked to any personal identity.'),
    ('Children\'s Privacy',
     'Callbreak is not directed at children under 13. We do not knowingly collect personal data from children under 13.'),
  ];
}

// ─── Terms Content ─────────────────────────────────────────────────────────────
class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 12),
        ..._sections.map((s) => _TermsSection(title: s.$1, body: s.$2)),
      ],
    );
  }

  static const _sections = [
    ('1. Acceptance of Terms',
     'By downloading or using Callbreak, you agree to be bound by these Terms & Conditions. If you do not agree, please do not use the application.'),
    ('2. Eligibility',
     'This game is intended for users aged 13 and above. By using the app you confirm that you meet this requirement.'),
    ('3. Fair Play',
     'Users must not exploit bugs, use automation tools, or engage in any form of cheating. Violations may result in permanent account suspension.'),
    ('4. User Conduct',
     'Users agree to behave respectfully within the platform. Harassment, abusive language, or any harmful behaviour towards other players is strictly prohibited.'),
    ('5. Virtual Items',
     'Any in-game currency, rewards, or virtual items have no real-world monetary value and cannot be exchanged, transferred, or redeemed for cash.'),
    ('6. Account Responsibility',
     'You are responsible for maintaining the confidentiality of your account. Sharing accounts is not permitted and may result in suspension.'),
    ('7. Modifications',
     'We reserve the right to update these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.'),
    ('8. Termination',
     'We reserve the right to suspend or terminate access to the game for violations of these terms or for any other reason at our sole discretion.'),
  ];
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;
  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(body, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── License Content ───────────────────────────────────────────────────────────
class _LicenseContent extends StatelessWidget {
  const _LicenseContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 12),
        Text(
          'MIT License — © 2025 Arun Mishra',
          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Permission is hereby granted, free of charge, to any person obtaining a copy of this software to use, copy, modify, and distribute, subject to the following conditions:\n\n'
          'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\n'
          'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY ARISING FROM THE USE OF THIS SOFTWARE.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11, height: 1.6),
        ),
        const SizedBox(height: 12),
        Text('Open Source Acknowledgements', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ..._libs.map((lib) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(Icons.circle, size: 4, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              Text(lib, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
            ],
          ),
        )),
      ],
    );
  }

  static const _libs = [
    'Flutter SDK — BSD 3-Clause License',
    'Supabase Flutter — Apache 2.0 License',
    'flutter_bloc — MIT License',
    'shared_preferences — BSD 3-Clause License',
    'share_plus — BSD 3-Clause License',
  ];
}


// ─── Reusable helpers ──────────────────────────────────────────────────────────
class _ContentScaffold extends StatelessWidget {
  final String sectionLabel;
  final List<Widget> children;

  const _ContentScaffold({super.key, required this.sectionLabel, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: sectionLabel),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.gold,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );
  }
}

// ─── Gold Toggle Switch ────────────────────────────────────────────────────────
class _GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GoldSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: value ? AppColors.gold : Colors.white.withValues(alpha: 0.15),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Colors.black : Colors.white.withValues(alpha: 0.6),
            ),
            child: value ? const Icon(Icons.check, size: 12, color: AppColors.gold) : null,
          ),
        ),
      ),
    );
  }
}
