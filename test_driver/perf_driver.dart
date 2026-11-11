// Host side of `flutter drive` for integration_test/perf_test.dart. Receives the frame-timing
// summaries the test reported and writes them to build/perf/ (json + a markdown table that
// integration_test/run_perf.sh pastes into PERF-RESULTS.md).
import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const _scenarios = {
  'feed_scroll': 'Scroll the feed (fling down x4, up x4)',
  'listing_open_hero': 'Open a listing (hero) and go back, x3',
  'tab_switch': 'Switch tabs Home/Search/Build/Chats/Profile, x3 rounds',
  'build_tilt': 'Tilt the KeyboardLayers with drags (2 parts filled)',
  'build_clear': 'Clear 2 filled build slots (layers lift away)',
  'build_fill': 'Fill a build slot via Find, Add to build, back (layer drops in)',
};

String _f(Object? v) => v is num ? v.toStringAsFixed(2) : '$v';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final dir = Directory('build/perf')..createSync(recursive: true);
        File('${dir.path}/summary.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
        final b = StringBuffer()
          ..writeln('| Scenario | Frames | Build avg / p90 / p99 / worst (ms) | Raster avg / p90 / p99 / worst (ms) | Missed build / raster budget |')
          ..writeln('|---|---|---|---|---|');
        for (final e in _scenarios.entries) {
          final s = data[e.key];
          if (s is! Map) {
            b.writeln('| ${e.value} | no data | | | |');
            continue;
          }
          b.writeln('| ${e.value} | ${s['frame_count']} '
              '| ${_f(s['average_frame_build_time_millis'])} / ${_f(s['90th_percentile_frame_build_time_millis'])} / ${_f(s['99th_percentile_frame_build_time_millis'])} / ${_f(s['worst_frame_build_time_millis'])} '
              '| ${_f(s['average_frame_rasterizer_time_millis'])} / ${_f(s['90th_percentile_frame_rasterizer_time_millis'])} / ${_f(s['99th_percentile_frame_rasterizer_time_millis'])} / ${_f(s['worst_frame_rasterizer_time_millis'])} '
              '| ${s['missed_frame_build_budget_count']} / ${s['missed_frame_rasterizer_budget_count']} |');
        }
        File('${dir.path}/table.md').writeAsStringSync(b.toString());
      },
    );
