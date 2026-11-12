import 'package:material_ui/material_ui.dart';

class AppPreset {
  const AppPreset(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

/// Presets the user can mark as "apps I want to manage". These are labels
/// only; they are not yet linked to installed apps on the device.
const appPresets = <AppPreset>[
  AppPreset('instagram', 'Instagram', Icons.photo_camera_outlined),
  AppPreset('youtube', 'YouTube', Icons.smart_display_outlined),
  AppPreset('tiktok', 'TikTok', Icons.music_note_outlined),
  AppPreset('reddit', 'Reddit', Icons.forum_outlined),
  AppPreset('x', 'X', Icons.alternate_email),
  AppPreset('facebook', 'Facebook', Icons.groups_outlined),
  AppPreset('snapchat', 'Snapchat', Icons.chat_bubble_outline),
  AppPreset('games', 'Games', Icons.sports_esports_outlined),
  AppPreset('streaming', 'Streaming', Icons.live_tv_outlined),
];

class GoalOption {
  const GoalOption(this.id, this.title);
  final String id;
  final String title;
}

const goalOptions = <GoalOption>[
  GoalOption('less_scrolling', 'Less passive scrolling'),
  GoalOption('keep_messaging', 'Keep messaging, cut the feeds'),
  GoalOption('better_sleep', 'Better sleep'),
  GoalOption('deep_focus', 'Deeper focus for study or work'),
  GoalOption('understand_usage', 'Just understand my usage'),
];

class FocusModePreset {
  const FocusModePreset(this.name, this.summary, this.icon);
  final String name;
  final String summary;
  final IconData icon;
}

const focusModePresets = <FocusModePreset>[
  FocusModePreset(
    'Study',
    'Distracting apps restricted, with Pomodoro breaks.',
    Icons.menu_book_outlined,
  ),
  FocusModePreset(
    'Work',
    'Entertainment limited; communication stays open.',
    Icons.work_outline,
  ),
  FocusModePreset(
    'Sleep',
    'Bedtime restrictions with important contacts reachable.',
    Icons.bedtime_outlined,
  ),
  FocusModePreset(
    'Social',
    'Messaging-friendly, tighter budgets for passive scrolling.',
    Icons.people_outline,
  ),
  FocusModePreset(
    'Deep Focus',
    'Longer uninterrupted sessions with limited overrides.',
    Icons.center_focus_strong_outlined,
  ),
];
