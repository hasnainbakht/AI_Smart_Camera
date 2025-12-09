// edit_image_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
// lib/screens/image_editor_screen.dart
import 'package:flutter/material.dart';

class ImageEditorScreen extends StatelessWidget {
  const ImageEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
        backgroundColor: Colors.black87,
      ),
      backgroundColor: Colors.black,
      body: const Center(
        child: Text(
          'Image Editor Here',
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}

class EditImageScreen extends StatefulWidget {
  final String imagePath;
  const EditImageScreen({super.key, required this.imagePath});

  @override
  State<EditImageScreen> createState() => _EditImageScreenState();
}

class _EditImageScreenState extends State<EditImageScreen>
    with TickerProviderStateMixin {
  late ui.Image _image;
  bool _loading = true;

  // Filter controls
  double brightness = 0;
  double contrast = 1;
  double saturation = 1;

  // Crop & rotate
  double rotation = 0;
  double scale = 1;
  Offset offset = Offset.zero;

  // Undo / redo
  final List<Map<String, dynamic>> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadImage(widget.imagePath);
  }

  Future<void> _loadImage(String path) async {
    final bytes = await rootBundle.load(path); // use File(path).readAsBytes() for real files
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
      _loading = false;
      _pushHistory();
    });
  }

  void _pushHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add({
      "brightness": brightness,
      "contrast": contrast,
      "saturation": saturation,
      "rotation": rotation,
      "scale": scale,
      "offset": offset,
    });
    _historyIndex++;
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    _applyHistory();
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    _applyHistory();
  }

  void _applyHistory() {
    final state = _history[_historyIndex];
    setState(() {
      brightness = state["brightness"];
      contrast = state["contrast"];
      saturation = state["saturation"];
      rotation = state["rotation"];
      scale = state["scale"];
      offset = state["offset"];
    });
  }

  ColorFilter _buildColorFilter() {
    final b = brightness;
    final c = contrast;
    final s = saturation;
    // basic matrix combining
    return ColorFilter.matrix([
      c * s, 0, 0, 0, b * 255,
      0, c * s, 0, 0, b * 255,
      0, 0, c * s, 0, b * 255,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ===== IMAGE AREA =====
                Positioned.fill(
                  child: GestureDetector(
                    onScaleUpdate: (details) {
                      setState(() {
                        scale = (scale * details.scale).clamp(0.5, 5.0);
                        offset += details.focalPointDelta;
                      });
                    },
                    child: Center(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translate(offset.dx, offset.dy)
                          ..scale(scale)
                          ..rotateZ(rotation),
                        child: ColorFiltered(
                          colorFilter: _buildColorFilter(),
                          child: RawImage(image: _image),
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== TOP BAR =====
                Positioned(
                  top: mq.padding.top + 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _iconButton(Icons.arrow_back, () => context.go("/home")),
                      Text("Edit Image",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _iconButton(Icons.undo, _undo),
                          const SizedBox(width: 10),
                          _iconButton(Icons.redo, _redo),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===== BOTTOM TOOLS =====
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        )),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Filters
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _filterButton("Normal", 1, 1, 0),
                            _filterButton("BW", 0, 1, 0),
                            _filterButton("Bright", 1.2, 1, 0.2),
                            _filterButton("Vintage", 0.9, 1.1, 0.9),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Sliders
                        _slider("Brightness", brightness, -1, 1, (v) {
                          setState(() => brightness = v);
                        }),
                        _slider("Contrast", contrast, 0, 3, (v) {
                          setState(() => contrast = v);
                        }),
                        _slider("Saturation", saturation, 0, 3, (v) {
                          setState(() => saturation = v);
                        }),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _iconButton(Icons.rotate_left, () {
                              setState(() {
                                rotation -= 0.1;
                                _pushHistory();
                              });
                            }),
                            _iconButton(Icons.rotate_right, () {
                              setState(() {
                                rotation += 0.1;
                                _pushHistory();
                              });
                            }),
                            _iconButton(Icons.save_alt, () {
                              // TODO: Save image
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ],
      );

  Widget _filterButton(String label, double c, double s, double b) => GestureDetector(
        onTap: () {
          setState(() {
            contrast = c;
            saturation = s;
            brightness = b;
            _pushHistory();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
      );

  Widget _iconButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}
