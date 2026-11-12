import 'package:flutter_test/flutter_test.dart';
import 'package:unscroll/core/platform_capabilities/capability.dart';
import 'package:unscroll/core/platform_capabilities/capability_registry.dart';

void main() {
  test('unreported features are unavailable, never usable', () {
    final registry = CapabilityRegistry(
      const PlatformReport.unreachable('no native layer'),
    );
    expect(registry.all, hasLength(FeatureId.values.length));
    for (final c in registry.all) {
      expect(c.status, CapabilityStatus.unavailable);
      expect(c.isUsable, isFalse);
      expect(c.reason, 'no native layer');
    }
    expect(
      registry.permission(AppPermission.usageAccess),
      PermissionState.unavailable,
    );
  });

  test('parses a native report and ignores malformed entries', () {
    final report = PlatformReport.fromMap({
      'platform': 'Android',
      'osVersion': '15',
      'permissions': {
        'usageAccess': 'granted',
        'madeUp': 'granted',
        'notifications': 7,
      },
      'capabilities': {
        'usageReporting': {'status': 'supported', 'reason': 'ok'},
        'appBlocking': {
          'status': 'requiresAuthorization',
          'source': 'android',
          'reason': 'needs access',
        },
        'reminders': {'status': 'definitely'},
        'focusSessions': 'yes',
        'unknownFeature': {'status': 'supported'},
      },
    });
    final registry = CapabilityRegistry(report);

    expect(
      registry.permission(AppPermission.usageAccess),
      PermissionState.granted,
    );
    expect(
      registry.permission(AppPermission.notifications),
      PermissionState.unavailable,
    );
    expect(registry.of(FeatureId.usageReporting).isUsable, isTrue);

    final blocking = registry.of(FeatureId.appBlocking);
    expect(blocking.status, CapabilityStatus.requiresAuthorization);
    expect(blocking.source, LimitationSource.android);
    expect(blocking.isUsable, isFalse);

    // Bad status / wrong shape must not be read as support.
    expect(
      registry.of(FeatureId.reminders).status,
      CapabilityStatus.unavailable,
    );
    expect(
      registry.of(FeatureId.focusSessions).status,
      CapabilityStatus.unavailable,
    );
  });

  test('every feature id has a catalog entry', () {
    expect(featureCatalog.map((f) => f.id).toSet(), FeatureId.values.toSet());
  });
}
