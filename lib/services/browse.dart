import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/build.dart';
import '../models/listing.dart';
import '../widgets/keyboard_layers.dart';
import 'api.dart';
import 'providers.dart';

/// API enum values -> display labels, shared by cards, filters and detail.
const categoryLabels = {
  'keyboard': 'Keyboards',
  'keycaps': 'Keycaps',
  'switches': 'Switches',
  'stabilizers': 'Stabilizers',
  'cable': 'Cables',
};
const conditionLabels = {'new': 'New', 'like_new': 'Like new', 'used': 'Used', 'for_parts': 'For parts'};
const connectionLabels = {'wired': 'Wired', 'wireless': 'Wireless'};
const layoutLabels = {'full': 'Full', 'tkl': 'TKL', '75': '75%', '65': '65%', '60': '60%', '40': '40%'};
const stemLabels = {'mx': 'MX', 'alps': 'Alps', 'topre': 'Topre', 'low_profile': 'Low profile'};
const connectorLabels = {'usb_c': 'USB-C', 'usb_a': 'USB-A', 'mini_usb': 'Mini-USB'};
const switchTypeLabels = {'linear': 'Linear', 'tactile': 'Tactile', 'clicky': 'Clicky'};
const sortLabels = {'new': 'Newest', 'price_asc': 'Price: low to high', 'price_desc': 'Price: high to low'};

/// Build slot <-> listing category (the API calls the board slot's category "keyboard").
String categoryOfSlot(BuildSlot s) => s == BuildSlot.board ? 'keyboard' : s.name;
BuildSlot? slotOfCategory(String c) => BuildSlot.fromApi(c == 'keyboard' ? 'board' : c);
const slotLabels = {
  BuildSlot.board: 'Keyboard',
  BuildSlot.switches: 'Switches',
  BuildSlot.keycaps: 'Keycaps',
  BuildSlot.stabilizers: 'Stabilizers',
  BuildSlot.cable: 'Cable',
};

const _keep = Object();

/// Everything `GET /listings` can filter on. Value-equal so it can key a provider family.
class ListingFilter {
  const ListingFilter({this.q, this.category, this.minPrice, this.maxPrice, this.condition, this.layout, this.connection, this.buildId, this.sort});
  final String? q, category, condition, layout, connection, sort;
  final int? minPrice, maxPrice, buildId;

  /// Pass `null` to clear a field; omit it to keep the current value.
  ListingFilter copyWith({
    Object? q = _keep, Object? category = _keep, Object? minPrice = _keep, Object? maxPrice = _keep, Object? condition = _keep,
    Object? layout = _keep, Object? connection = _keep, Object? buildId = _keep, Object? sort = _keep,
  }) =>
      ListingFilter(
        q: identical(q, _keep) ? this.q : q as String?,
        category: identical(category, _keep) ? this.category : category as String?,
        minPrice: identical(minPrice, _keep) ? this.minPrice : minPrice as int?,
        maxPrice: identical(maxPrice, _keep) ? this.maxPrice : maxPrice as int?,
        condition: identical(condition, _keep) ? this.condition : condition as String?,
        layout: identical(layout, _keep) ? this.layout : layout as String?,
        connection: identical(connection, _keep) ? this.connection : connection as String?,
        buildId: identical(buildId, _keep) ? this.buildId : buildId as int?,
        sort: identical(sort, _keep) ? this.sort : sort as String?,
      );

  List<Object?> get _props => [q, category, minPrice, maxPrice, condition, layout, connection, buildId, sort];
  @override
  bool operator ==(Object other) => other is ListingFilter && _props.indexed.every((e) => e.$2 == other._props[e.$1]);
  @override
  int get hashCode => Object.hashAll(_props);
}

// Riverpod 3 retries failed providers by default; screens have their own "Try again", so show errors at once.
Duration? _noRetry(int _, Object _) => null;

final listingsProvider = FutureProvider.autoDispose.family<List<Listing>, ListingFilter>(
  (ref, f) => ref.watch(apiProvider).listings(
        q: f.q, category: f.category, minPrice: f.minPrice, maxPrice: f.maxPrice, condition: f.condition,
        layout: f.layout, connection: f.connection, buildId: f.buildId, sort: f.sort,
      ),
  retry: _noRetry,
);

final listingProvider = FutureProvider.autoDispose.family<Listing, int>((ref, id) => ref.watch(apiProvider).listing(id), retry: _noRetry);

/// The buyer's builds, kept in sync after every write (the API returns the updated build).
class BuildsNotifier extends AsyncNotifier<List<Build>> {
  @override
  Future<List<Build>> build() => ref.watch(apiProvider).builds();

  Api get _api => ref.read(apiProvider);
  List<Build> get _list => state.value ?? const [];
  void _replace(Build b) => state = AsyncData([for (final x in _list) x.id == b.id ? b : x]);

  Future<Build> create(String name) async {
    final b = await _api.createBuild(name: name);
    state = AsyncData([..._list, b]);
    ref.read(selectedBuildIdProvider.notifier).set(b.id);
    return b;
  }

  Future<void> rename(int id, String name) async => _replace(await _api.updateBuild(id, name: name));
  Future<void> setSpec(int id, {String? layout, String? stem, String? connector}) async =>
      _replace(await _api.updateBuild(id, layout: layout, stem: stem, connector: connector));
  Future<void> setSlot(int id, BuildSlot slot, int? listingId) async =>
      _replace(await _api.updateBuild(id, slots: {slot.name: listingId}));

  Future<void> remove(int id) async {
    await _api.deleteBuild(id);
    state = AsyncData([for (final x in _list) if (x.id != id) x]);
  }
}

final buildsProvider = AsyncNotifierProvider<BuildsNotifier, List<Build>>(BuildsNotifier.new, retry: _noRetry);

class SelectedBuildId extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final selectedBuildIdProvider = NotifierProvider<SelectedBuildId, int?>(SelectedBuildId.new);

/// The selected build, falling back to the first one.
Build? selectedBuild(List<Build> builds, int? id) => builds.where((b) => b.id == id).firstOrNull ?? builds.firstOrNull;
