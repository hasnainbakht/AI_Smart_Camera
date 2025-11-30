import 'package:flutter/material.dart';

typedef OverlayOptionsChanged = void Function(OverlayOptions options);

class OverlayOptions {
  final bool showRuleOfThirds;
  final bool showGoldenRatio;
  final bool showCenterCross;
  final double opacity;
  final double strokeWidth;

  const OverlayOptions({ // <- mark as const
    required this.showRuleOfThirds,
    required this.showGoldenRatio,
    required this.showCenterCross,
    required this.opacity,
    required this.strokeWidth,
  });

  OverlayOptions copyWith({
    bool? showRuleOfThirds,
    bool? showGoldenRatio,
    bool? showCenterCross,
    double? opacity,
    double? strokeWidth,
  }) {
    return OverlayOptions(
      showRuleOfThirds: showRuleOfThirds ?? this.showRuleOfThirds,
      showGoldenRatio: showGoldenRatio ?? this.showGoldenRatio,
      showCenterCross: showCenterCross ?? this.showCenterCross,
      opacity: opacity ?? this.opacity,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}


class OverlaySelector extends StatefulWidget {
  final OverlayOptions initial;
  final OverlayOptionsChanged? onChanged;

  const OverlaySelector({
    Key? key,
    this.onChanged,
    this.initial = const OverlayOptions(
      showRuleOfThirds: true,
      showGoldenRatio: false,
      showCenterCross: false,
      opacity: 0.8,
      strokeWidth: 1.0,
    ),
  }) : super(key: key);

  @override
  State<OverlaySelector> createState() => _OverlaySelectorState();
}

class _OverlaySelectorState extends State<OverlaySelector> {
  late OverlayOptions options;

  @override
  void initState() {
    super.initState();
    options = widget.initial;
  }

  void _emit() {
    widget.onChanged?.call(options);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // semi-transparent card to sit on top of camera preview
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggles
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rule of Thirds', style: TextStyle(color: Colors.white)),
                  value: options.showRuleOfThirds,
                  onChanged: (v) => setState(() {
                    options = options.copyWith(showRuleOfThirds: v);
                    _emit();
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Golden Ratio', style: TextStyle(color: Colors.white)),
                  value: options.showGoldenRatio,
                  onChanged: (v) => setState(() {
                    options = options.copyWith(showGoldenRatio: v);
                    _emit();
                  }),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Center Guide', style: TextStyle(color: Colors.white)),
                  value: options.showCenterCross,
                  onChanged: (v) => setState(() {
                    options = options.copyWith(showCenterCross: v);
                    _emit();
                  }),
                ),
              ),
            ],
          ),

          // Opacity slider
          Row(
            children: [
              const Text('Opacity', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: options.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (v) => setState(() {
                    options = options.copyWith(opacity: v);
                    _emit();
                  }),
                ),
              ),
            ],
          ),

          // Stroke width slider
          Row(
            children: [
              const Text('Width', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: options.strokeWidth,
                  min: 0.5,
                  max: 4.0,
                  divisions: 7,
                  onChanged: (v) => setState(() {
                    options = options.copyWith(strokeWidth: v);
                    _emit();
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
