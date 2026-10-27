import 'package:flutter/material.dart';

/// A desktop-optimized split layout widget with a draggable divider
/// between the left and right panels.
class SplitLayoutBuilder extends StatefulWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;

  const SplitLayoutBuilder({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.initialRatio = 0.52,
    this.minRatio = 0.30,
    this.maxRatio = 0.75,
  });

  @override
  State<SplitLayoutBuilder> createState() => _SplitLayoutBuilderState();
}

class _SplitLayoutBuilderState extends State<SplitLayoutBuilder> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If window is very narrow (e.g. snapped to quarter screen), stack vertically
        if (constraints.maxWidth < 750) {
          return Column(
            children: [
              Expanded(child: widget.leftChild),
              const Divider(height: 1, thickness: 1),
              Expanded(child: widget.rightChild),
            ],
          );
        }

        final totalWidth = constraints.maxWidth;
        final leftWidth = (totalWidth * _ratio).clamp(
          totalWidth * widget.minRatio,
          totalWidth * widget.maxRatio,
        );
        final rightWidth = (totalWidth - leftWidth - 8).clamp(200.0, totalWidth);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Panel
            SizedBox(
              width: leftWidth,
              child: widget.leftChild,
            ),

            // Draggable Divider Bar
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _ratio += details.delta.dx / totalWidth;
                    _ratio = _ratio.clamp(widget.minRatio, widget.maxRatio);
                  });
                },
                child: Container(
                  width: 8,
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary.withAlpha(77)
                      : Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 2,
                    height: double.infinity,
                    color: _isDragging
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerTheme.color ?? const Color(0xFF374151),
                  ),
                ),
              ),
            ),

            // Right Panel
            Expanded(
              child: SizedBox(
                width: rightWidth,
                child: widget.rightChild,
              ),
            ),
          ],
        );
      },
    );
  }
}
