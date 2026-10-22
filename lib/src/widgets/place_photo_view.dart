/// @docImport '../places_client_options.dart';
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_cancellation_token.dart';
import '../places_client.dart';
import 'photo_links.dart';
import 'places_design_scope.dart';
import 'places_photo_attribution.dart';
import 'places_strings.dart';

/// Builds a [PlacePhotoView] in place of its default look, for every state:
/// loading, loaded, and failed.
typedef PlacePhotoViewBuilder =
    Widget Function(BuildContext context, PlacePhotoViewData photo);

/// The state of a [PlacePhotoView], as a [PlacePhotoViewBuilder] receives it.
enum PlacePhotoStatus {
  /// The photo's address is being fetched from Google, or the image itself is
  /// downloading.
  loading,

  /// The image is ready; see [PlacePhotoViewData.image].
  loaded,

  /// Fetching or decoding the photo failed; see [PlacePhotoViewData.error].
  error,
}

/// What a [PlacePhotoViewBuilder] receives.
///
/// Return [defaultView] for any state you do not want to change.
@immutable
class PlacePhotoViewData {
  /// Creates the data a [PlacePhotoViewBuilder] receives.
  const PlacePhotoViewData({
    required this.status,
    required this.photo,
    required this.image,
    required this.error,
    required this.onRetry,
    required this.attribution,
    required this.defaultView,
    required this.strings,
  });

  /// Which state the photo is in.
  final PlacePhotoStatus status;

  /// The photo being shown, including its [PlacePhoto.authors] and
  /// [PlacePhoto.googleMapsUri].
  final PlacePhoto photo;

  /// The image, sized and fitted as the widget was asked, when [status] is
  /// [PlacePhotoStatus.loaded]; otherwise `null`.
  final Widget? image;

  /// Why the photo failed, when [status] is [PlacePhotoStatus.error].
  ///
  /// When the image download fails, it is kind [PlacesErrorKind.network] with
  /// the HTTP status in [PlacesException.statusCode] — a photo address can
  /// expire. Any other failure that is not a [PlacesException], such as an
  /// image that cannot be decoded, is kind [PlacesErrorKind.unknown] with its
  /// type in `metadata`.
  final PlacesException? error;

  /// Fetches the photo again. Call it from an event handler, such as a
  /// button's `onPressed`, not while building.
  final VoidCallback onRetry;

  /// The photo's attribution — the author names and the "View on Google
  /// Maps" link — or `null` when there is neither (see
  /// [PlacePhotoView.onOpenLink]).
  ///
  /// Google requires the author to be credited wherever the photo is shown,
  /// and the user to be able to open the photo on Google Maps — see the
  /// [Places API policies](https://developers.google.com/maps/documentation/places/web-service/policies).
  /// Place it beside or over [image]. The policies allow leaving the author
  /// names out only when space is limited, such as a thumbnail, and the user
  /// can open a larger version of the photo that carries the full attribution
  /// and the Google Maps link.
  final Widget? attribution;

  /// The package's own view for this state, to return unchanged or to wrap.
  final Widget defaultView;

  /// The widget's strings, such as [PlacesStrings.retryText] and
  /// [PlacesStrings.photoAttributionPrefix].
  final PlacesStrings strings;
}

/// Shows a [PlacePhoto] from a place result, with its required author
/// attribution.
///
/// ```dart
/// PlacePhotoView(
///   photo: place.photos.first,
///   apiKey: 'YOUR_API_KEY',
///   height: 200,
/// )
/// ```
///
/// The widget asks Google for the photo's address with
/// [PlacesClient.fetchPhotoMedia] when it is first built, then downloads the
/// image. Each fetch is a billed Place Photos request, so a list of photos
/// costs one request per photo shown. It fetches again when [photo], the
/// client, or the requested size changes, and cancels a fetch still running
/// when it is disposed. Nothing is cached by the package: Google does not
/// allow photo names to be cached, and they can expire.
///
/// Photos only arrive when the place was fetched with [PlaceField.photos],
/// which the default `address` fields do not include.
///
/// The image is then downloaded by Flutter's image loader straight from the
/// address Google returned, so that request does not go through a
/// [PlacesClient.proxy] client's proxy, even when the address came through it.
///
/// On web, the photo's address is always a REST request: the Maps JavaScript
/// library has no equivalent. It therefore follows
/// [PlacesWebOptions.fallbackPolicy] — with the default, a key given to
/// [apiKey] is sent from the browser; with
/// [PlacesWebFallbackPolicy.proxyOnly] it needs a [client] with a proxy, or
/// every photo fails with a [PlacesErrorKind.configuration] error. The image
/// download needs the image host to allow cross-origin requests, which
/// Google's does.
///
/// By default the attribution is drawn over the bottom of the image: the
/// author names, and a "View on Google Maps" link to the photo, which Google
/// requires users to be able to open. Pass [onOpenLink] so the link works on
/// every platform. Use [builder] to change any state's look or to place the
/// attribution yourself; there is no option to hide it.
class PlacePhotoView extends StatefulWidget {
  /// Creates a widget that shows [photo].
  ///
  /// Pass exactly one of [client] and [apiKey].
  const PlacePhotoView({
    super.key,
    required this.photo,
    this.client,
    this.apiKey,
    this.width,
    this.height,
    this.maxWidthPx,
    this.maxHeightPx,
    this.fit = BoxFit.cover,
    this.builder,
    this.strings = const PlacesStrings(),
    this.onOpenLink,
  }) : assert(
         (client == null) != (apiKey == null),
         'Pass exactly one of client or apiKey.',
       ),
       assert(
         width == null || (width > 0 && width < double.infinity),
         'width must be positive and finite.',
       ),
       assert(
         height == null || (height > 0 && height < double.infinity),
         'height must be positive and finite.',
       ),
       assert(
         maxWidthPx == null || (maxWidthPx >= 1 && maxWidthPx <= 4800),
         'maxWidthPx must be between 1 and 4800.',
       ),
       assert(
         maxHeightPx == null || (maxHeightPx >= 1 && maxHeightPx <= 4800),
         'maxHeightPx must be between 1 and 4800.',
       );

  /// The photo to show, from [PlaceData.photos].
  final PlacePhoto photo;

  /// Client used to fetch the photo's address.
  ///
  /// The caller owns it: the widget never closes a client it was given.
  final PlacesClient? client;

  /// Google Maps Platform API key, for when the widget should manage its own
  /// client.
  ///
  /// The widget creates `PlacesClient(apiKey: apiKey)` with default
  /// [PlacesClientOptions], closes it when disposed, and replaces it if the key
  /// changes. A key restricted to your Android or iOS app needs
  /// [PlacesClientOptions.applicationIdentity]: pass a [client] built with it.
  /// On web the key is sent from the browser in a REST request; to keep it
  /// off the device, pass a [client] made with [PlacesClient.proxy].
  final String? apiKey;

  /// Width of the image in logical pixels.
  ///
  /// Also sets the size requested from Google: [width] times the device pixel
  /// ratio, capped at Google's 4800 pixels. Changing it fetches the photo
  /// again, so do not tie it to a size that changes as a window resizes.
  final double? width;

  /// Height of the image in logical pixels, requested from Google the same way
  /// as [width].
  final double? height;

  /// The maximum width, in physical pixels, to request from Google, from 1 to
  /// 4800. When this or [maxHeightPx] is set, the two replace the size worked
  /// out from [width] and [height]; one left `null` is not requested.
  ///
  /// With no size at all, the widget asks for the photo at its original size,
  /// up to 4800 pixels wide — pass [width] or [height] so a thumbnail does not
  /// download a full-size photo.
  final int? maxWidthPx;

  /// The maximum height, in physical pixels, to request from Google; see
  /// [maxWidthPx].
  final int? maxHeightPx;

  /// How the image fills [width] and [height]. Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Builds the widget for each state in place of the default look.
  ///
  /// It receives the image, the error, a retry callback, the author
  /// attribution, and the package's [PlacePhotoViewData.defaultView].
  final PlacePhotoViewBuilder? builder;

  /// The widget's strings: [PlacesStrings.photoAttributionPrefix] and
  /// [PlacesStrings.viewOnGoogleMapsText] for the attribution, and
  /// [PlacesStrings.retryText] for the retry button.
  final PlacesStrings strings;

  /// Opens a link the user taps in the attribution: the photo on Google Maps,
  /// or an author's Google Maps profile.
  ///
  /// The package cannot open a link itself on Android, iOS, macOS, Windows or
  /// Linux, since that needs a plugin, so pass this — for example
  /// `onOpenLink: (uri) => launchUrl(uri)`, with `url_launcher` in your app.
  /// It receives only `https` and `http` links.
  ///
  /// When it is `null`: on web, a link opens in a new browser tab; on other
  /// platforms, no link is shown — the author names are plain text — and a
  /// debug notice is printed once per app run.
  final ValueChanged<Uri>? onOpenLink;

  @override
  State<PlacePhotoView> createState() => _PlacePhotoViewState();
}

// Google's limit on a requested photo dimension.
const int _maxPhotoPx = 4800;

class _PlacePhotoViewState extends State<PlacePhotoView> {
  PlacesClient? _ownedClient;
  PlacesCancellationToken? _cancellationToken;
  int _generation = 0;
  ({int? width, int? height})? _requestedPx;
  String? _photoUri;
  PlacesException? _error;

  PlacesClient get _client => widget.client ?? _ownedClient!;

  void _createOwnedClient() {
    _ownedClient = widget.client == null
        ? PlacesClient(apiKey: widget.apiKey!)
        : null;
  }

  @override
  void initState() {
    super.initState();
    _createOwnedClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The device pixel ratio is read here, so a change to it is seen too.
    final requested = _requestedSize();
    if (requested != _requestedPx) {
      unawaited(_load(requested));
    }
  }

  @override
  void didUpdateWidget(PlacePhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clientChanged =
        oldWidget.client != widget.client || oldWidget.apiKey != widget.apiKey;
    final retiredClient = clientChanged ? _ownedClient : null;
    if (clientChanged) {
      _createOwnedClient();
    }
    final requested = _requestedSize();
    if (clientChanged ||
        oldWidget.photo.name != widget.photo.name ||
        requested != _requestedPx) {
      unawaited(_load(requested));
    }
    // After the fetch it served has been cancelled, so its failure is
    // discarded as stale rather than shown.
    unawaited(retiredClient?.close());
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    unawaited(_ownedClient?.close());
    super.dispose();
  }

  ({int? width, int? height}) _requestedSize() {
    final widget = this.widget;
    if (widget.maxWidthPx != null || widget.maxHeightPx != null) {
      return (width: widget.maxWidthPx, height: widget.maxHeightPx);
    }
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    int? physical(double? logical) =>
        logical == null ? null : (logical * ratio).ceil().clamp(1, _maxPhotoPx);
    if (widget.width != null || widget.height != null) {
      return (width: physical(widget.width), height: physical(widget.height));
    }
    // Google returns the original when it is smaller than the request.
    return (
      width: (widget.photo.widthPx ?? _maxPhotoPx).clamp(1, _maxPhotoPx),
      height: null,
    );
  }

  // Called before build (from didChangeDependencies and didUpdateWidget), or
  // inside setState from a retry, so the reset state needs no setState here.
  Future<void> _load(({int? width, int? height}) requested) async {
    _requestedPx = requested;
    _cancellationToken?.cancel();
    final cancellationToken = _cancellationToken = PlacesCancellationToken();
    final generation = ++_generation;
    _photoUri = null;
    _error = null;
    try {
      // Future.sync: a synchronous throw must still arrive after this frame's
      // build, where setState is allowed.
      final media = await Future<PlacePhotoMedia>.sync(
        () => _client.fetchPhotoMedia(
          PhotoMediaRequest(
            name: widget.photo.name,
            maxWidthPx: requested.width,
            maxHeightPx: requested.height,
          ),
          cancellationToken: cancellationToken,
        ),
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        if (media.photoUri.isEmpty) {
          _error = const PlacesException(
            'Google returned no photo URI.',
            kind: PlacesErrorKind.googleApi,
            operation: PlacesOperation.photoMedia,
            code: 'missing_photo_uri',
          );
        } else {
          _photoUri = media.photoUri;
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _error = _wrap(error));
    } finally {
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
      }
    }
  }

  void _retry() {
    // On web a failed image download stays in the image cache, so without
    // this a retry would get the same failure back without downloading again.
    final photoUri = _photoUri;
    if (photoUri != null) {
      imageCache.evict(NetworkImage(photoUri));
    }
    setState(() {
      unawaited(_load(_requestedSize()));
    });
  }

  static PlacesException _wrap(Object error) => switch (error) {
    PlacesException() => error,
    // An expired or refused photo address, told apart from a bad image.
    NetworkImageLoadException(:final statusCode) => PlacesException(
      'The place photo failed to download.',
      kind: PlacesErrorKind.network,
      statusCode: statusCode,
      retryable: true,
      operation: PlacesOperation.photoMedia,
    ),
    _ => PlacesException(
      'The place photo failed to load.',
      operation: PlacesOperation.photoMedia,
      metadata: <String, Object?>{'errorType': error.runtimeType.toString()},
    ),
  };

  @override
  Widget build(BuildContext context) {
    // The default loading and retry views are material_ui widgets.
    return PlacesDesignScope(child: Builder(builder: _buildContent));
  }

  Widget _buildContent(BuildContext context) {
    final photoUri = _photoUri;
    if (_error != null || photoUri == null) {
      return _view(
        context,
        _error == null ? PlacePhotoStatus.loading : PlacePhotoStatus.error,
      );
    }
    return Image.network(
      photoUri,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      frameBuilder: (context, image, frame, wasSynchronouslyLoaded) =>
          frame == null
          ? _view(context, PlacePhotoStatus.loading)
          : _view(context, PlacePhotoStatus.loaded, image: image),
      errorBuilder: (context, error, stackTrace) =>
          _view(context, PlacePhotoStatus.error, error: _wrap(error)),
    );
  }

  Widget _view(
    BuildContext context,
    PlacePhotoStatus status, {
    Widget? image,
    PlacesException? error,
  }) {
    final hasAttribution = photoHasAttribution(
      widget.photo,
      photoLinkOpener(widget.onOpenLink, widget.photo),
    );
    final defaultView = switch (status) {
      PlacePhotoStatus.loading => _placeholder(
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      ),
      PlacePhotoStatus.error => _placeholder(
        TextButton(onPressed: _retry, child: Text(widget.strings.retryText)),
      ),
      // Passthrough, so a tight box — a PageView page, a grid tile — sizes
      // the image itself and the band stays on it.
      PlacePhotoStatus.loaded => Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          image!,
          if (hasAttribution)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // A dark band keeps the white text legible on any photo.
              child: ColoredBox(
                color: const Color(0x8A000000),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: PlacesPhotoAttribution(
                    photo: widget.photo,
                    strings: widget.strings,
                    onOpenLink: widget.onOpenLink,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    };
    final builder = widget.builder;
    if (builder == null) {
      return defaultView;
    }
    return builder(
      context,
      PlacePhotoViewData(
        status: status,
        photo: widget.photo,
        image: image,
        error: error ?? _error,
        onRetry: _retry,
        attribution: hasAttribution
            ? PlacesPhotoAttribution(
                photo: widget.photo,
                strings: widget.strings,
                onOpenLink: widget.onOpenLink,
              )
            : null,
        defaultView: defaultView,
        strings: widget.strings,
      ),
    );
  }

  Widget _placeholder(Widget child) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: Center(child: child),
  );
}
