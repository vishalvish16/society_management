import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Max edge (px) before crop UI — smaller = faster crop + smaller uploads.
const int _kMaxCropImageEdge = 900;

/// Max edge (px) of JPEG sent to the server after crop (avatars / ID photos).
const int _kMaxUploadEdge = 640;

const int _kUploadJpegQuality = 75;

/// Runs in a [compute] isolate: resize very large photos before the crop widget loads.
Uint8List downscaleImageForProfileCrop(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final w = decoded.width;
    final h = decoded.height;
    if (w <= _kMaxCropImageEdge && h <= _kMaxCropImageEdge) return bytes;

    final smaller = w >= h
        ? img.copyResize(
            decoded,
            width: _kMaxCropImageEdge,
            interpolation: img.Interpolation.linear,
          )
        : img.copyResize(
            decoded,
            height: _kMaxCropImageEdge,
            interpolation: img.Interpolation.linear,
          );
    return Uint8List.fromList(
      img.encodeJpg(smaller, quality: 80, chroma: img.JpegChroma.yuv420),
    );
  } catch (_) {
    return bytes;
  }
}

/// Runs in a [compute] isolate: resize + JPEG so multipart uploads stay small and fast.
Uint8List compressAvatarUploadBytes(Uint8List bytes) {
  try {
    var src = img.decodeImage(bytes);
    if (src == null) return bytes;
    if (src.numChannels == 4) {
      src = src.convert(numChannels: 3);
    }
    final w = src.width;
    final h = src.height;
    img.Image out = src;
    if (w > _kMaxUploadEdge || h > _kMaxUploadEdge) {
      out = w >= h
          ? img.copyResize(
              src,
              width: _kMaxUploadEdge,
              interpolation: img.Interpolation.linear,
            )
          : img.copyResize(
              src,
              height: _kMaxUploadEdge,
              interpolation: img.Interpolation.linear,
            );
    }
    return Uint8List.fromList(
      img.encodeJpg(
        out,
        quality: _kUploadJpegQuality,
        chroma: img.JpegChroma.yuv420,
      ),
    );
  } catch (_) {
    return bytes;
  }
}

/// Rounded “card” panel (not a full-screen route) with square circular crop. Returns cropped bytes.
Future<Uint8List?> showProfilePhotoCrop(
  BuildContext context,
  Uint8List imageBytes,
) async {
  final prepared = await compute(downscaleImageForProfileCrop, imageBytes);
  if (!context.mounted) return null;

  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black45,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      final panelH = (h * 0.72).clamp(340.0, h * 0.88);
      final bottomPad = MediaQuery.paddingOf(ctx).bottom + 10;
      final scheme = Theme.of(ctx).colorScheme;

      return Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 12,
            shadowColor: Colors.black38,
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: panelH,
              child: _ProfilePhotoCropPanel(
                imageBytes: prepared,
                onDone: (bytes) => Navigator.of(ctx).pop(bytes),
                onCancel: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ProfilePhotoCropPanel extends StatefulWidget {
  const _ProfilePhotoCropPanel({
    required this.imageBytes,
    required this.onDone,
    required this.onCancel,
  });

  final Uint8List imageBytes;
  final void Function(Uint8List bytes) onDone;
  final VoidCallback onCancel;

  @override
  State<_ProfilePhotoCropPanel> createState() => _ProfilePhotoCropPanelState();
}

class _ProfilePhotoCropPanelState extends State<_ProfilePhotoCropPanel> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBg = scheme.onSurface;

    return PopScope(
      canPop: !_cropping,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: _cropping ? null : widget.onCancel,
                  icon: Icon(Icons.close_rounded, color: onBg),
                ),
                Expanded(
                  child: Text(
                    'Adjust photo',
                    style: AppTextStyles.h3.copyWith(color: onBg),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _cropping
                      ? null
                      : () {
                          setState(() => _cropping = true);
                          _controller.crop();
                        },
                  child: _cropping
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Text('Use', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Pinch to zoom, drag to move. Frame your face in the circle.',
              style: AppTextStyles.bodySmall.copyWith(
                color: onBg.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              child: Crop(
                image: widget.imageBytes,
                controller: _controller,
                aspectRatio: 1,
                withCircleUi: true,
                interactive: true,
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 0.78,
                  aspectRatio: 1,
                ),
                baseColor: scheme.surface,
                maskColor: scheme.scrim.withValues(alpha: 0.45),
                onCropped: (CropResult result) async {
                  if (!mounted) return;
                  if (result is CropSuccess) {
                    final optimized =
                        await compute(compressAvatarUploadBytes, result.croppedImage);
                    if (!mounted) return;
                    setState(() => _cropping = false);
                    widget.onDone(optimized);
                  } else if (result is CropFailure) {
                    setState(() => _cropping = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not crop: ${result.cause}'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
