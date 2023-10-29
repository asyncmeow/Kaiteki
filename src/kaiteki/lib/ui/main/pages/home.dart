import "package:flutter/material.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/fediverse/services/timeline.dart";
import "package:kaiteki/preferences/theme_preferences.dart";
import "package:kaiteki/ui/shared/posts/post_widget.dart";
import "package:kaiteki/ui/shared/timeline/source.dart";
import "package:kaiteki/ui/shared/timeline/widget.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki_core/social.dart";

/// Timeline tabs to show.
///
/// This is intentionally not [TimelineType.values] because the values might
/// not be important to the user.
Set<TimelineType> get _defaultKinds {
  return const {
    TimelineType.following,
    TimelineType.local,
    TimelineType.bubble,
    TimelineType.hybrid,
    TimelineType.federated,
  };
}

final _timelineProvider = Provider<Iterable<TimelineSource>>(
  (ref) {
    return ref.watch(
      adapterProvider.select(
        (adapter) => _defaultKinds
            .where(adapter.capabilities.supportedTimelines.contains)
            .map(StandardTimelineSource.new),
      ),
    );
  },
  dependencies: [adapterProvider],
);

class HomePage extends ConsumerStatefulWidget {
  final TimelineType? initialTimeline;
  final TabAlignment? tabAlignment;

  const HomePage({
    super.key,
    this.initialTimeline,
    this.tabAlignment,
  });

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  TimelineSource? _currentTimeline;

  TimelineSource? get timeline => _currentTimeline;

  @override
  void initState() {
    super.initState();

    ref.listenManual(
      _timelineProvider,
      (previous, next) {
        // this shouldn't happen
        if (next.isEmpty) {
          _currentTimeline = null;
          _tabController?.dispose();
          return;
        }

        // ensure the current timeline is still set to a valid one
        if (_currentTimeline == null || !next.contains(_currentTimeline)) {
          _currentTimeline = next.first;
        }

        // recreate the TabController if the number of tabs changed, as the
        // TabController.length cannot be changed after instantiation
        if (previous == null || previous.length != next.length) {
          _tabController = TabController(
            vsync: this,
            length: next.length,
            initialIndex: next.toList().indexOf(_currentTimeline!),
          );
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timelines = ref.watch(_timelineProvider);

    final showTabBar = timelines.length >= 2;
    return Column(
      children: [
        if (showTabBar)
          TabBar(
            controller: _tabController,
            isScrollable: true,
            onTap: _onTabTap,
            tabAlignment: widget.tabAlignment,
            tabs: timelines.map((e) => _TimelineTab(timeline: e)).toList(),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children:
                timelines.map((e) => _TimelineTabPage(timeline: e)).toList(),
          ),
        ),
      ],
    );
  }

  void _onTabTap(int value) {
    final timelines = ref.read(_timelineProvider);
    _currentTimeline = timelines.elementAt(value);
  }

  void _onRefresh() {
    final key = ref.read(currentAccountProvider)!.key;
    final provider = TimelineServiceProvider(key, _currentTimeline!);
    ref.invalidate(provider);
  }
}

class _TimelineTab extends StatelessWidget {
  final TimelineSource timeline;
  final bool showLabel;

  const _TimelineTab({
    required this.timeline,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String getTabLabel() {
      final timeline = this.timeline;
      return switch (timeline) {
        UserTimelineSource() => timeline.userId,
        StandardTimelineSource() => timeline.type.getDisplayName(l10n),
        ListTimelineSource() => timeline.listId,
        HashtagTimelineSource() => "#${timeline.hashtag}",
      };
    }

    Icon buildTabIcon() {
      final timeline = this.timeline;
      return switch (timeline) {
        UserTimelineSource() => const Icon(Icons.person_rounded),
        StandardTimelineSource() => Icon(timeline.type.getIconData()),
        ListTimelineSource() => const Icon(Icons.article_rounded),
        HashtagTimelineSource() => const Icon(Icons.tag_rounded),
      };
    }

    final label = getTabLabel();
    final icon = buildTabIcon();

    return Semantics(
      label: label,
      child: Tab(
        icon: ExcludeSemantics(
          child: showLabel
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                )
              : icon,
        ),
      ),
    );
  }
}

class _TimelineTabPage extends ConsumerWidget {
  final TimelineSource timeline;

  const _TimelineTabPage({required this.timeline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        final key = ref.read(currentAccountProvider)!.key;
        final provider = TimelineServiceProvider(key, timeline);
        return ref.refresh(provider.notifier);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Timeline(
          timeline,
          maxWidth: 600,
          postLayout: ref.watch(useWidePostLayout).value
              ? PostWidgetLayout.wide
              : PostWidgetLayout.normal,
        ),
      ),
    );
  }
}
