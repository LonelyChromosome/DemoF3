import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Local presentation only. Card UIDs and updater data never enter this view.
class CardLinkVfx extends StatefulWidget {
  const CardLinkVfx({
    required this.displayName,
    required this.status,
    required this.onComplete,
    this.deleting = false,
    this.onDeleteRequested,
    super.key,
  });

  final String displayName;
  final String status;
  final bool deleting;
  final VoidCallback onComplete;
  final Future<bool> Function()? onDeleteRequested;

  @override
  State<CardLinkVfx> createState() => _CardLinkVfxState();
}

class _CardLinkVfxState extends State<CardLinkVfx> {
  late final Future<String> _html = rootBundle.loadString(
    'assets/card_vfx/${widget.deleting ? 'unlink' : 'link'}.html',
  );
  InAppWebViewController? _web;
  bool _ready = false;

  Future<void> _present() async {
    if (!_ready || !mounted) return;
    await _web?.evaluateJavascript(
      source: 'window.paSetState(${jsonEncode(widget.status)},'
          '${jsonEncode(widget.displayName)});',
    );
  }

  @override
  void didUpdateWidget(covariant CardLinkVfx oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.displayName != widget.displayName) {
      _present();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 480,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: FutureBuilder<String>(
        future: _html,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: Color(0xFF050913));
          }
          return InAppWebView(
            initialData: InAppWebViewInitialData(data: snapshot.data!),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: false,
              underPageBackgroundColor: const Color(0xFF050913),
              forceDark: ForceDark.OFF,
              algorithmicDarkeningAllowed: false,
              hardwareAcceleration: true,
              useHybridComposition: true,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
            ),
            onWebViewCreated: (controller) {
              _web = controller;
              controller.addJavaScriptHandler(
                handlerName: 'vfxComplete',
                callback: (_) {
                  if (mounted) widget.onComplete();
                  return null;
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'deleteCard',
                callback: (_) async {
                  if (!mounted || widget.onDeleteRequested == null) return false;
                  return widget.onDeleteRequested!();
                },
              );
            },
            onLoadStop: (_, _) async {
              _ready = true;
              await _present();
            },
          );
        },
      ),
    ),
  );
}
