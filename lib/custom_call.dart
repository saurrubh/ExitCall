part of 'main.dart';

enum _CallPart {
  name('Caller name', 0, -.64, 36, 0xfff4eeff),
  number('Number', 0, -.48, 16, 0xffd4c6e9),
  status('Status', 0, .25, 15, 0xffd4c6e9),
  avatar('Avatar', 0, -.05, 112, 0xffc6aaff),
  answer('Answer', .65, .82, 58, 0xff9fe0bc),
  decline('Decline', -.65, .82, 58, 0xffffb2c0),
  end('End call', 0, .82, 58, 0xffffb2c0);

  const _CallPart(this.label, this.x, this.y, this.size, this.color);

  final String label;
  final double x;
  final double y;
  final double size;
  final int color;

  bool get isAction => this == answer || this == decline || this == end;
  double get minSize => isAction ? 48 : (this == avatar ? 36 : 10);
  double get maxSize => this == avatar ? 210 : (isAction ? 100 : 64);
  bool get canHide => this == number || this == status || this == avatar;
  String key(String property) => '${this.name}_$property';
}

enum _CallGesture {
  tap('Tap'),
  left('Swipe left'),
  right('Swipe right'),
  up('Swipe up'),
  down('Swipe down'),
  drag('Drag any direction');

  const _CallGesture(this.label);
  final String label;
}

class CallDesign {
  const CallDesign([this._values = const {}]);

  static const minButtonDimension = 24.0;
  static const maxButtonWidth = 360.0;
  static const maxButtonHeight = 320.0;
  static const minButtonContentSize = 8.0;
  static const maxButtonLabelSize = 72.0;
  static const maxButtonIconSize = 112.0;

  final Map<String, Object?> _values;

  factory CallDesign.decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const CallDesign();
    try {
      final values = jsonDecode(encoded);
      if (values is Map<String, Object?>) return CallDesign(values);
    } on FormatException {
      return const CallDesign();
    }
    return const CallDesign();
  }

  String encode() => jsonEncode(_values);

  CallDesign withValue(String key, Object value) =>
      CallDesign({..._values, key: value});

  CallDesign withPosition(_CallPart part, Alignment alignment) => CallDesign({
    ..._values,
    part.key('x'): alignment.x,
    part.key('y'): alignment.y,
  });

  double value(String key, double fallback, double min, double max) {
    final value = _values[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  int option(String key, int max) => value(key, 0, 0, max.toDouble()).toInt();

  bool flag(String key, {bool fallback = false}) =>
      _values[key] is bool ? _values[key] as bool : fallback;

  String text(String key, String fallback) {
    final value = _values[key];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  Color color(String key, int fallback) {
    final value = _values[key];
    return Color(value is int ? (value & 0xffffff) | 0xff000000 : fallback);
  }

  Color partColor(_CallPart part) => color(part.key('color'), part.color);
  Color get background => color('background', 0xff251d36);
  Color get backgroundEnd => color('background_end', 0xff111b2d);
  Color get actionInk => color('action_ink', 0xff251b37);
  Color get avatarInk => color('avatar_ink', 0xff251b37);
  bool get gradient => flag('gradient');
  bool visible(_CallPart part) => !part.canHide || !flag(part.key('hidden'));
  double size(_CallPart part) =>
      value(part.key('size'), part.size, part.minSize, part.maxSize);
  Size buttonSize(_CallPart part) {
    final originalSize = size(part);
    final originalWidth = option(part.key('shape'), 2) == 1
        ? originalSize
        : originalSize * 1.8;
    return Size(
      value(
        part.key('width'),
        originalWidth,
        minButtonDimension,
        maxButtonWidth,
      ),
      value(
        part.key('height'),
        originalSize,
        minButtonDimension,
        maxButtonHeight,
      ),
    );
  }

  double buttonLabelSize(_CallPart part) => value(
    part.key('label_size'),
    size(part) * .23,
    minButtonContentSize,
    maxButtonLabelSize,
  );

  double buttonIconSize(_CallPart part) => value(
    part.key('icon_size'),
    size(part) * .37,
    minButtonContentSize,
    maxButtonIconSize,
  );

  Alignment position(_CallPart part) => Alignment(
    value(part.key('x'), part.x, -1, 1),
    value(part.key('y'), part.y, -1, 1),
  );
  _CallGesture gesture(_CallPart part) =>
      _CallGesture.values[option(
        part.key('gesture'),
        _CallGesture.values.length - 1,
      )];

  BoxDecoration get backdrop {
    if (!gradient) return BoxDecoration(color: background);
    final direction = switch (option('gradient_direction', 2)) {
      1 => (Alignment.centerLeft, Alignment.centerRight),
      2 => (Alignment.topLeft, Alignment.bottomRight),
      _ => (Alignment.topCenter, Alignment.bottomCenter),
    };
    return BoxDecoration(
      gradient: LinearGradient(
        begin: direction.$1,
        end: direction.$2,
        colors: [background, backgroundEnd],
      ),
    );
  }
}

class _CustomCallScreen extends StatelessWidget {
  const _CustomCallScreen({
    required this.design,
    required this.name,
    required this.number,
    required this.elapsed,
    required this.onAnswer,
    required this.onEnd,
    this.editingPart,
    this.onSelect,
    this.onMove,
    this.scale = 1,
  });

  final CallDesign design;
  final String name;
  final String number;
  final String? elapsed;
  final VoidCallback onAnswer;
  final VoidCallback onEnd;
  final _CallPart? editingPart;
  final ValueChanged<_CallPart>? onSelect;
  final void Function(_CallPart, Offset)? onMove;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(design.background) ==
        Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: DecoratedBox(
        decoration: design.backdrop,
        child: SafeArea(
          minimum: EdgeInsets.all(12 * scale),
          child: LayoutBuilder(
            builder: (context, viewport) {
              final ratio = scale == 1
                  ? (viewport.maxWidth / 280).clamp(.55, 1.0)
                  : scale;
              final parts = _CallPart.values.where((part) {
                if (!design.visible(part)) return false;
                if (part == _CallPart.number && number.isEmpty) return false;
                if (part == _CallPart.end) return elapsed != null;
                if (part.isAction) return elapsed == null;
                return true;
              });
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (final part in parts)
                    Align(
                      alignment: design.position(part),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: viewport.maxWidth,
                        ),
                        child: _element(context, viewport, part, ratio),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _element(
    BuildContext context,
    BoxConstraints viewport,
    _CallPart part,
    double ratio,
  ) {
    final size = design.size(part) * ratio;
    final editing = onSelect != null;
    final color = design.partColor(part);
    final Widget content;
    if (part.isAction) {
      content = _action(part, ratio, color, editing);
    } else if (part == _CallPart.avatar) {
      final initial = name.trim().isEmpty
          ? '?'
          : String.fromCharCode(name.trim().runes.first);
      content = Container(
        alignment: Alignment.center,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(
            design.option('avatar_shape', 1) == 0 ? size / 2 : size * .19,
          ),
        ),
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(color: design.avatarInk, fontSize: size * .43),
        ),
      );
    } else {
      final value = switch (part) {
        _CallPart.name => name,
        _CallPart.number => number,
        _ => elapsed ?? design.text('status_label', 'Incoming call'),
      };
      content = Text(
        value,
        textAlign: switch (design.option(part.key('align'), 2)) {
          1 => TextAlign.left,
          2 => TextAlign.right,
          _ => TextAlign.center,
        },
        maxLines: part == _CallPart.name ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          height: 1.14,
          fontSize: size,
          fontWeight:
              design.flag(part.key('bold'), fallback: part == _CallPart.name)
              ? FontWeight.w700
              : FontWeight.w400,
          fontFamily: switch (design.option(part.key('font'), 2)) {
            1 => 'serif',
            2 => 'monospace',
            _ => null,
          },
        ),
      );
    }
    if (!editing) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect!(part),
      onPanStart: (_) => onSelect!(part),
      onPanUpdate: (details) => onMove!(
        part,
        Offset(
          details.delta.dx * 2 / viewport.maxWidth,
          details.delta.dy * 2 / viewport.maxHeight,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: editingPart == part
              ? Border.all(color: const Color(0xff80dafa))
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: content,
      ),
    );
  }

  Widget _action(_CallPart part, double scale, Color color, bool editing) {
    final label = design.text(part.key('label'), part.label);
    final gesture = design.gesture(part);
    final shape = design.option(part.key('shape'), 2);
    final display = design.option(part.key('display'), 2);
    final ink = design.color(part.key('ink'), design.actionInk.toARGB32());
    final action = part == _CallPart.answer ? onAnswer : onEnd;
    final dimensions = design.buttonSize(part) * scale;
    final radius = dimensions.shortestSide * (shape == 2 ? .2 : .5);
    final face = Container(
      width: dimensions.width,
      height: dimensions.height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dimensions.width - 10 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (display != 2)
                Icon(
                  part == _CallPart.answer
                      ? Icons.call_rounded
                      : Icons.call_end_rounded,
                  size: design.buttonIconSize(part) * scale,
                  color: ink,
                ),
              if (display != 1)
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: design.buttonLabelSize(part) * scale,
                    height: 1.08,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (editing) return face;
    Widget button = Semantics(
      button: true,
      label: label,
      hint: gesture == _CallGesture.tap ? null : gesture.label,
      onTap: action,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: action,
          child: face,
        ),
      ),
    );
    if (gesture == _CallGesture.tap) return button;
    return _CallDrag(
      direction: switch (gesture) {
        _CallGesture.up => _DragDirection.up,
        _CallGesture.down => _DragDirection.down,
        _CallGesture.drag => _DragDirection.any,
        _ => _DragDirection.horizontal,
      },
      onCommit: gesture == _CallGesture.left ? null : action,
      onReverse: gesture == _CallGesture.left ? action : null,
      builder: (offset) => Transform.translate(
        offset: Offset(
          offset.dx.clamp(-24, 24).toDouble(),
          offset.dy.clamp(-24, 24).toDouble(),
        ),
        child: button,
      ),
    );
  }
}
