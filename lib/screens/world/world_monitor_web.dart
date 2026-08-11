import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class WorldMonitorWeb extends StatefulWidget {
  const WorldMonitorWeb({super.key});

  @override
  State<WorldMonitorWeb> createState() => _WorldMonitorWebState();
}

class _WorldMonitorWebState extends State<WorldMonitorWeb> {
  final String viewType = 'world-monitor-iframe';

  @override
  void initState() {
    super.initState();
    // Register the IFrame element for Flutter Web
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement();
      iframe.src = 'https://worldmonitor.app/dashboard';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewType);
  }
}
