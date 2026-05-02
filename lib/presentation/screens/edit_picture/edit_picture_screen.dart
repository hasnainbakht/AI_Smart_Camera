// import 'dart:async';
// import 'dart:io';
// import 'dart:isolate';
// import 'dart:math' as math;
// import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image/image.dart' as img;
// import 'package:path_provider/path_provider.dart';
// import 'package:saver_gallery/saver_gallery.dart';
// // ---------------------------------------------------------------------------
// // SECTION 1 — DATA MODELS
// // ---------------------------------------------------------------------------

// /// Immutable snapshot of every edit parameter at a point in history.
// class EditState {
//   final double brightness;   // –1.0 … +1.0   (0 = neutral)
//   final double contrast;     //  0.0 … 3.0    (1 = neutral)
//   final double saturation;   //  0.0 … 3.0    (1 = neutral)
//   final double exposure;     // –2.0 … +2.0   (0 = neutral, EV stops)
//   final double rotation;     // radians
//   final double scale;        // zoom factor
//   final Offset offset;       // pan offset in logical pixels
//   final ColorGradePreset preset;
//   final bool backgroundRemoved;

//   const EditState({
//     this.brightness = 0,
//     this.contrast = 1,
//     this.saturation = 1,
//     this.exposure = 0,
//     this.rotation = 0,
//     this.scale = 1,
//     this.offset = Offset.zero,
//     this.preset = ColorGradePreset.normal,
//     this.backgroundRemoved = false,
//   });

//   EditState copyWith({
//     double? brightness,
//     double? contrast,
//     double? saturation,
//     double? exposure,
//     double? rotation,
//     double? scale,
//     Offset? offset,
//     ColorGradePreset? preset,
//     bool? backgroundRemoved,
//   }) =>
//       EditState(
//         brightness: brightness ?? this.brightness,
//         contrast: contrast ?? this.contrast,
//         saturation: saturation ?? this.saturation,
//         exposure: exposure ?? this.exposure,
//         rotation: rotation ?? this.rotation,
//         scale: scale ?? this.scale,
//         offset: offset ?? this.offset,
//         preset: preset ?? this.preset,
//         backgroundRemoved: backgroundRemoved ?? this.backgroundRemoved,
//       );
// }

// enum ColorGradePreset { normal, warm, cool, vintage, highContrast, bw }

// // ---------------------------------------------------------------------------
// // SECTION 2 — IMAGE PROCESSING ENGINE  (pure functions, isolate-safe)
// // ---------------------------------------------------------------------------

// class ImageProcessor {
//   // ── 2-a  Color grading: modify RGB channels directly ────────────────────

//   static img.Image applyColorGrade(img.Image src, ColorGradePreset preset) {
//     switch (preset) {
//       case ColorGradePreset.normal:
//         return src.clone();
//       case ColorGradePreset.bw:
//         return _applyBW(src);
//       case ColorGradePreset.warm:
//         return _applyChannelCurve(src, rGain: 1.15, gGain: 1.05, bGain: 0.85);
//       case ColorGradePreset.cool:
//         return _applyChannelCurve(src, rGain: 0.85, gGain: 1.00, bGain: 1.20);
//       case ColorGradePreset.vintage:
//         return _applyVintage(src);
//       case ColorGradePreset.highContrast:
//         return _applyHighContrast(src);
//     }
//   }

//   static img.Image _applyChannelCurve(
//     img.Image src, {
//     double rGain = 1,
//     double gGain = 1,
//     double bGain = 1,
//   }) {
//     final out = img.Image(width: src.width, height: src.height);
//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         out.setPixelRgba(
//           x, y,
//           _clamp((px.r * rGain).round()),
//           _clamp((px.g * gGain).round()),
//           _clamp((px.b * bGain).round()),
//           px.a.toInt(),
//         );
//       }
//     }
//     return out;
//   }

//   static img.Image _applyBW(img.Image src) {
//     final out = img.Image(width: src.width, height: src.height);
//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         // luminance weights ITU-R BT.601
//         final lum = _clamp((0.299 * px.r + 0.587 * px.g + 0.114 * px.b).round());
//         out.setPixelRgba(x, y, lum, lum, lum, px.a.toInt());
//       }
//     }
//     return out;
//   }

//   static img.Image _applyVintage(img.Image src) {
//     // Slightly faded shadows, warm mids, desaturated look
//     final out = img.Image(width: src.width, height: src.height);
//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         int r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
//         // Fade shadows (lift blacks slightly)
//         r = _clamp((r * 0.9 + 20).round());
//         g = _clamp((g * 0.88 + 15).round());
//         b = _clamp((b * 0.72 + 10).round());
//         out.setPixelRgba(x, y, r, g, b, px.a.toInt());
//       }
//     }
//     return out;
//   }

//   static img.Image _applyHighContrast(img.Image src) {
//     // S-curve approximation on luminance
//     final out = img.Image(width: src.width, height: src.height);
//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         out.setPixelRgba(
//           x, y,
//           _sCurve(px.r.toInt()),
//           _sCurve(px.g.toInt()),
//           _sCurve(px.b.toInt()),
//           px.a.toInt(),
//         );
//       }
//     }
//     return out;
//   }

//   static int _sCurve(int v) {
//     final n = v / 255.0;
//     // Simple cubic S-curve: 3t²-2t³ mapped around 0.5
//     final c = n < 0.5
//         ? 2 * n * n * (1.5 - n)
//         : 1 - 2 * (1 - n) * (1 - n) * (1.5 - (1 - n));
//     return _clamp((c * 255).round());
//   }

//   // ── 2-b  Relighting: brightness / contrast / exposure ───────────────────

//   /// Applies brightness (–1…+1), contrast (0…3) and exposure (EV stops).
//   static img.Image applyRelight(
//     img.Image src, {
//     required double brightness,
//     required double contrast,
//     required double exposure,
//   }) {
//     // Exposure: multiply linear light by 2^EV
//     final evMul = math.pow(2.0, exposure).toDouble();

//     // Contrast pivot at mid-grey (128)
//     // out = (in - 128) * contrast + 128 + brightness*255
//     final out = img.Image(width: src.width, height: src.height);
//     final bShift = (brightness * 255).round();

//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         int r = _applyPixelRelight(px.r.toInt(), contrast, bShift, evMul);
//         int g = _applyPixelRelight(px.g.toInt(), contrast, bShift, evMul);
//         int b = _applyPixelRelight(px.b.toInt(), contrast, bShift, evMul);
//         out.setPixelRgba(x, y, r, g, b, px.a.toInt());
//       }
//     }
//     return out;
//   }

//   static int _applyPixelRelight(int v, double contrast, int bShift, double evMul) {
//     // Apply exposure (linear)
//     double f = (v / 255.0) * evMul;
//     f = f.clamp(0.0, 1.0);
//     // Back to 0-255
//     int c = (f * 255).round();
//     // Contrast
//     c = _clamp(((c - 128) * contrast + 128).round());
//     // Brightness
//     c = _clamp(c + bShift);
//     return c;
//   }

//   // ── 2-c  Saturation ─────────────────────────────────────────────────────

//   static img.Image applySaturation(img.Image src, double saturation) {
//     final out = img.Image(width: src.width, height: src.height);
//     for (int y = 0; y < src.height; y++) {
//       for (int x = 0; x < src.width; x++) {
//         final px = src.getPixel(x, y);
//         final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
//         final lum = (0.299 * r + 0.587 * g + 0.114 * b);
//         out.setPixelRgba(
//           x, y,
//           _clamp((lum + (r - lum) * saturation).round()),
//           _clamp((lum + (g - lum) * saturation).round()),
//           _clamp((lum + (b - lum) * saturation).round()),
//           px.a.toInt(),
//         );
//       }
//     }
//     return out;
//   }

//   // ── 2-d  Compose full pipeline ───────────────────────────────────────────

//   /// Runs ALL adjustments in a single pixel pass (efficient).
//   /// Call this in an isolate for large images.
//   static img.Image applyFullPipeline(img.Image base, EditState state) {
//     // Step 1: colour grade preset
//     var result = applyColorGrade(base, state.preset);

//     // Step 2: saturation
//     result = applySaturation(result, state.saturation);

//     // Step 3: relight (brightness / contrast / exposure)
//     result = applyRelight(
//       result,
//       brightness: state.brightness,
//       contrast: state.contrast,
//       exposure: state.exposure,
//     );

//     // Step 4: geometric transforms baked in for export
//     if (state.rotation != 0) {
//       result = img.copyRotate(result, angle: state.rotation * (180 / math.pi));
//     }

//     return result;
//   }

//   // ── 2-e  Utility ─────────────────────────────────────────────────────────

//   static int _clamp(int v) => v.clamp(0, 255);

//   /// Decode any Uint8List (PNG / JPEG / etc.) to img.Image
//   static img.Image? decode(Uint8List bytes) => img.decodeImage(bytes);

//   /// Encode img.Image to PNG bytes
//   static Uint8List encodePng(img.Image image) => img.encodePng(image);
// }

// // ---------------------------------------------------------------------------
// // SECTION 3 — ISOLATE HELPER  (keeps UI smooth during heavy processing)
// // ---------------------------------------------------------------------------

// class _IsolatePayload {
//   final Uint8List baseBytes;
//   final EditState state;
//   final SendPort replyPort;
//   const _IsolatePayload(this.baseBytes, this.state, this.replyPort);
// }

// void _processInIsolate(_IsolatePayload payload) {
//   final base = ImageProcessor.decode(payload.baseBytes);
//   if (base == null) {
//     payload.replyPort.send(null);
//     return;
//   }
//   final result = ImageProcessor.applyFullPipeline(base, payload.state);
//   payload.replyPort.send(ImageProcessor.encodePng(result));
// }

// // ---------------------------------------------------------------------------
// // SECTION 4 — BACKGROUND REMOVAL SERVICE  (remove.bg REST API)
// // ---------------------------------------------------------------------------

// class BackgroundRemovalService {
//   // Replace with your actual remove.bg API key.
//   // For production: load from environment / secure storage, never hard-code.
//   static const String _apiKey = 'YOUR_REMOVE_BG_API_KEY';
//   static const String _endpoint = 'https://api.remove.bg/v1.0/removebg';

//   /// Sends [imageBytes] to remove.bg and returns the result PNG.
//   /// Throws a [BackgroundRemovalException] on failure.
//   static Future<Uint8List> remove(Uint8List imageBytes) async {
//     final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
//       ..headers['X-Api-Key'] = _apiKey
//       ..fields['size'] = 'auto'
//       ..files.add(http.MultipartFile.fromBytes(
//         'image_file',
//         imageBytes,
//         filename: 'image.png',
//       ));

//     final streamedResponse = await request.send().timeout(
//       const Duration(seconds: 60),
//       onTimeout: () => throw BackgroundRemovalException('Request timed out'),
//     );

//     final response = await http.Response.fromStream(streamedResponse);

//     if (response.statusCode == 200) {
//       return response.bodyBytes;
//     }
//     throw BackgroundRemovalException(
//         'remove.bg API error ${response.statusCode}: ${response.body}');
//   }
// }

// class BackgroundRemovalException implements Exception {
//   final String message;
//   const BackgroundRemovalException(this.message);
//   @override
//   String toString() => 'BackgroundRemovalException: $message';
// }

// // ---------------------------------------------------------------------------
// // SECTION 5 — SAVE SERVICE
// // ---------------------------------------------------------------------------

// class ImageSaveService {
//   /// Runs the full pipeline in an isolate, saves to temp dir,
//   /// then writes to the device gallery via saver_gallery 3.0.10.
//   /// Returns the saved file path.
//   static Future<String> saveToGallery({
//     required Uint8List baseImageBytes,
//     required EditState state,
//     required String albumName,
//   }) async {
//     // 1. Process in isolate
//     final receivePort = ReceivePort();
//     await Isolate.spawn(
//       _processInIsolate,
//       _IsolatePayload(baseImageBytes, state, receivePort.sendPort),
//     );
//     final Uint8List? processedBytes = await receivePort.first as Uint8List?;
//     if (processedBytes == null) throw Exception('Image processing failed');

//     // 2. Write to temp file
//     final dir = await getTemporaryDirectory();
//     final filePath =
//         '${dir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png';
//     await File(filePath).writeAsBytes(processedBytes);

//     // 3. Save to gallery — saver_gallery 3.0.10 API
//     final result = await SaverGallery.saveFile(
//       filePath: filePath,
//       fileName: 'edited_${DateTime.now().millisecondsSinceEpoch}',
//       skipIfExists: false,
//     );
//     if (!result.isSuccess) {
//       throw Exception('Gallery save failed: ${result.errorMessage}');
//     }

//     return filePath; // ✅ required return
//   }
// }

// // ---------------------------------------------------------------------------
// // SECTION 6 — WIDGET
// // ---------------------------------------------------------------------------

// class EditImageScreen extends StatefulWidget {
//   final String imagePath;
//   const EditImageScreen({super.key, required this.imagePath});

//   @override
//   State<EditImageScreen> createState() => _EditImageScreenState();
// }

// class _EditImageScreenState extends State<EditImageScreen>
//     with TickerProviderStateMixin {
//   // ── Raw source data ──────────────────────────────────────────────────────
//   Uint8List? _sourceBytes;        // original bytes (never mutated)
//   Uint8List? _bgRemovedBytes;     // bytes after background removal
//   ui.Image? _previewImage;        // current flutter ui.Image for rendering

//   // ── State ────────────────────────────────────────────────────────────────
//   EditState _current = const EditState();
//   final List<EditState> _history = [];
//   int _historyIndex = -1;

//   // ── UI flags ─────────────────────────────────────────────────────────────
//   bool _loadingSource = true;
//   bool _processingPreview = false;
//   bool _removingBg = false;
//   bool _saving = false;
//   String? _statusMessage;

//   // ── Debounce timer for slider preview ────────────────────────────────────
//   Timer? _previewDebounce;

//   // ── Selected bottom panel ─────────────────────────────────────────────────
//   _ToolPanel _activePanel = _ToolPanel.relight;

//   // ── Gesture state ────────────────────────────────────────────────────────
//   double _baseScale = 1;
//   Offset _baseOffset = Offset.zero;

//   // ---------------------------------------------------------------------------
//   // LIFECYCLE
//   // ---------------------------------------------------------------------------

//   @override
//   void initState() {
//     super.initState();
//     _loadSourceImage();
//   }

//   @override
//   void dispose() {
//     _previewDebounce?.cancel();
//     super.dispose();
//   }

//   // ---------------------------------------------------------------------------
//   // IMAGE LOADING
//   // ---------------------------------------------------------------------------

//   Future<void> _loadSourceImage() async {
//     setState(() => _loadingSource = true);
//     try {
//       final bytes = File(widget.imagePath).existsSync()
//           ? await File(widget.imagePath).readAsBytes()
//           : (await rootBundle.load(widget.imagePath)).buffer.asUint8List();

//       _sourceBytes = bytes;
//       await _refreshPreview(push: true);
//     } catch (e) {
//       _showSnack('Failed to load image: $e');
//     } finally {
//       if (mounted) setState(() => _loadingSource = false);
//     }
//   }

//   // ---------------------------------------------------------------------------
//   // PREVIEW PIPELINE  (runs async, debounced for sliders)
//   // ---------------------------------------------------------------------------

//   Uint8List get _activeBaseBytes => _bgRemovedBytes ?? _sourceBytes!;

//   Future<void> _refreshPreview({bool push = false}) async {
//     if (_sourceBytes == null) return;
//     if (mounted) setState(() => _processingPreview = true);

//     try {
//       // Use compute-style isolate so UI never jank
//       final receivePort = ReceivePort();
//       await Isolate.spawn(
//         _processInIsolate,
//         _IsolatePayload(_activeBaseBytes, _current, receivePort.sendPort),
//       );
//       final Uint8List? result = await receivePort.first as Uint8List?;
//       if (result == null) throw Exception('Isolate returned null');

//       final codec = await ui.instantiateImageCodec(result);
//       final frame = await codec.getNextFrame();

//       if (mounted) {
//         setState(() {
//           _previewImage = frame.image;
//           if (push) _pushHistory();
//         });
//       }
//     } catch (e) {
//       _showSnack('Preview error: $e');
//     } finally {
//       if (mounted) setState(() => _processingPreview = false);
//     }
//   }

//   void _schedulePreview() {
//     _previewDebounce?.cancel();
//     _previewDebounce = Timer(const Duration(milliseconds: 180), _refreshPreview);
//   }

//   // ---------------------------------------------------------------------------
//   // HISTORY
//   // ---------------------------------------------------------------------------

//   void _pushHistory() {
//     if (_historyIndex < _history.length - 1) {
//       _history.removeRange(_historyIndex + 1, _history.length);
//     }
//     _history.add(_current);
//     _historyIndex++;
//   }

//   void _undo() {
//     if (_historyIndex <= 0) return;
//     _historyIndex--;
//     _applyHistoryState(_history[_historyIndex]);
//   }

//   void _redo() {
//     if (_historyIndex >= _history.length - 1) return;
//     _historyIndex++;
//     _applyHistoryState(_history[_historyIndex]);
//   }

//   void _applyHistoryState(EditState state) {
//     setState(() => _current = state);
//     _refreshPreview();
//   }

//   // ---------------------------------------------------------------------------
//   // BACKGROUND REMOVAL
//   // ---------------------------------------------------------------------------

//   Future<void> _removeBackground() async {
//     if (_sourceBytes == null) return;
//     setState(() {
//       _removingBg = true;
//       _statusMessage = 'Removing background…';
//     });
//     try {
//       final result = await BackgroundRemovalService.remove(_sourceBytes!);
//       _bgRemovedBytes = result;
//       _current = _current.copyWith(backgroundRemoved: true);
//       await _refreshPreview(push: true);
//       _showSnack('Background removed ✓');
//     } on BackgroundRemovalException catch (e) {
//       _showSnack(e.message);
//     } catch (e) {
//       _showSnack('Background removal failed: $e');
//     } finally {
//       if (mounted) setState(() {
//         _removingBg = false;
//         _statusMessage = null;
//       });
//     }
//   }

//   Future<void> _restoreBackground() async {
//     _bgRemovedBytes = null;
//     _current = _current.copyWith(backgroundRemoved: false);
//     await _refreshPreview(push: true);
//     _showSnack('Original background restored');
//   }

//   // ---------------------------------------------------------------------------
//   // SAVE
//   // ---------------------------------------------------------------------------

//   Future<void> _saveImage() async {
//     if (_sourceBytes == null) return;
//     setState(() {
//       _saving = true;
//       _statusMessage = 'Baking edits & saving…';
//     });
//     try {
//       final path = await ImageSaveService.saveToGallery(
//         baseImageBytes: _activeBaseBytes,
//         state: _current,
//         albumName: 'EditedPhotos',
//       );
//       _showSnack('Saved to gallery → $path');
//     } catch (e) {
//       _showSnack('Save failed: $e');
//     } finally {
//       if (mounted) setState(() {
//         _saving = false;
//         _statusMessage = null;
//       });
//     }
//   }

//   // ---------------------------------------------------------------------------
//   // HELPERS
//   // ---------------------------------------------------------------------------

//   void _showSnack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context)
//       ..clearSnackBars()
//       ..showSnackBar(SnackBar(
//         content: Text(msg),
//         backgroundColor: const Color(0xFF1A1A2E),
//         behavior: SnackBarBehavior.floating,
//       ));
//   }

//   // ---------------------------------------------------------------------------
//   // STATE MUTATORS  (called by UI, schedule preview)
//   // ---------------------------------------------------------------------------

//   void _setBrightness(double v) => setState(() {
//         _current = _current.copyWith(brightness: v);
//         _schedulePreview();
//       });

//   void _setContrast(double v) => setState(() {
//         _current = _current.copyWith(contrast: v);
//         _schedulePreview();
//       });

//   void _setSaturation(double v) => setState(() {
//         _current = _current.copyWith(saturation: v);
//         _schedulePreview();
//       });

//   void _setExposure(double v) => setState(() {
//         _current = _current.copyWith(exposure: v);
//         _schedulePreview();
//       });

//   void _setPreset(ColorGradePreset preset) {
//     setState(() => _current = _current.copyWith(preset: preset));
//     _refreshPreview(push: true);
//   }

//   void _rotateLeft() {
//     setState(() => _current = _current.copyWith(
//           rotation: _current.rotation - (math.pi / 16),
//         ));
//     _refreshPreview(push: true);
//   }

//   void _rotateRight() {
//     setState(() => _current = _current.copyWith(
//           rotation: _current.rotation + (math.pi / 16),
//         ));
//     _refreshPreview(push: true);
//   }

//   void _resetTransform() {
//     setState(() => _current = _current.copyWith(
//           rotation: 0,
//           scale: 1,
//           offset: Offset.zero,
//         ));
//     _refreshPreview(push: true);
//   }

//   void _resetAdjustments() {
//     setState(() => _current = _current.copyWith(
//           brightness: 0,
//           contrast: 1,
//           saturation: 1,
//           exposure: 0,
//           preset: ColorGradePreset.normal,
//         ));
//     _refreshPreview(push: true);
//   }

//   // ---------------------------------------------------------------------------
//   // BUILD
//   // ---------------------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     final mq = MediaQuery.of(context);
//     return Scaffold(
//       backgroundColor: const Color(0xFF0D0D0D),
//       body: _loadingSource
//           ? const Center(
//               child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
//           : Stack(
//               children: [
//                 // ── IMAGE VIEWPORT ─────────────────────────────────────────
//                 Positioned.fill(
//                   child: _ImageViewport(
//                     image: _previewImage,
//                     scale: _current.scale,
//                     offset: _current.offset,
//                     rotation: _current.rotation,
//                     onScaleStart: (_) {
//                       _baseScale = _current.scale;
//                       _baseOffset = _current.offset;
//                     },
//                     onScaleUpdate: (details) {
//                       setState(() {
//                         _current = _current.copyWith(
//                           scale: (_baseScale * details.scale).clamp(0.2, 8.0),
//                           offset: _baseOffset + details.focalPointDelta,
//                         );
//                       });
//                     },
//                     processingOverlay: _processingPreview,
//                   ),
//                 ),

//                 // ── TOP BAR ────────────────────────────────────────────────
//                 Positioned(
//                   top: mq.padding.top + 8,
//                   left: 12,
//                   right: 12,
//                   child: _TopBar(
//                     onBack: () => Navigator.of(context).maybePop(),
//                     onUndo: _historyIndex > 0 ? _undo : null,
//                     onRedo:
//                         _historyIndex < _history.length - 1 ? _redo : null,
//                     onSave: _saving ? null : _saveImage,
//                     saving: _saving,
//                     statusMessage: _statusMessage,
//                   ),
//                 ),

//                 // ── BOTTOM PANEL ───────────────────────────────────────────
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   right: 0,
//                   child: _BottomPanel(
//                     activePanel: _activePanel,
//                     current: _current,
//                     removingBg: _removingBg,
//                     onPanelChanged: (p) => setState(() => _activePanel = p),
//                     onBrightness: _setBrightness,
//                     onContrast: _setContrast,
//                     onSaturation: _setSaturation,
//                     onExposure: _setExposure,
//                     onPreset: _setPreset,
//                     onRotateLeft: _rotateLeft,
//                     onRotateRight: _rotateRight,
//                     onResetTransform: _resetTransform,
//                     onResetAdjustments: _resetAdjustments,
//                     onRemoveBg: _removeBackground,
//                     onRestoreBg: _restoreBackground,
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }

// // ---------------------------------------------------------------------------
// // SECTION 7 — SUB-WIDGETS  (split for readability)
// // ---------------------------------------------------------------------------

// enum _ToolPanel { relight, colorGrade, transform, background }

// // ── Image Viewport ──────────────────────────────────────────────────────────

// class _ImageViewport extends StatelessWidget {
//   final ui.Image? image;
//   final double scale;
//   final Offset offset;
//   final double rotation;
//   final GestureScaleStartCallback onScaleStart;
//   final GestureScaleUpdateCallback onScaleUpdate;
//   final bool processingOverlay;

//   const _ImageViewport({
//     required this.image,
//     required this.scale,
//     required this.offset,
//     required this.rotation,
//     required this.onScaleStart,
//     required this.onScaleUpdate,
//     required this.processingOverlay,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onScaleStart: onScaleStart,
//       onScaleUpdate: onScaleUpdate,
//       child: Container(
//         color: const Color(0xFF0D0D0D),
//         child: Center(
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               if (image != null)
//                 Transform(
//                   alignment: Alignment.center,
//                   transform: Matrix4.identity()
//                     ..translate(offset.dx, offset.dy)
//                     ..scale(scale)
//                     ..rotateZ(rotation),
//                   child: CustomPaint(
//                     painter: _ImagePainter(image!),
//                     size: Size(
//                       image!.width.toDouble(),
//                       image!.height.toDouble(),
//                     ),
//                   ),
//                 )
//               else
//                 const Text('No image',
//                     style: TextStyle(color: Colors.white54)),
//               if (processingOverlay)
//                 const Positioned.fill(
//                   child: ColoredBox(
//                     color: Color(0x44000000),
//                     child: Center(
//                       child: SizedBox(
//                         width: 28,
//                         height: 28,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2.5,
//                           color: Color(0xFF00E5FF),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ImagePainter extends CustomPainter {
//   final ui.Image image;
//   const _ImagePainter(this.image);

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()..filterQuality = FilterQuality.high;
//     canvas.drawImage(image, Offset.zero, paint);
//   }

//   @override
//   bool shouldRepaint(_ImagePainter old) => old.image != image;
// }

// // ── Top Bar ─────────────────────────────────────────────────────────────────

// class _TopBar extends StatelessWidget {
//   final VoidCallback onBack;
//   final VoidCallback? onUndo;
//   final VoidCallback? onRedo;
//   final VoidCallback? onSave;
//   final bool saving;
//   final String? statusMessage;

//   const _TopBar({
//     required this.onBack,
//     required this.onUndo,
//     required this.onRedo,
//     required this.onSave,
//     required this.saving,
//     required this.statusMessage,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             _Btn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
//             const Text(
//               'Edit Photo',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 letterSpacing: 0.5,
//               ),
//             ),
//             Row(
//               children: [
//                 _Btn(
//                   icon: Icons.undo_rounded,
//                   onTap: onUndo,
//                   disabled: onUndo == null,
//                 ),
//                 const SizedBox(width: 8),
//                 _Btn(
//                   icon: Icons.redo_rounded,
//                   onTap: onRedo,
//                   disabled: onRedo == null,
//                 ),
//                 const SizedBox(width: 8),
//                 saving
//                     ? const SizedBox(
//                         width: 36,
//                         height: 36,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: Color(0xFF00E5FF),
//                         ),
//                       )
//                     : _Btn(
//                         icon: Icons.save_alt_rounded,
//                         onTap: onSave,
//                         accent: true,
//                         disabled: onSave == null,
//                       ),
//               ],
//             ),
//           ],
//         ),
//         if (statusMessage != null) ...[
//           const SizedBox(height: 6),
//           Text(
//             statusMessage!,
//             style: const TextStyle(
//               color: Color(0xFF00E5FF),
//               fontSize: 13,
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }

// // ── Bottom Panel ─────────────────────────────────────────────────────────────

// class _BottomPanel extends StatelessWidget {
//   final _ToolPanel activePanel;
//   final EditState current;
//   final bool removingBg;
//   final ValueChanged<_ToolPanel> onPanelChanged;
//   final ValueChanged<double> onBrightness;
//   final ValueChanged<double> onContrast;
//   final ValueChanged<double> onSaturation;
//   final ValueChanged<double> onExposure;
//   final ValueChanged<ColorGradePreset> onPreset;
//   final VoidCallback onRotateLeft;
//   final VoidCallback onRotateRight;
//   final VoidCallback onResetTransform;
//   final VoidCallback onResetAdjustments;
//   final VoidCallback onRemoveBg;
//   final VoidCallback onRestoreBg;

//   const _BottomPanel({
//     required this.activePanel,
//     required this.current,
//     required this.removingBg,
//     required this.onPanelChanged,
//     required this.onBrightness,
//     required this.onContrast,
//     required this.onSaturation,
//     required this.onExposure,
//     required this.onPreset,
//     required this.onRotateLeft,
//     required this.onRotateRight,
//     required this.onResetTransform,
//     required this.onResetAdjustments,
//     required this.onRemoveBg,
//     required this.onRestoreBg,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFF141414),
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.5),
//               blurRadius: 20,
//               spreadRadius: 2),
//         ],
//       ),
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // drag handle
//           Container(
//             width: 36,
//             height: 4,
//             decoration: BoxDecoration(
//               color: Colors.white24,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//           const SizedBox(height: 14),

//           // Tab selector
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: [
//                 _tab('Relight', _ToolPanel.relight, Icons.wb_sunny_outlined),
//                 _tab('Color', _ToolPanel.colorGrade, Icons.palette_outlined),
//                 _tab(
//                     'Transform', _ToolPanel.transform, Icons.crop_rotate_rounded),
//                 _tab('Background', _ToolPanel.background,
//                     Icons.auto_fix_high_rounded),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Panel content
//           AnimatedSwitcher(
//             duration: const Duration(milliseconds: 220),
//             child: _buildActivePanel(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _tab(String label, _ToolPanel panel, IconData icon) {
//     final active = activePanel == panel;
//     return GestureDetector(
//       onTap: () => onPanelChanged(panel),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 180),
//         margin: const EdgeInsets.only(right: 10),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           color: active ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.white10,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: active ? const Color(0xFF00E5FF) : Colors.transparent,
//             width: 1.2,
//           ),
//         ),
//         child: Row(
//           children: [
//             Icon(icon,
//                 size: 16,
//                 color:
//                     active ? const Color(0xFF00E5FF) : Colors.white54),
//             const SizedBox(width: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 color: active ? const Color(0xFF00E5FF) : Colors.white54,
//                 fontSize: 13,
//                 fontWeight:
//                     active ? FontWeight.w600 : FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildActivePanel() {
//     switch (activePanel) {
//       case _ToolPanel.relight:
//         return _RelightPanel(
//           key: const ValueKey('relight'),
//           current: current,
//           onBrightness: onBrightness,
//           onContrast: onContrast,
//           onSaturation: onSaturation,
//           onExposure: onExposure,
//           onReset: onResetAdjustments,
//         );
//       case _ToolPanel.colorGrade:
//         return _ColorGradePanel(
//           key: const ValueKey('color'),
//           selectedPreset: current.preset,
//           onPreset: onPreset,
//         );
//       case _ToolPanel.transform:
//         return _TransformPanel(
//           key: const ValueKey('transform'),
//           current: current,
//           onRotateLeft: onRotateLeft,
//           onRotateRight: onRotateRight,
//           onReset: onResetTransform,
//         );
//       case _ToolPanel.background:
//         return _BackgroundPanel(
//           key: const ValueKey('background'),
//           bgRemoved: current.backgroundRemoved,
//           removing: removingBg,
//           onRemove: onRemoveBg,
//           onRestore: onRestoreBg,
//         );
//     }
//   }
// }

// // ── Relight Panel ─────────────────────────────────────────────────────────────

// class _RelightPanel extends StatelessWidget {
//   final EditState current;
//   final ValueChanged<double> onBrightness;
//   final ValueChanged<double> onContrast;
//   final ValueChanged<double> onSaturation;
//   final ValueChanged<double> onExposure;
//   final VoidCallback onReset;

//   const _RelightPanel({
//     super.key,
//     required this.current,
//     required this.onBrightness,
//     required this.onContrast,
//     required this.onSaturation,
//     required this.onExposure,
//     required this.onReset,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _EditorSlider(
//           label: 'Brightness',
//           value: current.brightness,
//           min: -1,
//           max: 1,
//           onChanged: onBrightness,
//         ),
//         _EditorSlider(
//           label: 'Contrast',
//           value: current.contrast,
//           min: 0,
//           max: 3,
//           onChanged: onContrast,
//         ),
//         _EditorSlider(
//           label: 'Saturation',
//           value: current.saturation,
//           min: 0,
//           max: 3,
//           onChanged: onSaturation,
//         ),
//         _EditorSlider(
//           label: 'Exposure (EV)',
//           value: current.exposure,
//           min: -2,
//           max: 2,
//           onChanged: onExposure,
//         ),
//         const SizedBox(height: 8),
//         Align(
//           alignment: Alignment.centerRight,
//           child: TextButton(
//             onPressed: onReset,
//             child: const Text('Reset',
//                 style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Color Grade Panel ─────────────────────────────────────────────────────────

// class _ColorGradePanel extends StatelessWidget {
//   final ColorGradePreset selectedPreset;
//   final ValueChanged<ColorGradePreset> onPreset;

//   const _ColorGradePanel({
//     super.key,
//     required this.selectedPreset,
//     required this.onPreset,
//   });

//   static const _presets = [
//     (ColorGradePreset.normal, 'Normal'),
//     (ColorGradePreset.warm, 'Warm'),
//     (ColorGradePreset.cool, 'Cool'),
//     (ColorGradePreset.vintage, 'Vintage'),
//     (ColorGradePreset.highContrast, 'Hi-Con'),
//     (ColorGradePreset.bw, 'B&W'),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 72,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: _presets.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 10),
//         itemBuilder: (_, i) {
//           final (preset, label) = _presets[i];
//           final selected = selectedPreset == preset;
//           return GestureDetector(
//             onTap: () => onPreset(preset),
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               width: 72,
//               decoration: BoxDecoration(
//                 gradient: selected
//                     ? const LinearGradient(
//                         colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       )
//                     : null,
//                 color: selected ? null : Colors.white12,
//                 borderRadius: BorderRadius.circular(14),
//                 border: Border.all(
//                   color: selected ? const Color(0xFF00E5FF) : Colors.transparent,
//                   width: 1.5,
//                 ),
//               ),
//               child: Center(
//                 child: Text(
//                   label,
//                   style: TextStyle(
//                     color: selected ? Colors.white : Colors.white54,
//                     fontSize: 13,
//                     fontWeight:
//                         selected ? FontWeight.w700 : FontWeight.normal,
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// // ── Transform Panel ───────────────────────────────────────────────────────────

// class _TransformPanel extends StatelessWidget {
//   final EditState current;
//   final VoidCallback onRotateLeft;
//   final VoidCallback onRotateRight;
//   final VoidCallback onReset;

//   const _TransformPanel({
//     super.key,
//     required this.current,
//     required this.onRotateLeft,
//     required this.onRotateRight,
//     required this.onReset,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final deg = (current.rotation * 180 / math.pi).toStringAsFixed(1);
//     return Column(
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _Btn(
//                 icon: Icons.rotate_left_rounded, onTap: onRotateLeft, size: 26),
//             Column(
//               children: [
//                 Text(
//                   '${deg}°',
//                   style: const TextStyle(
//                       color: Colors.white70,
//                       fontSize: 15,
//                       fontWeight: FontWeight.w600),
//                 ),
//                 const Text('rotation',
//                     style: TextStyle(color: Colors.white38, fontSize: 11)),
//               ],
//             ),
//             _Btn(
//                 icon: Icons.rotate_right_rounded,
//                 onTap: onRotateRight,
//                 size: 26),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _infoChip(
//                 'Zoom', '${(current.scale * 100).toStringAsFixed(0)}%'),
//             TextButton.icon(
//               onPressed: onReset,
//               icon: const Icon(Icons.refresh_rounded,
//                   size: 16, color: Color(0xFF00E5FF)),
//               label: const Text('Reset',
//                   style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _infoChip(String label, String value) => Container(
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//         decoration: BoxDecoration(
//           color: Colors.white10,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Column(
//           children: [
//             Text(value,
//                 style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                     fontSize: 14)),
//             Text(label,
//                 style:
//                     const TextStyle(color: Colors.white38, fontSize: 11)),
//           ],
//         ),
//       );
// }

// // ── Background Panel ──────────────────────────────────────────────────────────

// class _BackgroundPanel extends StatelessWidget {
//   final bool bgRemoved;
//   final bool removing;
//   final VoidCallback onRemove;
//   final VoidCallback onRestore;

//   const _BackgroundPanel({
//     super.key,
//     required this.bgRemoved,
//     required this.removing,
//     required this.onRemove,
//     required this.onRestore,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         if (removing)
//           const Row(
//             children: [
//               SizedBox(
//                   width: 20,
//                   height: 20,
//                   child: CircularProgressIndicator(
//                       strokeWidth: 2, color: Color(0xFF00E5FF))),
//               SizedBox(width: 12),
//               Text('Removing background…',
//                   style: TextStyle(color: Colors.white70)),
//             ],
//           )
//         else if (!bgRemoved)
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
//               foregroundColor: const Color(0xFF00E5FF),
//               side: const BorderSide(color: Color(0xFF00E5FF)),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14)),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//             ),
//             icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
//             label: const Text('Remove Background'),
//             onPressed: onRemove,
//           )
//         else ...[
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green.withOpacity(0.15),
//               foregroundColor: Colors.greenAccent,
//               side: const BorderSide(color: Colors.greenAccent),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14)),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//             ),
//             icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
//             label: const Text('BG Removed ✓'),
//             onPressed: null,
//           ),
//           const SizedBox(width: 12),
//           OutlinedButton(
//             style: OutlinedButton.styleFrom(
//               side: const BorderSide(color: Colors.white24),
//               foregroundColor: Colors.white54,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(14)),
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             ),
//             onPressed: onRestore,
//             child: const Text('Restore'),
//           ),
//         ],
//       ],
//     );
//   }
// }

// // ── Shared Widgets ────────────────────────────────────────────────────────────

// class _EditorSlider extends StatelessWidget {
//   final String label;
//   final double value;
//   final double min;
//   final double max;
//   final ValueChanged<double> onChanged;

//   const _EditorSlider({
//     required this.label,
//     required this.value,
//     required this.min,
//     required this.max,
//     required this.onChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(label,
//                 style:
//                     const TextStyle(color: Colors.white70, fontSize: 13)),
//             Text(value.toStringAsFixed(2),
//                 style: const TextStyle(
//                     color: Color(0xFF00E5FF),
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600)),
//           ],
//         ),
//         SliderTheme(
//           data: SliderTheme.of(context).copyWith(
//             activeTrackColor: const Color(0xFF00E5FF),
//             inactiveTrackColor: Colors.white12,
//             thumbColor: const Color(0xFF00E5FF),
//             overlayColor: const Color(0xFF00E5FF).withOpacity(0.12),
//             trackHeight: 3,
//             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
//           ),
//           child: Slider(
//             value: value.clamp(min, max),
//             min: min,
//             max: max,
//             onChanged: onChanged,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _Btn extends StatelessWidget {
//   final IconData icon;
//   final VoidCallback? onTap;
//   final bool accent;
//   final bool disabled;
//   final double size;

//   const _Btn({
//     required this.icon,
//     required this.onTap,
//     this.accent = false,
//     this.disabled = false,
//     this.size = 22,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final color = disabled
//         ? Colors.white24
//         : accent
//             ? const Color(0xFF00E5FF)
//             : Colors.white;
//     return GestureDetector(
//       onTap: disabled ? null : onTap,
//       child: Container(
//         padding: const EdgeInsets.all(9),
//         decoration: BoxDecoration(
//           color: accent && !disabled
//               ? const Color(0xFF00E5FF).withOpacity(0.15)
//               : Colors.white12,
//           borderRadius: BorderRadius.circular(12),
//           border: accent && !disabled
//               ? Border.all(color: const Color(0xFF00E5FF), width: 1)
//               : null,
//         ),
//         child: Icon(icon, color: color, size: size),
//       ),
//     );
//   }
// }


// lib/screens/edit_image_screen.dart
//
// Production-ready Image Editor
//
// NEW in this version:
//   • Image source picker — gallery, camera, or keep existing asset path
//   • Background removal via Photoroom API (FREE tier, no credit card needed)
//     Sign up at https://www.photoroom.com/api  → copy your API key below
//   • Pure-Dart greedy flood-fill BG removal fallback (no API needed)
//
// pubspec.yaml dependencies:
//   image: ^4.0.20
//   http: ^0.13.6
//   path_provider: ^2.1.3
//   saver_gallery: ^3.0.10
//   image_picker: ^1.0.7          ← already in your pubspec
//   permission_handler: ^12.0.1   ← already in your pubspec
//
// AndroidManifest.xml permissions (inside <manifest>):
//   <uses-permission android:name="android.permission.CAMERA"/>
//   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
//   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
//       android:maxSdkVersion="32"/>
//   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
//       android:maxSdkVersion="32"/>
//   <uses-permission android:name="android.permission.INTERNET"/>
//
// Inside <application> tag add for camera:
//   <uses-feature android:name="android.hardware.camera" android:required="false"/>

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

// ===========================================================================
// SECTION 1 — DATA MODELS
// ===========================================================================

enum ColorGradePreset { normal, warm, cool, vintage, highContrast, bw }

class EditState {
  final double brightness; // -1.0 … +1.0
  final double contrast;   //  0.0 … 3.0
  final double saturation; //  0.0 … 3.0
  final double exposure;   // -2.0 … +2.0  (EV stops)
  final double rotation;   // radians
  final double scale;
  final Offset offset;
  final ColorGradePreset preset;
  final bool backgroundRemoved;

  const EditState({
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.exposure = 0,
    this.rotation = 0,
    this.scale = 1,
    this.offset = Offset.zero,
    this.preset = ColorGradePreset.normal,
    this.backgroundRemoved = false,
  });

  EditState copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? rotation,
    double? scale,
    Offset? offset,
    ColorGradePreset? preset,
    bool? backgroundRemoved,
  }) =>
      EditState(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        exposure: exposure ?? this.exposure,
        rotation: rotation ?? this.rotation,
        scale: scale ?? this.scale,
        offset: offset ?? this.offset,
        preset: preset ?? this.preset,
        backgroundRemoved: backgroundRemoved ?? this.backgroundRemoved,
      );
}

// ===========================================================================
// SECTION 2 — IMAGE PROCESSING ENGINE  (pure, isolate-safe)
// ===========================================================================

class ImageProcessor {
  // -- Color grade ------------------------------------------------------------

  static img.Image applyColorGrade(img.Image src, ColorGradePreset preset) {
    switch (preset) {
      case ColorGradePreset.normal:
        return src.clone();
      case ColorGradePreset.bw:
        return _applyBW(src);
      case ColorGradePreset.warm:
        return _channelGain(src, rg: 1.15, gg: 1.05, bg: 0.85);
      case ColorGradePreset.cool:
        return _channelGain(src, rg: 0.85, gg: 1.00, bg: 1.20);
      case ColorGradePreset.vintage:
        return _applyVintage(src);
      case ColorGradePreset.highContrast:
        return _applyHighContrast(src);
    }
  }

  static img.Image _channelGain(img.Image src,
      {required double rg, required double gg, required double bg}) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        out.setPixelRgba(x, y, _c((px.r * rg).round()),
            _c((px.g * gg).round()), _c((px.b * bg).round()), px.a.toInt());
      }
    }
    return out;
  }

  static img.Image _applyBW(img.Image src) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final lum = _c((0.299 * px.r + 0.587 * px.g + 0.114 * px.b).round());
        out.setPixelRgba(x, y, lum, lum, lum, px.a.toInt());
      }
    }
    return out;
  }

  static img.Image _applyVintage(img.Image src) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        out.setPixelRgba(
          x, y,
          _c((px.r * 0.9 + 20).round()),
          _c((px.g * 0.88 + 15).round()),
          _c((px.b * 0.72 + 10).round()),
          px.a.toInt(),
        );
      }
    }
    return out;
  }

  static img.Image _applyHighContrast(img.Image src) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        out.setPixelRgba(x, y, _sCurve(px.r.toInt()), _sCurve(px.g.toInt()),
            _sCurve(px.b.toInt()), px.a.toInt());
      }
    }
    return out;
  }

  static int _sCurve(int v) {
    final n = v / 255.0;
    final c = n < 0.5
        ? 2 * n * n * (1.5 - n)
        : 1 - 2 * (1 - n) * (1 - n) * (1.5 - (1 - n));
    return _c((c * 255).round());
  }

  // -- Relighting -------------------------------------------------------------

  static img.Image applyRelight(img.Image src,
      {required double brightness,
      required double contrast,
      required double exposure}) {
    final evMul = math.pow(2.0, exposure).toDouble();
    final bShift = (brightness * 255).round();
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        out.setPixelRgba(
          x, y,
          _relit(px.r.toInt(), contrast, bShift, evMul),
          _relit(px.g.toInt(), contrast, bShift, evMul),
          _relit(px.b.toInt(), contrast, bShift, evMul),
          px.a.toInt(),
        );
      }
    }
    return out;
  }

  static int _relit(int v, double contrast, int bShift, double evMul) {
    double f = ((v / 255.0) * evMul).clamp(0.0, 1.0);
    int c = (f * 255).round();
    c = _c(((c - 128) * contrast + 128).round());
    return _c(c + bShift);
  }

  // -- Saturation -------------------------------------------------------------

  static img.Image applySaturation(img.Image src, double saturation) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        out.setPixelRgba(
          x, y,
          _c((lum + (r - lum) * saturation).round()),
          _c((lum + (g - lum) * saturation).round()),
          _c((lum + (b - lum) * saturation).round()),
          px.a.toInt(),
        );
      }
    }
    return out;
  }

  // -- Full pipeline ----------------------------------------------------------

  static img.Image applyFullPipeline(img.Image base, EditState state) {
    var result = applyColorGrade(base, state.preset);
    result = applySaturation(result, state.saturation);
    result = applyRelight(result,
        brightness: state.brightness,
        contrast: state.contrast,
        exposure: state.exposure);
    if (state.rotation != 0) {
      result = img.copyRotate(result, angle: state.rotation * (180 / math.pi));
    }
    return result;
  }

  // -- Pure-Dart flood-fill background removal --------------------------------
  //
  // Samples the image border to detect the background colour, then BFS
  // flood-fills matching pixels from every border edge and makes them
  // transparent.  Works best for images with a solid or near-solid
  // background.  For complex backgrounds use the Photoroom API path.

  static img.Image floodFillRemoveBg(img.Image src, {int tolerance = 35}) {
    // Ensure RGBA
    final out = img.Image(width: src.width, height: src.height, numChannels: 4);
    img.compositeImage(out, src);

    // Sample border to estimate background colour
    int totalR = 0, totalG = 0, totalB = 0, count = 0;
    void sample(int x, int y) {
      final px = out.getPixel(x, y);
      totalR += px.r.toInt();
      totalG += px.g.toInt();
      totalB += px.b.toInt();
      count++;
    }

    for (int x = 0; x < out.width; x++) {
      sample(x, 0);
      sample(x, out.height - 1);
    }
    for (int y = 1; y < out.height - 1; y++) {
      sample(0, y);
      sample(out.width - 1, y);
    }

    final bgR = totalR ~/ count;
    final bgG = totalG ~/ count;
    final bgB = totalB ~/ count;

    // BFS
    final visited = List.filled(out.width * out.height, false);
    final queue = <int>[];

    void enqueue(int x, int y) {
      if (x < 0 || y < 0 || x >= out.width || y >= out.height) return;
      final idx = y * out.width + x;
      if (visited[idx]) return;
      final px = out.getPixel(x, y);
      final dist = (px.r.toInt() - bgR).abs() +
          (px.g.toInt() - bgG).abs() +
          (px.b.toInt() - bgB).abs();
      if (dist > tolerance * 3) return;
      visited[idx] = true;
      queue.add(idx);
    }

    // Seed entire border
    for (int x = 0; x < out.width; x++) {
      enqueue(x, 0);
      enqueue(x, out.height - 1);
    }
    for (int y = 0; y < out.height; y++) {
      enqueue(0, y);
      enqueue(out.width - 1, y);
    }

    while (queue.isNotEmpty) {
      final idx = queue.removeLast();
      final x = idx % out.width;
      final y = idx ~/ out.width;
      out.setPixelRgba(x, y, 0, 0, 0, 0);
      enqueue(x + 1, y);
      enqueue(x - 1, y);
      enqueue(x, y + 1);
      enqueue(x, y - 1);
    }

    return out;
  }

  // -- Utility ----------------------------------------------------------------
  static int _c(int v) => v.clamp(0, 255);
  static img.Image? decode(Uint8List bytes) => img.decodeImage(bytes);
  static Uint8List encodePng(img.Image image) => img.encodePng(image);
}

// ===========================================================================
// SECTION 3 — ISOLATE HELPERS
// ===========================================================================

class _IsolatePayload {
  final Uint8List baseBytes;
  final EditState state;
  final SendPort replyPort;
  const _IsolatePayload(this.baseBytes, this.state, this.replyPort);
}

void _processInIsolate(_IsolatePayload p) {
  final base = ImageProcessor.decode(p.baseBytes);
  if (base == null) {
    p.replyPort.send(null);
    return;
  }
  p.replyPort.send(ImageProcessor.encodePng(
      ImageProcessor.applyFullPipeline(base, p.state)));
}

class _BgRemovePayload {
  final Uint8List bytes;
  final int tolerance;
  final SendPort replyPort;
  const _BgRemovePayload(this.bytes, this.tolerance, this.replyPort);
}

void _bgRemoveInIsolate(_BgRemovePayload p) {
  final src = ImageProcessor.decode(p.bytes);
  if (src == null) {
    p.replyPort.send(null);
    return;
  }
  p.replyPort.send(ImageProcessor.encodePng(
      ImageProcessor.floodFillRemoveBg(src, tolerance: p.tolerance)));
}

// ===========================================================================
// SECTION 4 — BACKGROUND REMOVAL SERVICE
// ===========================================================================
//
// Priority:
//   1. Photoroom free API (30 free images/month, no card required)
//      → Get a free key at https://www.photoroom.com/api
//      → Paste it in _photoroomApiKey below
//   2. If key is empty OR request fails → pure-Dart flood-fill fallback

class BackgroundRemovalService {
  // Leave empty to always use local fallback.
  static const String _photoroomApiKey = 'sk_pr_default_b5babf0f25febbb30765ebe394539f29e6b1b35c';
  static const String _endpoint = 'https://sdk.photoroom.com/v1/segment';

  static Future<Uint8List> remove(Uint8List imageBytes,
      {int localTolerance = 35}) async {
    if (_photoroomApiKey.isNotEmpty) {
      try {
        return await _photoroomRemove(imageBytes);
      } catch (e) {
        debugPrint('Photoroom failed ($e) — falling back to local algorithm');
      }
    }
    return _localRemove(imageBytes, localTolerance);
  }

  static Future<Uint8List> _photoroomRemove(Uint8List bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(_endpoint))
      ..headers['x-api-key'] = _photoroomApiKey
      ..files.add(http.MultipartFile.fromBytes('image_file', bytes,
          filename: 'image.png'));
    final streamed =
        await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Photoroom ${response.statusCode}: ${response.body}');
  }

  static Future<Uint8List> _localRemove(Uint8List bytes, int tolerance) async {
    final port = ReceivePort();
    await Isolate.spawn(
        _bgRemoveInIsolate, _BgRemovePayload(bytes, tolerance, port.sendPort));
    final result = await port.first as Uint8List?;
    if (result == null) throw Exception('Local BG removal failed');
    return result;
  }
}

// ===========================================================================
// SECTION 5 — SAVE SERVICE
// ===========================================================================

class ImageSaveService {
  static Future<String> saveToGallery({
    required Uint8List baseImageBytes,
    required EditState state,
    required String albumName,
  }) async {
    final port = ReceivePort();
    await Isolate.spawn(
        _processInIsolate, _IsolatePayload(baseImageBytes, state, port.sendPort));
    final Uint8List? processed = await port.first as Uint8List?;
    if (processed == null) throw Exception('Processing failed');

    final dir = await getTemporaryDirectory();
    final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}';
    final filePath = '${dir.path}/$fileName.png';
    await File(filePath).writeAsBytes(processed);

    final result = await SaverGallery.saveFile(
      filePath: filePath,
      fileName: fileName,
      skipIfExists: false,
    );
    if (!result.isSuccess) {
      throw Exception('Gallery save failed: ${result.errorMessage}');
    }
    return filePath;
  }
}

// ===========================================================================
// SECTION 6 — IMAGE SOURCE PICKER
// ===========================================================================

class ImageSourcePicker {
  static final _picker = ImagePicker();

  static Future<Uint8List?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _SourcePickerSheet(),
    );
    if (source == null) return null;
    final XFile? file =
        await _picker.pickImage(source: source, imageQuality: 95);
    if (file == null) return null;
    return file.readAsBytes();
  }
}

class _SourcePickerSheet extends StatelessWidget {
  const _SourcePickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Choose Image Source',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(children: [
            Icon(icon, color: const Color(0xFF00E5FF), size: 32),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
      );
}

// ===========================================================================
// SECTION 7 — MAIN SCREEN
// ===========================================================================

class EditImageScreen extends StatefulWidget {
  /// Provide an asset/file path to pre-load, or leave null to show picker.
  final String? imagePath;
  const EditImageScreen({super.key, this.imagePath});

  @override
  State<EditImageScreen> createState() => _EditImageScreenState();
}

class _EditImageScreenState extends State<EditImageScreen>
    with TickerProviderStateMixin {
  Uint8List? _sourceBytes;
  Uint8List? _bgRemovedBytes;
  ui.Image? _previewImage;

  EditState _current = const EditState();
  final List<EditState> _history = [];
  int _historyIndex = -1;

  bool _loadingSource = false;
  bool _processingPreview = false;
  bool _removingBg = false;
  bool _saving = false;
  String? _statusMessage;

  _ToolPanel _activePanel = _ToolPanel.relight;

  double _baseScale = 1;
  Offset _baseOffset = Offset.zero;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      _loadFromPath(widget.imagePath!);
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _pickNewImage());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------------

  Future<void> _loadFromPath(String path) async {
    setState(() {
      _loadingSource = true;
      _statusMessage = 'Loading…';
    });
    try {
      final bytes = File(path).existsSync()
          ? await File(path).readAsBytes()
          : (await rootBundle.load(path)).buffer.asUint8List();
      await _setSourceBytes(bytes);
    } catch (e) {
      _showSnack('Failed to load: $e');
    } finally {
      if (mounted) setState(() { _loadingSource = false; _statusMessage = null; });
    }
  }

  Future<void> _setSourceBytes(Uint8List bytes) async {
    _sourceBytes = bytes;
    _bgRemovedBytes = null;
    _current = const EditState();
    _history.clear();
    _historyIndex = -1;
    await _refreshPreview(push: true);
  }

  Future<void> _pickNewImage() async {
    final bytes = await ImageSourcePicker.pickImage(context);
    if (bytes == null) return;
    setState(() { _loadingSource = true; _statusMessage = 'Loading image…'; });
    try {
      await _setSourceBytes(bytes);
    } finally {
      if (mounted) setState(() { _loadingSource = false; _statusMessage = null; });
    }
  }

  // ---------------------------------------------------------------------------
  // PREVIEW
  // ---------------------------------------------------------------------------

  Uint8List get _activeBase => _bgRemovedBytes ?? _sourceBytes!;

  Future<void> _refreshPreview({bool push = false}) async {
    if (_sourceBytes == null) return;
    if (mounted) setState(() => _processingPreview = true);
    try {
      final port = ReceivePort();
      await Isolate.spawn(
          _processInIsolate, _IsolatePayload(_activeBase, _current, port.sendPort));
      final Uint8List? result = await port.first as Uint8List?;
      if (result == null) throw Exception('null result');
      final codec = await ui.instantiateImageCodec(result);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() {
        _previewImage = frame.image;
        if (push) _pushHistory();
      });
    } catch (e) {
      _showSnack('Preview error: $e');
    } finally {
      if (mounted) setState(() => _processingPreview = false);
    }
  }

  void _schedulePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _refreshPreview);
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(_current);
    _historyIndex++;
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    setState(() => _current = _history[_historyIndex]);
    _refreshPreview();
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    setState(() => _current = _history[_historyIndex]);
    _refreshPreview();
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND REMOVAL
  // ---------------------------------------------------------------------------

  Future<void> _removeBackground() async {
    if (_sourceBytes == null) return;
    setState(() { _removingBg = true; _statusMessage = 'Removing background…'; });
    try {
      final result = await BackgroundRemovalService.remove(_sourceBytes!);
      _bgRemovedBytes = result;
      _current = _current.copyWith(backgroundRemoved: true);
      await _refreshPreview(push: true);
      _showSnack('Background removed successfully');
    } catch (e) {
      _showSnack('BG removal failed: $e');
    } finally {
      if (mounted) setState(() { _removingBg = false; _statusMessage = null; });
    }
  }

  Future<void> _restoreBackground() async {
    _bgRemovedBytes = null;
    _current = _current.copyWith(backgroundRemoved: false);
    await _refreshPreview(push: true);
    _showSnack('Original background restored');
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveImage() async {
    if (_sourceBytes == null) return;
    setState(() { _saving = true; _statusMessage = 'Saving to gallery…'; });
    try {
      final path = await ImageSaveService.saveToGallery(
        baseImageBytes: _activeBase,
        state: _current,
        albumName: 'SmartCamera',
      );
      _showSnack('Saved to gallery successfully');
      debugPrint('Saved to: $path');
    } catch (e) {
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() { _saving = false; _statusMessage = null; });
    }
  }

  // ---------------------------------------------------------------------------
  // MUTATORS
  // ---------------------------------------------------------------------------

  void _set(EditState s) {
    setState(() => _current = s);
    _schedulePreview();
  }

  void _setPreset(ColorGradePreset p) {
    setState(() => _current = _current.copyWith(preset: p));
    _refreshPreview(push: true);
  }

  void _rotateLeft() {
    setState(() =>
        _current = _current.copyWith(rotation: _current.rotation - math.pi / 16));
    _refreshPreview(push: true);
  }

  void _rotateRight() {
    setState(() =>
        _current = _current.copyWith(rotation: _current.rotation + math.pi / 16));
    _refreshPreview(push: true);
  }

  void _resetTransform() {
    setState(() => _current =
        _current.copyWith(rotation: 0, scale: 1, offset: Offset.zero));
    _refreshPreview(push: true);
  }

  void _resetAdjustments() {
    setState(() => _current = _current.copyWith(
        brightness: 0,
        contrast: 1,
        saturation: 1,
        exposure: 0,
        preset: ColorGradePreset.normal));
    _refreshPreview(push: true);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A1A2E),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Image viewport or empty state
          Positioned.fill(
            child: _sourceBytes == null
                ? _EmptyState(onPick: _pickNewImage)
                : _ImageViewport(
                    image: _previewImage,
                    scale: _current.scale,
                    offset: _current.offset,
                    rotation: _current.rotation,
                    processingOverlay: _processingPreview || _loadingSource,
                    onScaleStart: (_) {
                      _baseScale = _current.scale;
                      _baseOffset = _current.offset;
                    },
                    onScaleUpdate: (d) => setState(() => _current = _current.copyWith(
                          scale: (_baseScale * d.scale).clamp(0.2, 8.0),
                          offset: _baseOffset + d.focalPointDelta,
                        )),
                  ),
          ),

          // Top bar
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 12,
            child: _TopBar(
              hasImage: _sourceBytes != null,
              onBack: () => Navigator.of(context).maybePop(),
              onPickImage: _pickNewImage,
              onUndo: _historyIndex > 0 ? _undo : null,
              onRedo: _historyIndex < _history.length - 1 ? _redo : null,
              onSave: (_sourceBytes != null && !_saving) ? _saveImage : null,
              saving: _saving,
              statusMessage: _statusMessage,
            ),
          ),

          // Bottom panel
          if (_sourceBytes != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomPanel(
                activePanel: _activePanel,
                current: _current,
                removingBg: _removingBg,
                onPanelChanged: (p) => setState(() => _activePanel = p),
                onBrightness: (v) => _set(_current.copyWith(brightness: v)),
                onContrast: (v) => _set(_current.copyWith(contrast: v)),
                onSaturation: (v) => _set(_current.copyWith(saturation: v)),
                onExposure: (v) => _set(_current.copyWith(exposure: v)),
                onPreset: _setPreset,
                onRotateLeft: _rotateLeft,
                onRotateRight: _rotateRight,
                onResetTransform: _resetTransform,
                onResetAdjustments: _resetAdjustments,
                onRemoveBg: _removeBackground,
                onRestoreBg: _restoreBackground,
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SECTION 8 — SUB-WIDGETS
// ===========================================================================

enum _ToolPanel { relight, colorGrade, transform, background }

// -- Empty state --------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyState({required this.onPick});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E5FF), width: 2),
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  color: Color(0xFF00E5FF), size: 44),
            ),
            const SizedBox(height: 20),
            const Text('No image selected',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Pick from gallery or take a photo',
                style: TextStyle(color: Colors.white30, fontSize: 13)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Choose Image'),
              onPressed: onPick,
            ),
          ],
        ),
      );
}

// -- Image viewport -----------------------------------------------------------

class _ImageViewport extends StatelessWidget {
  final ui.Image? image;
  final double scale, rotation;
  final Offset offset;
  final bool processingOverlay;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;

  const _ImageViewport({
    required this.image,
    required this.scale,
    required this.offset,
    required this.rotation,
    required this.processingOverlay,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Container(
          color: const Color(0xFF0D0D0D),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (image != null)
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translate(offset.dx, offset.dy)
                      ..scale(scale)
                      ..rotateZ(rotation),
                    child: CustomPaint(
                      painter: _ImagePainter(image!),
                      size: Size(image!.width.toDouble(),
                          image!.height.toDouble()),
                    ),
                  ),
                if (processingOverlay)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55000000),
                      child: Center(
                        child: SizedBox(
                          width: 28, height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Color(0xFF00E5FF)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  const _ImagePainter(this.image);
  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawImage(image, Offset.zero,
          Paint()..filterQuality = FilterQuality.high);
  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}

// -- Top bar ------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final bool hasImage, saving;
  final VoidCallback onBack, onPickImage;
  final VoidCallback? onUndo, onRedo, onSave;
  final String? statusMessage;

  const _TopBar({
    required this.hasImage,
    required this.saving,
    required this.onBack,
    required this.onPickImage,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Btn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const Text('Edit Photo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              Row(children: [
                _Btn(
                    icon: Icons.add_photo_alternate_rounded,
                    onTap: onPickImage,
                    tooltip: 'Change image'),
                const SizedBox(width: 6),
                _Btn(
                    icon: Icons.undo_rounded,
                    onTap: onUndo,
                    disabled: onUndo == null),
                const SizedBox(width: 6),
                _Btn(
                    icon: Icons.redo_rounded,
                    onTap: onRedo,
                    disabled: onRedo == null),
                const SizedBox(width: 6),
                saving
                    ? const SizedBox(
                        width: 38, height: 38,
                        child: Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00E5FF)),
                        ))
                    : _Btn(
                        icon: Icons.save_alt_rounded,
                        onTap: onSave,
                        accent: true,
                        disabled: onSave == null),
              ]),
            ],
          ),
          if (statusMessage != null) ...[
            const SizedBox(height: 6),
            Text(statusMessage!,
                style: const TextStyle(
                    color: Color(0xFF00E5FF), fontSize: 13)),
          ],
        ],
      );
}

// -- Bottom panel -------------------------------------------------------------

class _BottomPanel extends StatelessWidget {
  final _ToolPanel activePanel;
  final EditState current;
  final bool removingBg;
  final ValueChanged<_ToolPanel> onPanelChanged;
  final ValueChanged<double> onBrightness, onContrast, onSaturation, onExposure;
  final ValueChanged<ColorGradePreset> onPreset;
  final VoidCallback onRotateLeft, onRotateRight, onResetTransform,
      onResetAdjustments, onRemoveBg, onRestoreBg;

  const _BottomPanel({
    required this.activePanel,
    required this.current,
    required this.removingBg,
    required this.onPanelChanged,
    required this.onBrightness,
    required this.onContrast,
    required this.onSaturation,
    required this.onExposure,
    required this.onPreset,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onResetTransform,
    required this.onResetAdjustments,
    required this.onRemoveBg,
    required this.onRestoreBg,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2)
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _tab('Relight', _ToolPanel.relight, Icons.wb_sunny_outlined),
                _tab('Color', _ToolPanel.colorGrade, Icons.palette_outlined),
                _tab('Transform', _ToolPanel.transform,
                    Icons.crop_rotate_rounded),
                _tab('Background', _ToolPanel.background,
                    Icons.auto_fix_high_rounded),
              ]),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildPanel(),
            ),
          ],
        ),
      );

  Widget _tab(String label, _ToolPanel panel, IconData icon) {
    final active = activePanel == panel;
    return GestureDetector(
      onTap: () => onPanelChanged(panel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF).withOpacity(0.15)
              : Colors.white10,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? const Color(0xFF00E5FF) : Colors.transparent,
              width: 1.2),
        ),
        child: Row(children: [
          Icon(icon,
              size: 16,
              color: active ? const Color(0xFF00E5FF) : Colors.white54),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: active ? const Color(0xFF00E5FF) : Colors.white54,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildPanel() {
    switch (activePanel) {
      case _ToolPanel.relight:
        return _RelightPanel(
          key: const ValueKey('relight'),
          current: current,
          onBrightness: onBrightness,
          onContrast: onContrast,
          onSaturation: onSaturation,
          onExposure: onExposure,
          onReset: onResetAdjustments,
        );
      case _ToolPanel.colorGrade:
        return _ColorGradePanel(
          key: const ValueKey('color'),
          selectedPreset: current.preset,
          onPreset: onPreset,
        );
      case _ToolPanel.transform:
        return _TransformPanel(
          key: const ValueKey('transform'),
          current: current,
          onRotateLeft: onRotateLeft,
          onRotateRight: onRotateRight,
          onReset: onResetTransform,
        );
      case _ToolPanel.background:
        return _BackgroundPanel(
          key: const ValueKey('background'),
          bgRemoved: current.backgroundRemoved,
          removing: removingBg,
          onRemove: onRemoveBg,
          onRestore: onRestoreBg,
        );
    }
  }
}

// -- Relight panel ------------------------------------------------------------

class _RelightPanel extends StatelessWidget {
  final EditState current;
  final ValueChanged<double> onBrightness, onContrast, onSaturation, onExposure;
  final VoidCallback onReset;

  const _RelightPanel({
    super.key,
    required this.current,
    required this.onBrightness,
    required this.onContrast,
    required this.onSaturation,
    required this.onExposure,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditorSlider(label: 'Brightness', value: current.brightness,
              min: -1, max: 1, onChanged: onBrightness),
          _EditorSlider(label: 'Contrast', value: current.contrast,
              min: 0, max: 3, onChanged: onContrast),
          _EditorSlider(label: 'Saturation', value: current.saturation,
              min: 0, max: 3, onChanged: onSaturation),
          _EditorSlider(label: 'Exposure (EV)', value: current.exposure,
              min: -2, max: 2, onChanged: onExposure),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReset,
              child: const Text('Reset',
                  style:
                      TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
            ),
          ),
        ],
      );
}

// -- Color grade panel --------------------------------------------------------

class _ColorGradePanel extends StatelessWidget {
  final ColorGradePreset selectedPreset;
  final ValueChanged<ColorGradePreset> onPreset;

  static const _presets = [
    (ColorGradePreset.normal, 'Normal'),
    (ColorGradePreset.warm, 'Warm'),
    (ColorGradePreset.cool, 'Cool'),
    (ColorGradePreset.vintage, 'Vintage'),
    (ColorGradePreset.highContrast, 'Hi-Con'),
    (ColorGradePreset.bw, 'B&W'),
  ];

  const _ColorGradePanel(
      {super.key, required this.selectedPreset, required this.onPreset});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _presets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final (preset, label) = _presets[i];
            final sel = selectedPreset == preset;
            return GestureDetector(
              onTap: () => onPreset(preset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(
                          colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: sel ? null : Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel
                          ? const Color(0xFF00E5FF)
                          : Colors.transparent,
                      width: 1.5),
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white54,
                          fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.normal)),
                ),
              ),
            );
          },
        ),
      );
}

// -- Transform panel ----------------------------------------------------------

class _TransformPanel extends StatelessWidget {
  final EditState current;
  final VoidCallback onRotateLeft, onRotateRight, onReset;

  const _TransformPanel({
    super.key,
    required this.current,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final deg = (current.rotation * 180 / math.pi).toStringAsFixed(1);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _Btn(icon: Icons.rotate_left_rounded, onTap: onRotateLeft, size: 26),
        Column(children: [
          Text('$deg°',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Text('rotation',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        _Btn(icon: Icons.rotate_right_rounded, onTap: onRotateRight, size: 26),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _chip('Zoom', '${(current.scale * 100).toStringAsFixed(0)}%'),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded,
              size: 16, color: Color(0xFF00E5FF)),
          label: const Text('Reset',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
        ),
      ]),
    ]);
  }

  static Widget _chip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      );
}

// -- Background panel ---------------------------------------------------------

class _BackgroundPanel extends StatelessWidget {
  final bool bgRemoved, removing;
  final VoidCallback onRemove, onRestore;

  const _BackgroundPanel({
    super.key,
    required this.bgRemoved,
    required this.removing,
    required this.onRemove,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        if (removing)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00E5FF))),
              SizedBox(width: 12),
              Text('Removing background…',
                  style: TextStyle(color: Colors.white70)),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!bgRemoved)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF00E5FF).withOpacity(0.15),
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Remove Background'),
                  onPressed: onRemove,
                )
              else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.15),
                    foregroundColor: Colors.greenAccent,
                    side: const BorderSide(color: Colors.greenAccent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('BG Removed'),
                  onPressed: null,
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white54,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: onRestore,
                  child: const Text('Restore'),
                ),
              ],
            ],
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.white38),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Uses Photoroom API if key is set, otherwise local flood-fill (works best on solid backgrounds)',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ]);
}

// -- Shared ------------------------------------------------------------------

class _EditorSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  const _EditorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(value.toStringAsFixed(2),
                style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00E5FF),
              overlayColor: const Color(0xFF00E5FF).withOpacity(0.12),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent, disabled;
  final double size;
  final String? tooltip;

  const _Btn({
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.disabled = false,
    this.size = 22,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Colors.white24
        : accent
            ? const Color(0xFF00E5FF)
            : Colors.white;
    final btn = GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: accent && !disabled
              ? const Color(0xFF00E5FF).withOpacity(0.15)
              : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: accent && !disabled
              ? Border.all(color: const Color(0xFF00E5FF), width: 1)
              : null,
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}