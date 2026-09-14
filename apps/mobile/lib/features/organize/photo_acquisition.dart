import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/localization.dart';
import '../../core/state.dart';
import '../../design_system/widgets.dart';

typedef PhotoPicker = Future<XFile?> Function(ImageSource source);

/// Camera-first acquisition with an explicit review moment before processing.
class PhotoAcquisitionPage extends ConsumerStatefulWidget {
  const PhotoAcquisitionPage({
    super.key,
    required this.kind,
    this.onConfirm,
    this.picker,
  });

  final String kind;
  final Future<void> Function(XFile file)? onConfirm;
  final PhotoPicker? picker;

  @override
  ConsumerState<PhotoAcquisitionPage> createState() =>
      _PhotoAcquisitionPageState();
}

class _PhotoAcquisitionPageState extends ConsumerState<PhotoAcquisitionPage> {
  XFile? selected;
  Uint8List? bytes;
  bool opening = false, processing = false;
  String? error;

  Future<void> pick(ImageSource source) async {
    if (opening || processing) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      final file =
          await (widget.picker?.call(source) ??
              ImagePicker().pickImage(
                source: source,
                imageQuality: 85,
                maxWidth: 2048,
                maxHeight: 2048,
              ));
      if (file == null || !mounted) return;
      final data = await file.readAsBytes();
      if (mounted) {
        setState(() {
          selected = file;
          bytes = data;
        });
      }
    } on PlatformException catch (failure) {
      if (mounted) {
        setState(() {
          error = failure.code.toLowerCase().contains('denied')
              ? 'camera_permission_denied'
              : 'photo_unavailable';
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'photo_unavailable');
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> confirm() async {
    final file = selected;
    if (file == null || processing) return;
    if (widget.onConfirm == null) {
      Navigator.pop(context, file);
      return;
    }
    setState(() {
      processing = true;
      error = null;
    });
    try {
      await widget.onConfirm!(file);
      if (mounted) Navigator.pop(context);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.code);
    } catch (_) {
      if (mounted) setState(() => error = 'photo_unavailable');
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(appProvider).offline;
    const page = Color(0xff080d0b);
    const ink = Color(0xfff4f5f1);
    const muted = Color(0xffbdc7c0);
    const green = Color(0xff8fdfab);
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: green,
          onPrimary: Color(0xff0b2716),
          surface: page,
          onSurface: ink,
          onSurfaceVariant: muted,
        ),
      ),
      child: Scaffold(
        backgroundColor: page,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    EatMeIconButton(
                      glyph: EatMeGlyph.chevronLeft,
                      label: context.t('back'),
                      onPressed: processing
                          ? null
                          : () => Navigator.maybePop(context),
                      foregroundColor: ink,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                    ),
                    const Spacer(),
                    Text(
                      context.t('photo_acquisition'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Semantics(
                    image: true,
                    label: context.t(
                      bytes == null ? 'camera_frame' : 'photo_preview',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (bytes != null)
                            Image.memory(bytes!, fit: BoxFit.cover)
                          else
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xff26352d),
                                    Color(0xff101713),
                                  ],
                                ),
                              ),
                            ),
                          if (bytes == null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(42),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const EatMeIcon(
                                      EatMeGlyph.camera,
                                      color: green,
                                      size: 42,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      context.t('frame_your_food'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(color: ink),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      context.t('frame_your_food_body'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const Positioned.fill(child: _FrameCorners()),
                          if (opening || processing)
                            ColoredBox(
                              color: page.withValues(alpha: .78),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 18),
                                    Text(
                                      context.t(
                                        processing
                                            ? 'processing_photo'
                                            : 'opening_camera',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff4a211f),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(context.t(error!), textAlign: TextAlign.center),
                  ),
                if (offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.t('photo_offline'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted),
                    ),
                  ),
                Text(
                  context.t(
                    bytes == null ? 'photo_capture_support' : 'review_photo',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 14),
                if (bytes == null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _CameraAction(
                        icon: EatMeGlyph.image,
                        label: context.t('gallery'),
                        onTap: offline ? null : () => pick(ImageSource.gallery),
                      ),
                      Semantics(
                        button: true,
                        label: context.t('take_photo'),
                        child: InkWell(
                          key: const Key('camera_shutter'),
                          customBorder: const CircleBorder(),
                          onTap: offline
                              ? null
                              : () => pick(ImageSource.camera),
                          child: Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ink, width: 3),
                            ),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: ink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 64),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: processing
                              ? null
                              : () => setState(() {
                                  selected = null;
                                  bytes = null;
                                  error = null;
                                }),
                          child: Text(context.t('retake')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: processing || offline ? null : confirm,
                          child: Text(context.t('use_photo')),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraAction extends StatelessWidget {
  const _CameraAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final EatMeGlyph icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    child: Column(
      children: [
        EatMeIconButton(
          glyph: icon,
          label: label,
          onPressed: onTap,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Colors.white.withValues(alpha: .1),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _FrameCorners extends StatelessWidget {
  const _FrameCorners();

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _FramePainter()));
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .86)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 24.0, length = 30.0;
    for (final point in [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      final left = point.dx < size.width / 2;
      final top = point.dy < size.height / 2;
      canvas.drawLine(point, point + Offset(left ? length : -length, 0), paint);
      canvas.drawLine(point, point + Offset(0, top ? length : -length), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
