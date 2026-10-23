import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../service_locator.dart';
import '../services/auth_service.dart';
import '../utils/url_utils.dart';

/// Widget voor het tonen van cover afbeeldingen
/// Gebruikt simpele fallback voor web en CachedNetworkImage voor mobiel.
/// Image-proxy URLs van de backend worden met het Authorization-token opgehaald.
class CoverImage extends StatefulWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;

  const CoverImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  late String _url;
  Future<String?>? _token;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    _url = normalizeImageUrl(widget.imageUrl) ?? widget.imageUrl;
    _token = isAuthenticatedImageUrl(_url) ? getIt<AuthService>().token : null;
  }

  double? get height => widget.height;
  double? get width => widget.width;

  @override
  Widget build(BuildContext context) {
    final token = _token;
    if (token == null) return _buildImage(context, null);

    // The proxy needs the token: never request it without the header.
    return FutureBuilder<String?>(
      future: token,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(context);
        }
        final value = snapshot.data;
        if (value == null || value.isEmpty) return _buildPlaceholder(context);
        return _buildImage(context, {'Authorization': 'Bearer $value'});
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, Map<String, String>? headers) {
    // Voor web: gebruik Image.network met fallback
    if (kIsWeb) {
      return Image.network(
        _url,
        headers: headers,
        height: height,
        width: width,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading(context);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context);
        },
      );
    }
    
    // Voor mobiel: gebruik CachedNetworkImage (betere performance)
    return CachedNetworkImage(
      imageUrl: _url,
      httpHeaders: headers,
      height: height,
      width: width,
      fit: widget.fit,
      placeholder: (context, url) => _buildLoading(context),
      errorWidget: (context, url, error) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: (height != null && height! < 80) ? 24 : 40,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          if (height == null || height! >= 80) ...[
            const SizedBox(height: 4),
            Text(
              'Geen\nafbeelding',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
