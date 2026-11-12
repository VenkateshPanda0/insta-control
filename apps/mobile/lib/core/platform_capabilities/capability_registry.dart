import 'capability.dart';

/// Single source of truth for what works on this device.
///
/// A feature the native layer did not report is treated as unavailable, so
/// the UI can never show a working control for something unconfirmed.
class CapabilityRegistry {
  CapabilityRegistry(this.report);

  final PlatformReport report;

  Capability of(FeatureId id) {
    final feature = featureCatalog.firstWhere((f) => f.id == id);
    final reported = report.capabilities[id];
    if (reported == null) {
      return Capability(
        feature: feature,
        status: CapabilityStatus.unavailable,
        reason:
            report.error ?? 'This device did not confirm support for this.',
      );
    }
    return Capability(
      feature: feature,
      status: reported.status,
      reason: reported.reason,
      source: reported.source,
    );
  }

  List<Capability> get all => [for (final f in featureCatalog) of(f.id)];

  PermissionState permission(AppPermission permission) =>
      report.permissions[permission] ?? PermissionState.unavailable;
}
