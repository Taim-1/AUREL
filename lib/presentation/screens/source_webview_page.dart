import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/aurel_theme.dart';

class SourceWebViewPage extends StatefulWidget {
  const SourceWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<SourceWebViewPage> createState() => _SourceWebViewPageState();
}

class _SourceWebViewPageState extends State<SourceWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _failed = true;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AurelColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null || target.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurelColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Reload source page',
            onPressed: _failed ? null : () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: _progress < 100 && !_failed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  color: AurelColors.champagne,
                  backgroundColor: AurelColors.surface,
                ),
              )
            : null,
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_off_rounded,
                      color: AurelColors.champagne,
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This source page is unavailable.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'The track can still be played here when its provider permits it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AurelColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to AUREL'),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
