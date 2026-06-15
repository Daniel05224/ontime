import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'animations.dart';

/// Full-screen pan/zoom avatar editor, WhatsApp-style.
/// Returns cropped [Uint8List] via [onConfirm], null via [onCancel].
class AvatarCropView extends StatefulWidget {
  const AvatarCropView({
    super.key,
    required this.imageBytes,
    required this.onConfirm,
    required this.onCancel,
  });

  final Uint8List imageBytes;
  final void Function(Uint8List) onConfirm;
  final VoidCallback onCancel;

  @override
  State<AvatarCropView> createState() => _AvatarCropViewState();
}

class _AvatarCropViewState extends State<AvatarCropView>
    with SingleTickerProviderStateMixin {
  final _cropKey = GlobalKey();

  // Current transform
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Gesture base state
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _gestureStart = Offset.zero;

  bool _confirming = false;
  bool _fitted = false;

  ui.Image? _uiImage;

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _uiImage = frame.image);
  }

  // Called on first build after image decoded — needs real layout size.
  void _fitIfNeeded(double cropDiameter) {
    if (_fitted || _uiImage == null) return;
    _fitted = true;
    final imgW = _uiImage!.width.toDouble();
    final imgH = _uiImage!.height.toDouble();
    // Cover: scale so the image fills the crop circle
    _scale = math.max(cropDiameter / imgW, cropDiameter / imgH);
    _offset = Offset.zero;
    _enterCtrl.forward();
  }

  double _cropDiameter(Size size) => size.width * 0.80;

  void _onScaleStart(ScaleStartDetails d) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _gestureStart = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double cropDiameter) {
    final img = _uiImage;
    if (img == null) return;

    final minScale = math.max(
      cropDiameter / img.width.toDouble(),
      cropDiameter / img.height.toDouble(),
    );
    final newScale = (_baseScale * d.scale).clamp(minScale, 6.0);

    // Pan delta
    final panDelta = d.localFocalPoint - _gestureStart;
    final newOffset = _clampOffset(
      _baseOffset + panDelta,
      newScale,
      cropDiameter,
      img,
    );

    setState(() {
      _scale = newScale;
      _offset = newOffset;
    });
  }

  Offset _clampOffset(
      Offset o, double scale, double cropDiameter, ui.Image img) {
    final half = cropDiameter / 2;
    final halfW = img.width * scale / 2;
    final halfH = img.height * scale / 2;
    return Offset(
      o.dx.clamp(half - halfW, halfW - half),
      o.dy.clamp(half - halfH, halfH - half),
    );
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    HapticFeedback.mediumImpact();
    try {
      final boundary =
          _cropKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      if (mounted) widget.onConfirm(bytes);
    } catch (_) {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cropD = _cropDiameter(size);
    final img = _uiImage;

    // Fit on first frame that has both image and real size
    if (img != null && !_fitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fitIfNeeded(cropD));
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Overlay + GestureDetector ────────────────────────────────────
            GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: (d) => _onScaleUpdate(d, cropD),
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
              painter: _OverlayPainter(diameter: cropD),
              child: Center(
                child: RepaintBoundary(
                  key: _cropKey,
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: cropD,
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Center(
                          child: Transform.translate(
                            offset: _offset,
                            child: Transform.scale(
                              scale: _scale,
                              child: img != null
                                  ? Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.none,
                                      width: img.width.toDouble(),
                                      height: img.height.toDouble(),
                                      gaplessPlayback: true,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ), // CustomPaint
            ), // GestureDetector

            // Loading spinner (while decoding)
            if (img == null)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
                  ),
                ),
              ),

            // ── Top bar: X ───────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: FadeTransition(
                  opacity: _enterCtrl,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CircleBtn(
                        icon: Icons.close_rounded,
                        onTap: widget.onCancel,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom bar: Cancelar + Usar foto ─────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: FadeTransition(
                  opacity: _enterCtrl,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: PressableScale(
                            onTap: widget.onCancel,
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: PressableScale(
                            onTap: _confirming ? null : _confirm,
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: _confirming
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Usar foto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay painter ───────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.diameter});
  final double diameter;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = diameter / 2;

    // Semi-transparent black with circular hole
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black, // fully opaque outside circle
    );

    // White ring border
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.diameter != diameter;
}

// ── Small icon button ─────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
