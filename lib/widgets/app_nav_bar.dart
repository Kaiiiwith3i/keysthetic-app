import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'fly_to_target.dart';
import 'pressable.dart';

class NavItem {
  const NavItem(this.id, this.label, this.icon, this.activeIcon);
  final String id; // key becomes `nav.<id>`
  final String label;
  final IconData icon, activeIcon;
}

/// Custom bottom nav: a floating keycap tray; the active "key" slides between
/// tabs, its icon lifts and the label turns accent. The Build icon carries
/// [BuildNavAnchor.key] so [flyToBuild] can land on it.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.index, required this.onSelect});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.keys;
    final reduce = context.reduceMotion;
    final n = items.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
        child: RepaintBoundary(
          child: Container(
            height: 68,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [k.capTop, k.capBottom]),
              borderRadius: BorderRadius.circular(Rad.xl),
              border: Border(bottom: BorderSide(color: k.capLip, width: 3)),
              boxShadow: [BoxShadow(color: k.shadow, blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Stack(children: [
              AnimatedAlign(
                duration: reduce ? Duration.zero : Dur.slow,
                curve: Curves.easeOutBack,
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.cs.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: context.cs.primary.withValues(alpha: .4), width: 1.5),
                    ),
                  ),
                ),
              ),
              Row(children: [
                for (var i = 0; i < n; i++)
                  Expanded(child: _Tab(item: items[i], selected: i == index, onTap: () => onSelect(i))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.cs.primary : context.cs.onSurfaceVariant;
    Widget icon = Icon(selected ? item.activeIcon : item.icon, size: 24, color: color);
    if (item.id == 'build') icon = LandingBounce(child: KeyedSubtree(key: BuildNavAnchor.key, child: icon));
    return Pressable(
      key: ValueKey('nav.${item.id}'),
      semanticLabel: item.label,
      onTap: onTap,
      minSize: 56,
      pressedScale: .9,
      child: SizedBox(
        height: 60,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSlide(
            duration: context.reduceMotion ? Duration.zero : Dur.base,
            curve: Curves.easeOutBack,
            offset: Offset(0, selected ? -.08 : 0),
            child: icon,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(item.label, maxLines: 1, style: context.tt.labelSmall!.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        ]),
      ),
    );
  }
}
