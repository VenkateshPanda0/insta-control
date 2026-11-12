import 'package:flutter/services.dart';

import 'capability.dart';

abstract interface class PlatformCapabilityService {
  /// Never throws: failures come back as [PlatformReport.unreachable].
  Future<PlatformReport> fetchReport();
}

const platformChannel = MethodChannel('app.unscroll/platform');

class MethodChannelCapabilityService implements PlatformCapabilityService {
  const MethodChannelCapabilityService();

  @override
  Future<PlatformReport> fetchReport() async {
    try {
      final map = await platformChannel.invokeMapMethod<Object?, Object?>(
        'getPlatformReport',
      );
      if (map == null) {
        return const PlatformReport.unreachable(
          'The device returned no capability information.',
        );
      }
      return PlatformReport.fromMap(map);
    } on MissingPluginException {
      return const PlatformReport.unreachable(
        'Device features are not available on this platform.',
      );
    } on PlatformException catch (e) {
      return PlatformReport.unreachable(
        'Could not check device features (${e.code}).',
      );
    }
  }
}
