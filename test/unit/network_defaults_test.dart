import 'package:daily_meal/core/providers/network_provider.dart';
import 'package:daily_meal/core/services/reachability_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud features are not Wi-Fi-only by default', () {
    // With `true` and no UI switch, mobile-data users could never propose.
    expect(kWifiOnlyCloudDefault, isFalse);
  });

  test('reachability never probes DNS port 53 (blocked on many networks)', () {
    for (final url in ReachabilityService.probeUrls) {
      expect(url, startsWith('https://'));
      expect(url, isNot(contains(':53')));
    }
  });
}
