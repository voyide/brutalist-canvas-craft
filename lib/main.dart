import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BrutalistDrawingApp());
}

class BrutalistDrawingApp extends StatelessWidget {
  const BrutalistDrawingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRUTAL CANVAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFEBEBEB),
        fontFamily: 'monospace',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
      ),
      home: const CanvasStudioScreen(),
    );
  }
}

enum DrawingTool { pen, highlighter, eraser, line, rectangle, circle }

class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;
  final double opacity;

  DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    this.opacity = 1.0,
  });
}

class CanvasStudioScreen extends StatefulWidget {
  const CanvasStudioScreen({Key? key}) : super(key: key);

  @override
  State<CanvasStudioScreen> createState() => _CanvasStudioScreenState();
}

class _CanvasStudioScreenState extends State<CanvasStudioScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<DrawnPath> _paths = [];
  final List<DrawnPath> _undonePaths = [];

  DrawingTool _selectedTool = DrawingTool.pen;
  Color _selectedColor = const Color(0xFF000000);
  double _strokeWidth = 6.0;
  double _opacity = 1.0;

  final List<Color> _palette = [
    const Color(0xFF000000), // Pure Black
    const Color(0xFFFF0055), // Radical Red
    const Color(0xFFFFE500), // Neo Yellow
    const Color(0xFF00F0FF), // Electric Cyan
    const Color(0xFF00FF66), // Cyber Lime
    const Color(0xFF7000FF), // Deep Violet
    const Color(0xFFFF6B00), // Blaze Orange
    const Color(0xFFFFFFFF), // Pure White
  ];

  void _onPanStart(DragStartDetails details) {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset localPosition = details.localPosition;

    setState(() {
      _undonePaths.clear();
      _paths.add(
        DrawnPath(
          points: [localPosition],
          color: _selectedTool == DrawingTool.eraser ? const Color(0xFFFFFFFF) : _selectedColor,
          strokeWidth: _selectedTool == DrawingTool.eraser ? _strokeWidth * 2.5 : _strokeWidth,
          tool: _selectedTool,
          opacity: _selectedTool == DrawingTool.highlighter ? 0.35 : _opacity,
        ),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset localPosition = details.localPosition;

    setState(() {
      if (_paths.isNotEmpty) {
        if (_selectedTool == DrawingTool.line ||
            _selectedTool == DrawingTool.rectangle ||
            _selectedTool == DrawingTool.circle) {
          if (_paths.last.points.length > 1) {
            _paths.last.points.removeLast();
          }
          _paths.last.points.add(localPosition);
        } else {
          _paths.last.points.add(localPosition);
        }
      }
    });
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _undonePaths.add(_paths.removeLast());
      });
    }
  }

  void _redo() {
    if (_undonePaths.isNotEmpty) {
      setState(() {
        _paths.add(_undonePaths.removeLast());
      });
    }
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => BrutalistDialog(
        title: 'NUKE CANVAS?',
        content: 'This will irreversibly delete all drawing strokes.',
        confirmLabel: 'CLEAR',
        onConfirm: () {
          setState(() {
            _paths.clear();
            _undonePaths.clear();
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _exportCanvas() async {
    try {
      RenderRepaintBoundary boundary =
          _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FF66),
            content: Text(
              'SNAPSHOT CAPTURED [${byteData.lengthInBytes} BYTES]',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: Border.all(color: Colors.black, width: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF0055),
          content: Text('EXPORT ERROR: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F0),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              // TOP HEADER & CONTROLS
              _buildTopBar(),
              const SizedBox(height: 10),

              // MAIN CANVAS AREA
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 3.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
                    ],
                  ),
                  child: ClipRect(
                    child: RepaintBoundary(
                      key: _canvasKey,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        child: CustomPaint(
                          painter: CanvasPainter(paths: _paths),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // STROKE CONTROLLER BAR
              _buildStrokeControlBar(),
              const SizedBox(height: 10),

              // TOOL SELECTION & COLOR PALETTE DOCK
              _buildBottomToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE500),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'CANVAS:CRAFT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              _buildIconButton(Icons.undo, _undo, enabled: _paths.isNotEmpty),
              const SizedBox(width: 6),
              _buildIconButton(Icons.redo, _redo, enabled: _undonePaths.isNotEmpty),
              const SizedBox(width: 6),
              _buildIconButton(Icons.delete_forever, _clearCanvas, color: const Color(0xFFFF0055)),
              const SizedBox(width: 6),
              _buildIconButton(Icons.save_alt, _exportCanvas, color: const Color(0xFF00F0FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, {bool enabled = true, Color? color}) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? (color ?? Colors.white) : const Color(0xFFCCCCCC),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: enabled
              ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)]
              : [],
        ),
        child: Icon(icon, size: 20, color: enabled ? Colors.black : const Color(0xFF777777)),
      ),
    );
  }

  Widget _buildStrokeControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)],
      ),
      child: Row(
        children: [
          const Text('SIZE:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.black,
                inactiveTrackColor: const Color(0xFFDDDDDD),
                thumbColor: const Color(0xFFFF0055),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _strokeWidth,
                min: 2.0,
                max: 40.0,
                onChanged: (val) => setState(() => _strokeWidth = val),
              ),
            ),
          ),
          Container(
            width: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Text(
              _strokeWidth.toInt().toString(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0)],
      ),
      child: Column(
        children: [
          // TOOLS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolButton(DrawingTool.pen, Icons.edit, 'PEN'),
              _buildToolButton(DrawingTool.highlighter, Icons.brush, 'GLOW'),
              _buildToolButton(DrawingTool.eraser, Icons.auto_fix_normal, 'ERASE'),
              _buildToolButton(DrawingTool.line, Icons.timeline, 'LINE'),
              _buildToolButton(DrawingTool.rectangle, Icons.crop_square, 'RECT'),
              _buildToolButton(DrawingTool.circle, Icons.circle_outlined, 'CIRC'),
            ],
          ),
          const SizedBox(height: 10),
          // COLOR SWATCHES
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _palette.map((color) {
                final isSelected = _selectedColor == color && _selectedTool != DrawingTool.eraser;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      if (_selectedTool == DrawingTool.eraser) {
                        _selectedTool = DrawingTool.pen;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: Colors.black,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: isSelected
                          ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)]
                          : [],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(DrawingTool tool, IconData icon, String label) {
    final bool isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () => setState(() => _selectedTool = tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF0055) : const Color(0xFFEEEEEE),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: isSelected
              ? const [BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<DrawnPath> paths;

  CanvasPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..color = path.color.withOpacity(path.opacity)
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (path.tool == DrawingTool.eraser) {
        paint.blendMode = BlendMode.src;
        paint.color = Colors.white;
      }

      if (path.tool == DrawingTool.line) {
        if (path.points.length >= 2) {
          canvas.drawLine(path.points.first, path.points.last, paint);
        }
      } else if (path.tool == DrawingTool.rectangle) {
        if (path.points.length >= 2) {
          final rect = Rect.fromPoints(path.points.first, path.points.last);
          canvas.drawRect(rect, paint);
        }
      } else if (path.tool == DrawingTool.circle) {
        if (path.points.length >= 2) {
          final center = path.points.first;
          final radius = (path.points.last - center).distance;
          canvas.drawCircle(center, radius, paint);
        }
      } else {
        if (path.points.length == 1) {
          canvas.drawPoints(ui.PointMode.points, [path.points.first], paint);
        } else {
          final p = Path();
          p.moveTo(path.points[0].dx, path.points[0].dy);
          for (int i = 1; i < path.points.length; i++) {
            p.lineTo(path.points[i].dx, path.points[i].dy);
          }
          canvas.drawPath(p, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}

class BrutalistDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const BrutalistDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6), blurRadius: 0)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      border: Border.all(color: Colors.black, width: 2.5),
                    ),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0055),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0)
                      ],
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
