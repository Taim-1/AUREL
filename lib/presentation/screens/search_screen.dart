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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await context.read<AurelController>().searchMusic(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AurelController>();
    final hasQuery = controller.searchQuery.isNotEmpty;

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
          'Songs, artists and sounds worth finding.',
          style: TextStyle(color: AurelColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'What do you want to hear?',
            prefixIcon: const Icon(Icons.search_rounded, color: AurelColors.champagne),
            suffixIcon: IconButton(
              onPressed: () {
                _searchController.clear();
                context.read<AurelController>().searchMusic('');
              },
              icon: const Icon(Icons.close_rounded, color: AurelColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (controller.isSearching)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AurelColors.champagne),
            ),
          )
        else if (controller.searchError != null)
          _SearchMessage(
            controller.searchError!,
            action: 'Try again',
            onTap: _submit,
          )
        else if (hasQuery && controller.searchResults.isEmpty)
          const _SearchMessage('No matches yet. Try another artist or title.')
        else if (hasQuery) ...[
          Text(
            'Results for “${controller.searchQuery}”',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 9),
          ...controller.searchResults.map(
            (track) => TrackTile(track: track, queue: controller.searchResults),
          ),
        ] else ...[
          const Text(
            'Popular searches',
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
                onPressed: () {
                  _searchController.text = term;
                  _submit();
                },
                backgroundColor: AurelColors.surface,
                side: const BorderSide(color: AurelColors.divider),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
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
                (track) => TrackTile(track: track, queue: controller.discoverTracks),
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
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
        ],
      ),
    );
  }
}
