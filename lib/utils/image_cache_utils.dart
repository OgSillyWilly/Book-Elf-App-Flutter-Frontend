import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Evicts every cached cover so the next user never sees the previous
/// user's images (CachedNetworkImage keys its cache on the URL only).
Future<void> clearImageCaches() async {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();

  if (kIsWeb) return;
  try {
    await DefaultCacheManager().emptyCache();
  } catch (_) {
    // Best effort: a cache failure must not block logging out.
  }
}
