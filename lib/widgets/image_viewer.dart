import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Full-screen viewer for one or multiple remote or binary images.
///
/// Proof photos are attachments recorded against an activity, so the card that
/// lists them only has a filename-sized thumbnail to spend on it. Opening the
/// full image in a separate route is what makes the photo actually checkable -
/// a proof of attendance is only useful if the chapter admin can see it.
///
/// Uses a barrier-less [PageRouteBuilder] so the viewer can paint edge to edge
/// behind the status bar.
class ImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String? caption;

  /// Single image constructor for backward compatibility.
  ImageViewer({super.key, required String url, this.caption})
      : urls = [url],
        initialIndex = 0;

  /// Gallery constructor for multiple images.
  const ImageViewer.gallery({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.caption,
  });

  /// Opens the viewer over [context].
  /// [urlOrUrls] can be a single [String] URL, a JSON array string,
  /// a comma-separated string, or a [List<String>] / [List<dynamic>].
  static Future<void> show(
    BuildContext context,
    dynamic urlOrUrls, {
    int initialIndex = 0,
    String? caption,
  }) {
    List<String> list = [];
    if (urlOrUrls is List<String>) {
      list = urlOrUrls;
    } else if (urlOrUrls is List) {
      list = extractImageUrls(urlOrUrls);
    } else if (urlOrUrls is String) {
      list = extractImageUrls(urlOrUrls);
      if (list.isEmpty) {
        final r = resolveUrl(urlOrUrls);
        if (r.isNotEmpty) list = [r];
      }
    }

    if (list.isEmpty) return Future.value();

    final safeIndex =
        (initialIndex >= 0 && initialIndex < list.length) ? initialIndex : 0;

    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ImageViewer.gallery(
          urls: list,
          initialIndex: safeIndex,
          caption: caption,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  /// Checks whether a given string represents binary/base64-encoded image data.
  static bool isBase64Image(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    // Data URI pattern: data:image/...;base64,...
    if (s.toLowerCase().startsWith('data:image/')) return true;
    // Fast check: HTTP/HTTPS or obvious server paths are not raw base64
    if (s.startsWith('http://') || s.startsWith('https://')) return false;
    // Common image binary signatures encoded in base64:
    // /9j/ = JPEG, iVBORw0KGgo = PNG, R0lGOD = GIF, UklGR = WebP, Qk0 = BMP
    if (s.startsWith('/9j/') ||
        s.startsWith('iVBORw') ||
        s.startsWith('R0lGOD') ||
        s.startsWith('UklGR') ||
        s.startsWith('Qk0')) {
      return true;
    }
    // Check if it's a long base64 payload without URL slashes or spaces
    if (s.length >= 64 &&
        !s.contains(' ') &&
        !s.endsWith('.jpg') &&
        !s.endsWith('.jpeg') &&
        !s.endsWith('.png') &&
        !s.endsWith('.webp') &&
        !s.endsWith('.gif')) {
      final sanitized = s.replaceAll(RegExp(r'[\r\n]'), '');
      if (RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(sanitized)) {
        return true;
      }
    }
    return false;
  }

  /// Decodes base64/binary image data into [Uint8List] bytes.
  static Uint8List? decodeBase64Image(String raw) {
    try {
      String s = raw.trim();
      if (s.isEmpty) return null;
      if (s.contains(',')) {
        // e.g. data:image/png;base64,xxxx
        s = s.substring(s.indexOf(',') + 1).trim();
      }
      s = s.replaceAll(RegExp(r'\s+'), '');
      final remainder = s.length % 4;
      if (remainder != 0) {
        s = s.padRight(s.length + (4 - remainder), '=');
      }
      final bytes = base64Decode(s);
      if (bytes.isNotEmpty) return bytes;
    } catch (e) {
      debugPrint('Failed to decode base64 image: $e');
    }
    return null;
  }

  /// Displays an image from either a binary/base64 string, data URI, or network URL.
  /// Converts binary/base64 data into [Image.memory] and loads URLs with [Image.network].
  static Widget buildImageWidget(
    String imageSource, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    VoidCallback? onTap,
  }) {
    final raw = imageSource.trim();
    if (raw.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    Widget content;
    final isB64 = isBase64Image(raw);
    if (isB64) {
      final bytes = decodeBase64Image(raw);
      if (bytes != null) {
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) =>
              errorWidget ??
              _buildDefaultError(width, height, 'Corrupted binary image'),
        );
      } else {
        content = errorWidget ??
            _buildDefaultError(width, height, 'Invalid binary data');
      }
    } else {
      final resolved = resolveUrl(raw);
      if (resolved.isEmpty) {
        content = errorWidget ??
            _buildDefaultError(width, height, 'Empty image URL');
      } else {
        content = Image.network(
          resolved,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder ??
                Container(
                  width: width,
                  height: height,
                  color: Colors.black12,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
          },
          errorBuilder: (_, __, ___) =>
              errorWidget ??
              _buildDefaultError(width, height, 'Unable to load image'),
        );
      }
    }

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: content,
      );
    }

    return content;
  }

  static Widget _buildDefaultError(double? w, double? h, String label) {
    return Container(
      width: w,
      height: h,
      color: Colors.black12,
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.grey, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Turns whatever the API stored in the image column into something
  /// [Image.network] can load, while leaving binary/base64 untouched.
  static String resolveUrl(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return '';

    // Strip surrounding quotes if present: "url" or 'url'
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      if (value.length >= 2) {
        value = value.substring(1, value.length - 1).trim();
      }
    }

    // Unescape JSON escaped forward slashes: "\/" -> "/"
    value = value.replaceAll(r'\/', '/');
    // Normalize Windows backslashes: "\" -> "/"
    value = value.replaceAll(r'\', '/');

    if (value.isEmpty ||
        value.toLowerCase() == 'null' ||
        value.toLowerCase() == 'none' ||
        value.toLowerCase() == 'undefined') {
      return '';
    }

    // Do NOT prepend origin to binary / base64 image strings or data URIs
    if (isBase64Image(value) || value.startsWith('data:image/')) {
      return value;
    }

    // Protocol-relative URLs: "//example.com/path" -> "https://example.com/path"
    if (value.startsWith('//')) {
      value = 'https:$value';
    }

    // Absolute URLs
    if (value.startsWith('http://') || value.startsWith('https://')) {
      if (value.startsWith('http://rmbconnect.in')) {
        value = 'https://${value.substring(7)}';
      }
      return _encodeUrlSafely(value);
    }

    const origin = 'https://rmbconnect.in';

    // Clean up duplicate uploads/ prefix if present
    String path = value;
    if (path.startsWith('/uploads/uploads/')) {
      path = path.substring(8);
    } else if (path.startsWith('uploads/uploads/')) {
      path = path.substring(8);
    }

    String fullUrl;
    if (path.startsWith('/')) {
      fullUrl = '$origin$path';
    } else if (path.startsWith('uploads/') ||
        path.startsWith('assets/') ||
        path.startsWith('images/') ||
        path.startsWith('files/') ||
        path.startsWith('storage/') ||
        path.startsWith('api/') ||
        path.startsWith('api_flutter/')) {
      fullUrl = '$origin/$path';
    } else {
      fullUrl = '$origin/uploads/$path';
    }

    return _encodeUrlSafely(fullUrl);
  }

  static String _encodeUrlSafely(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && !url.contains(' ')) {
        return uri.toString();
      }
      return Uri.encodeFull(url);
    } catch (_) {
      return Uri.encodeFull(url);
    }
  }

  /// Extracts all valid, resolved image URLs or binary/base64 strings from raw data.
  /// Handles single URLs, binary strings, JSON arrays, comma/semicolon-separated lists, and Maps.
  static List<String> extractImageUrls(dynamic raw) {
    if (raw == null) return const [];
    final List<String> results = [];

    void addResolved(String s) {
      if (isBase64Image(s)) {
        if (!results.contains(s)) results.add(s);
        return;
      }
      final resolved = resolveUrl(s);
      if (resolved.isNotEmpty && !results.contains(resolved)) {
        results.add(resolved);
      }
    }

    void process(dynamic item) {
      if (item == null) return;
      if (item is Uint8List) {
        final b64 = base64Encode(item);
        if (!results.contains(b64)) results.add(b64);
        return;
      }
      if (item is List<int>) {
        final b64 = base64Encode(item);
        if (!results.contains(b64)) results.add(b64);
        return;
      }
      if (item is List) {
        // If it's a list of byte integers:
        if (item.isNotEmpty && item.first is int) {
          try {
            final ints = List<int>.from(item);
            final b64 = base64Encode(ints);
            if (!results.contains(b64)) results.add(b64);
            return;
          } catch (_) {}
        }
        for (final element in item) {
          process(element);
        }
      } else if (item is Map) {
        const imageKeys = [
          'url',
          'image',
          'proof_image',
          'image_url',
          'proof_url',
          'image_path',
          'meeting_image',
          'photo',
          'proof',
          'attachment',
          'file',
          'path',
          'src',
          'image_base64',
          'base64_image',
          'image_binary',
          'image_data',
          'proof_base64',
          'meeting_photo'
        ];
        for (final key in imageKeys) {
          if (item.containsKey(key)) {
            process(item[key]);
          }
        }
      } else if (item is String) {
        String str = item.trim();
        if (str.isEmpty ||
            str.toLowerCase() == 'null' ||
            str.toLowerCase() == 'none' ||
            str.toLowerCase() == 'undefined') {
          return;
        }

        // Check if string is base64 image or data URI
        if (isBase64Image(str)) {
          if (!results.contains(str)) {
            results.add(str);
          }
          return;
        }

        // Check if string is a JSON array or object
        if ((str.startsWith('[') && str.endsWith(']')) ||
            (str.startsWith('{') && str.endsWith('}'))) {
          try {
            final decoded = jsonDecode(str);
            if (decoded is List && decoded.isNotEmpty && decoded.first is int) {
              final b64 = base64Encode(List<int>.from(decoded));
              if (!results.contains(b64)) results.add(b64);
              return;
            }
            process(decoded);
            return;
          } catch (_) {}
        }

        // Check if string is comma-separated or semicolon-separated list of URLs
        if (str.contains(',') || str.contains(';')) {
          final parts = str.split(RegExp(r'[,;]'));
          bool looksLikeList = parts.any((p) {
            final lower = p.trim().toLowerCase();
            return lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png') ||
                lower.endsWith('.webp') ||
                lower.endsWith('.gif') ||
                lower.startsWith('http://') ||
                lower.startsWith('https://') ||
                lower.startsWith('uploads/');
          });
          if (looksLikeList) {
            for (final part in parts) {
              process(part.trim());
            }
            return;
          }
        }

        addResolved(str);
      }
    }

    process(raw);
    return results;
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, int> _retryCounts = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = (widget.initialIndex >= 0 &&
            widget.initialIndex < widget.urls.length)
        ? widget.initialIndex
        : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index >= 0 && index < widget.urls.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final total = urls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background tap to close
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox.expand(),
            ),
          ),

          if (total == 0)
            const Center(
              child: Text(
                'No image attached',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            )
          else
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: total,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  final raw = urls[index];
                  final isB64 = ImageViewer.isBase64Image(raw);
                  final bytes = isB64 ? ImageViewer.decodeBase64Image(raw) : null;
                  final retryKey = _retryCounts[index] ?? 0;

                  Widget imageChild;
                  if (bytes != null) {
                    imageChild = Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, __) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.broken_image_outlined,
                                  color: Colors.white54, size: 56),
                              SizedBox(height: 16),
                              Text(
                                'Binary image could not be loaded',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    final resolved = ImageViewer.resolveUrl(raw);
                    imageChild = Image.network(
                      resolved,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading image...',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      errorBuilder: (context, _, __) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_outlined,
                                  color: Colors.white54, size: 56),
                              SizedBox(height: 16),
                              const Text(
                                'Image could not be loaded',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                resolved,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                onPressed: () {
                                  PaintingBinding.instance.imageCache
                                      .evict(NetworkImage(resolved));
                                  setState(() {
                                    _retryCounts[index] =
                                        (_retryCounts[index] ?? 0) + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return KeyedSubtree(
                    key: ValueKey('${raw.hashCode}-$retryKey'),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(child: imageChild),
                    ),
                  );
                },
              ),
            ),

          // Previous / Next arrow buttons if multiple
          if (total > 1 && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _goTo(_currentIndex - 1),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.chevron_left,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          if (total > 1 && _currentIndex < total - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _goTo(_currentIndex + 1),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.chevron_right,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),

          // Top bar: Page indicator + Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (total > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Caption and bottom page dots
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (total > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (i) {
                        final active = i == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
                if (widget.caption != null && widget.caption!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      widget.caption!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

