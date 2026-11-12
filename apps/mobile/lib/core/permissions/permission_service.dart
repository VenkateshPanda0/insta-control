import 'package:flutter/services.dart';

import '../platform_capabilities/capability.dart';
import '../platform_capabilities/platform_capability_service.dart';

enum PermissionRequestOutcome { granted, denied, openedSettings, failed }

class PermissionRequestResult {
  const PermissionRequestResult(this.outcome, [this.message]);
  final PermissionRequestOutcome outcome;
  final String? message;
}

abstract interface class PermissionService {
  /// Never throws. The caller should refresh the platform report afterwards;
  /// that report, not this result, is the source of truth for status.
  Future<PermissionRequestResult> request(AppPermission permission);
}

class MethodChannelPermissionService implements PermissionService {
  const MethodChannelPermissionService();

  @override
  Future<PermissionRequestResult> request(AppPermission permission) async {
    try {
      final map = await platformChannel.invokeMapMethod<Object?, Object?>(
        'requestPermission',
        {'permission': permission.name},
      );
      final outcome = PermissionRequestOutcome.values
          .where((o) => o.name == map?['outcome'])
          .firstOrNull;
      final message = map?['message'];
      return PermissionRequestResult(
        outcome ?? PermissionRequestOutcome.failed,
        message is String ? message : null,
      );
    } on MissingPluginException {
      return const PermissionRequestResult(
        PermissionRequestOutcome.failed,
        'Permissions are not available on this platform.',
      );
    } on PlatformException catch (e) {
      return PermissionRequestResult(
        PermissionRequestOutcome.failed,
        e.message ?? 'The permission request failed.',
      );
    }
  }
}
