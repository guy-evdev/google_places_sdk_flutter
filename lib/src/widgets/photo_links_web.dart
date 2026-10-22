import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// In the browser, a link opens in a new tab.
const ValueChanged<Uri> platformOpenLink = _openInNewTab;

void _openInNewTab(Uri uri) =>
    web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
