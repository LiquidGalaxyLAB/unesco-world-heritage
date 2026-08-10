import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HelpView extends StatelessWidget {
  const HelpView({super.key});

  static const List<_HelpSectionData> _sections = [
    _HelpSectionData(
      title: 'Liquid Galaxy Connection',
      items: [
        _HelpItemData(
          question: 'What details do I need before connecting to LG?',
          answer:
              'Open Settings, then use LG Connection to enter the master rig IP address, SSH port, LG username, LG password, and the number of screens in the rig. The default SSH port is 22 and the default username is lg.',
        ),
        _HelpItemData(
          question: 'Why does the header still show LG DISCONNECTED?',
          answer:
              'The app only switches to LG CONNECTED after the SSH login succeeds. Check that the phone or emulator can reach the same network as the Liquid Galaxy master, then verify the IP address, port, username, and password.',
        ),
        _HelpItemData(
          question: 'What does the screen count change?',
          answer:
              'The screen count tells the app which slave screens can receive side content such as logos, info balloons, and KML overlays. Use the actual number of Liquid Galaxy screens configured in the rig.',
        ),
      ],
    ),
    _HelpSectionData(
      title: 'Maps And Site Discovery',
      items: [
        _HelpItemData(
          question: 'Why is the home page showing loading cards?',
          answer:
              'Home loads the UNESCO dataset and asks for device location so it can sort nearby sites. If location is unavailable, the app falls back to the default site list.',
        ),
        _HelpItemData(
          question: 'How do I find a specific heritage site?',
          answer:
              'Use the Search tab to type a site name, then use the filter button to narrow results by country, region, category, inscription year, or danger status.',
        ),
        _HelpItemData(
          question: 'Why is the map blank or not loading?',
          answer:
              'The map uses a Google Maps API key. Add the key in API Authentication, or provide it in the app environment. Also confirm the device has internet access.',
        ),
      ],
    ),
    _HelpSectionData(
      title: 'Viewing Sites On LG',
      items: [
        _HelpItemData(
          question: 'What happens when I open a heritage site?',
          answer:
              'If LG is connected, the app prepares the site scene, sends KML to the rig, flies Google Earth to the site, and starts live camera sync from the in-app map.',
        ),
        _HelpItemData(
          question: 'What does Orbit do?',
          answer:
              'Orbit plays the generated KML tour for the selected site. Tap Stop Orbit to exit the tour, or wait for the tour to finish and the button will return to Orbit.',
        ),
        _HelpItemData(
          question: 'Why do some boundaries look simplified?',
          answer:
              'Large UNESCO boundaries are simplified before sending to LG so the KML stays light enough for the rig to render reliably across multiple screens.',
        ),
      ],
    ),
    _HelpSectionData(
      title: 'AI, Audio, And Climate',
      items: [
        _HelpItemData(
          question: 'Why is Ask Gemini failing?',
          answer:
              'Gemini features require a Gemini API key saved in API Authentication. If the key is missing or invalid, chat and generated site stories will fall back or show an error.',
        ),
        _HelpItemData(
          question: 'What do Play, Mute, and Replay control?',
          answer:
              'These controls play the AI-generated site story through the app audio, stop audio while muted, or regenerate playback for the current heritage site.',
        ),
        _HelpItemData(
          question: 'Where does the Climate tab data come from?',
          answer:
              'The Climate tab fetches current weather near the selected site and combines it with the bundled best-time-to-visit dataset when a matching UNESCO property ID is available.',
        ),
      ],
    ),
    _HelpSectionData(
      title: 'LG Commands',
      items: [
        _HelpItemData(
          question: 'Why are command buttons disabled?',
          answer:
              'Relaunch LG, Reboot LG, Clean KML, Power Off, and Clean Logo are enabled only after the app is connected to the Liquid Galaxy rig.',
        ),
        _HelpItemData(
          question: 'When should I use Clean KML or Clean Logo?',
          answer:
              'Use Clean KML to clear active KML tours and overlays from the rig. Use Clean Logo when you only need to remove the logo overlay from the side screen.',
        ),
        _HelpItemData(
          question: 'When should I use Relaunch or Reboot?',
          answer:
              'Use Relaunch LG when Google Earth or the LG display stack stops responding. Use Reboot LG only when a full rig restart is needed.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Help',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                itemCount: _sections.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 28),
                itemBuilder: (context, sectionIndex) {
                  final section = _sections[sectionIndex];
                  return _HelpSection(section: section);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.section});

  final _HelpSectionData section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: AppColors.outlineVariant, height: 1),
        const SizedBox(height: 12),
        for (final item in section.items) ...[
          _HelpItem(item: item),
          if (item != section.items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({required this.item});

  final _HelpItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant, width: 0.8),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.onSurfaceVariant,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            item.question,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          children: [
            Text(
              item.answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSectionData {
  const _HelpSectionData({required this.title, required this.items});

  final String title;
  final List<_HelpItemData> items;
}

class _HelpItemData {
  const _HelpItemData({required this.question, required this.answer});

  final String question;
  final String answer;
}
