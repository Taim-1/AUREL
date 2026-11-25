import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme/aurel_theme.dart';
import '../../data/services/aurel_controller.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _debounce?.cancel();
    await context.read<AurelController>().searchMusic(_searchController.text);
  }

  void _searchTag(String tag) {
    _debounce?.cancel();
    _searchFocus.unfocus();
    _searchController.text = tag;
    context.read<AurelController>().searchByTag(tag.toLowerCase());
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      context.read<AurelController>().searchMusic(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final hasQuery = controller.searchQuery.isNotEmpty;

    // Mood shortcuts and Home recommendations can start a search from another
    // screen. Reflect that query here without stealing the keyboard from users.
    if (!_searchFocus.hasFocus &&
        _searchController.text != controller.searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _searchFocus.hasFocus) return;
        _searchController.value = TextEditingValue(
          text: controller.searchQuery,
          selection: TextSelection.collapsed(
            offset: controller.searchQuery.length,
          ),
        );
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
      children: [
        const Text(
          'Search',
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Find a sound, an artist, or a new favourite.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'What do you want to hear?',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AurelColors.champagne,
            ),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _debounce?.cancel();
                _searchController.clear();
                context.read<AurelController>().searchMusic('');
                _searchFocus.requestFocus();
              },
              icon: const Icon(
                Icons.close_rounded,
                color: AurelColors.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (controller.isSearching && controller.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AurelColors.champagne),
            ),
          )
        else if (controller.searchError != null &&
            controller.searchResults.isEmpty)
          _SearchMessage(
            controller.searchError!,
            action: 'Try again',
            onTap: _submit,
          )
        else if (hasQuery && controller.searchResults.isEmpty)
          const _SearchMessage(
            'No matches yet. Try another artist, title, or mood.',
          )
        else if (hasQuery) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Results for “${controller.searchQuery}”',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              if (controller.isSearching)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AurelColors.champagne,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          ...controller.searchResults.map(
            (track) => TrackTile(
              track: track,
              queue: controller.searchResults,
            ),
          ),
          if (controller.searchMoreError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                controller.searchMoreError!,
                style: const TextStyle(
                  color: Color(0xFFE6A0A0),
                  fontSize: 12,
                ),
              ),
            ),
          if (controller.hasMoreSearch)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: controller.isLoadingMoreSearch
                    ? null
                    : () => context
                        .read<AurelController>()
                        .loadMoreSearch(),
                icon: controller.isLoadingMoreSearch
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AurelColors.champagne,
                        ),
                      )
                    : const Icon(Icons.expand_more_rounded, size: 18),
                label: Text(
                  controller.isLoadingMoreSearch
                      ? 'Loading more results'
                      : 'Load more results',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AurelColors.champagne,
                  side: const BorderSide(color: AurelColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
        ] else ...[
          const Text(
            'Explore by sound',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              'Electronic',
              'Chill',
              'Ambient',
              'Jazz',
              'Indie',
              'Piano',
              'Hip Hop',
              'Acoustic',
            ].map((term) {
              return ActionChip(
                label: Text(term),
                onPressed: () => _searchTag(term),
                backgroundColor: AurelColors.surface,
                side: const BorderSide(color: AurelColors.divider),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const Text(
            'A little inspiration',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 9),
          ...controller.discoverTracks.take(5).map(
                (track) => TrackTile(
                  track: track,
                  queue: controller.discoverTracks,
                ),
              ),
        ],
      ],
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage(this.message, {this.action, this.onTap});

  final String message;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurelColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AurelColors.muted)),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ],
      ),
    );
  }
}
