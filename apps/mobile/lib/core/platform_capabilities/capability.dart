/// Capability model shared by every feature. The UI asks the
/// [CapabilityRegistry] before rendering any functional control.
library;

enum CapabilityStatus {
  supported,
  supportedWithLimitations,
  experimental,
  requiresAuthorization,
  unavailable;

  String get label => switch (this) {
    supported => 'Fully supported',
    supportedWithLimitations => 'Supported with limitations',
    experimental => 'Experimental',
    requiresAuthorization => 'Requires authorization',
    unavailable => 'Unavailable',
  };
}

/// Where a limitation comes from, so the app can explain it honestly.
enum LimitationSource {
  none,
  ios,
  android,
  thirdPartyApp,

  /// The operating system could support this, but this version of Unscroll
  /// has not built it yet.
  unscrollBuild;

  String get label => switch (this) {
    none => '',
    ios => 'iOS limitation',
    android => 'Android limitation',
    thirdPartyApp => 'Third-party app limitation',
    unscrollBuild => 'Not in this version yet',
  };
}

enum FeatureId {
  usageReporting,
  appSelection,
  appBlocking,
  scheduledRestrictions,
  launchInterception,
  inAppSectionControl,
  reminders,
  focusSessions,
}

class FeatureDescriptor {
  const FeatureDescriptor({
    required this.id,
    required this.title,
    required this.description,
    this.alternative,
  });

  final FeatureId id;
  final String title;
  final String description;

  /// What the user can do instead when the feature is unavailable.
  final String? alternative;
}

const featureCatalog = <FeatureDescriptor>[
  FeatureDescriptor(
    id: FeatureId.usageReporting,
    title: 'Screen-time reporting',
    description: 'Measured usage per app from the operating system.',
  ),
  FeatureDescriptor(
    id: FeatureId.appSelection,
    title: 'Choosing installed apps',
    description: 'Pick the real apps on this device that Unscroll manages.',
    alternative:
        'Until then, Unscroll remembers the app presets you chose in setup.',
  ),
  FeatureDescriptor(
    id: FeatureId.appBlocking,
    title: 'App restrictions',
    description: 'Restrict a whole app when a limit or schedule applies.',
    alternative: 'Reminders can be used where blocking is not possible.',
  ),
  FeatureDescriptor(
    id: FeatureId.scheduledRestrictions,
    title: 'Scheduled restrictions',
    description: 'Apply restrictions automatically at set times.',
  ),
  FeatureDescriptor(
    id: FeatureId.launchInterception,
    title: 'Intentional launch prompt',
    description: 'Ask for your purpose at the moment an app opens.',
    alternative:
        'Open the app from inside Unscroll to choose a purpose and a time '
        'budget first.',
  ),
  FeatureDescriptor(
    id: FeatureId.inAppSectionControl,
    title: 'Hiding sections inside other apps',
    description:
        'Removing Reels, Explore or suggested posts from inside the native '
        'Instagram app, or similar sections in other apps.',
    alternative:
        'Use Instagram\'s own Following feed, short timed sessions, and '
        'whole-app limits.',
  ),
  FeatureDescriptor(
    id: FeatureId.reminders,
    title: 'Reminders and budget notifications',
    description: 'Gentle notifications about budgets, breaks and bedtime.',
  ),
  FeatureDescriptor(
    id: FeatureId.focusSessions,
    title: 'Focus sessions',
    description: 'Timed focus modes with their own app restrictions.',
  ),
];

class Capability {
  const Capability({
    required this.feature,
    required this.status,
    this.reason = '',
    this.source = LimitationSource.none,
  });

  final FeatureDescriptor feature;
  final CapabilityStatus status;

  /// Why the feature has this status on this device.
  final String reason;
  final LimitationSource source;

  /// Only these statuses may be shown as a working, interactive control.
  bool get isUsable =>
      status == CapabilityStatus.supported ||
      status == CapabilityStatus.supportedWithLimitations ||
      status == CapabilityStatus.experimental;
}

enum AppPermission {
  usageAccess,
  screenTime,
  notifications;

  String get title => switch (this) {
    usageAccess => 'Usage access',
    screenTime => 'Screen Time access',
    notifications => 'Notifications',
  };

  String get explanation => switch (this) {
    usageAccess =>
      'Lets Unscroll read how long each app was used, from Android\'s own '
          'records. Unscroll never sees what you do inside an app.',
    screenTime =>
      'Lets Unscroll use Apple\'s Screen Time tools to restrict apps you '
          'choose. Apple keeps your usage details private from Unscroll.',
    notifications =>
      'Lets Unscroll send reminders about budgets, breaks and bedtime.',
  };
}

enum PermissionState {
  granted,
  denied,
  notDetermined,
  unavailable;

  String get label => switch (this) {
    granted => 'Allowed',
    denied => 'Not allowed',
    notDetermined => 'Not asked yet',
    unavailable => 'Unavailable',
  };
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

class CapabilityReport {
  const CapabilityReport(this.status, this.reason, this.source);
  final CapabilityStatus status;
  final String reason;
  final LimitationSource source;
}

/// What the native layer told us about this device. Parsed defensively:
/// anything malformed or unknown is dropped, never trusted.
class PlatformReport {
  const PlatformReport({
    required this.platform,
    required this.osVersion,
    required this.permissions,
    required this.capabilities,
    this.error,
  });

  /// Used when the native layer cannot be reached at all.
  const PlatformReport.unreachable(String this.error)
    : platform = 'unknown',
      osVersion = '',
      permissions = const {},
      capabilities = const {};

  final String platform;
  final String osVersion;
  final Map<AppPermission, PermissionState> permissions;
  final Map<FeatureId, CapabilityReport> capabilities;
  final String? error;

  factory PlatformReport.fromMap(Map<Object?, Object?> map) {
    final permissions = <AppPermission, PermissionState>{};
    final rawPermissions = map['permissions'];
    if (rawPermissions is Map) {
      rawPermissions.forEach((key, value) {
        final permission = _byName(AppPermission.values, key);
        final state = _byName(PermissionState.values, value);
        if (permission != null && state != null) {
          permissions[permission] = state;
        }
      });
    }
    final capabilities = <FeatureId, CapabilityReport>{};
    final rawCapabilities = map['capabilities'];
    if (rawCapabilities is Map) {
      rawCapabilities.forEach((key, value) {
        final id = _byName(FeatureId.values, key);
        if (id == null || value is! Map) return;
        final status = _byName(CapabilityStatus.values, value['status']);
        if (status == null) return;
        capabilities[id] = CapabilityReport(
          status,
          value['reason'] is String ? value['reason'] as String : '',
          _byName(LimitationSource.values, value['source']) ??
              LimitationSource.none,
        );
      });
    }
    return PlatformReport(
      platform: map['platform'] is String
          ? map['platform'] as String
          : 'unknown',
      osVersion: map['osVersion'] is String ? map['osVersion'] as String : '',
      permissions: permissions,
      capabilities: capabilities,
    );
  }
}
