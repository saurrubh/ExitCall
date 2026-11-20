part of 'main.dart';

class IncomingCall extends StatefulWidget {
  const IncomingCall({
    super.key,
    required this.name,
    required this.number,
    required this.preset,
    this.expires,
    this.design = const CallDesign(),
  });

  final String name;
  final String number;
  final int preset;
  final DateTime? expires;
  final CallDesign design;

  @override
  State<IncomingCall> createState() => _IncomingCallState();
}

class _IncomingCallState extends State<IncomingCall> {
  static const googleInk = Color(0xff223045);
  static const googleMuted = Color(0xff47586d);
  static const blue = Color(0xffb9d6fb);
  static const mint = Color(0xff8de1bb);
  static const rose = Color(0xffffb1b7);
  static const gold = Color(0xffffcf88);

  final _stopwatch = Stopwatch();
  Timer? _timer;
  bool _finishing = false;

  bool get _preview => widget.expires == null;
  bool get _connected => _stopwatch.isRunning;
  String get _name => widget.name.isEmpty ? 'Unknown caller' : widget.name;
  String get _initial => String.fromCharCode(_name.runes.first).toUpperCase();

  @override
  void initState() {
    super.initState();
    final expires = widget.expires;
    if (expires != null) {
      _timer = Timer(expires.difference(DateTime.now()), _finish);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_finishing || !mounted) return;
    _finishing = true;
    _timer?.cancel();
    if (_preview) {
      Navigator.of(context).pop();
    } else {
      unawaited(calls.invokeMethod<void>('finish'));
    }
  }

  void _answer() {
    if (_connected || _finishing) return;
    _timer?.cancel();
    if (!_preview) unawaited(calls.invokeMethod<void>('silence'));
    setState(_stopwatch.start);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  String get _elapsed {
    final seconds = _stopwatch.elapsed.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final light = widget.preset == 0;
    final colors = switch (widget.preset) {
      0 => const [Color(0xffe5eef9), Color(0xfff9f6fb), Color(0xffe4f0ee)],
      1 => const [Color(0xff263f67), Color(0xff14233a), Color(0xff101724)],
      2 => const [Color(0xff173e37), Color(0xff122a27), Color(0xff142021)],
      _ => const [Color(0xff4a3322), Color(0xff211a1a), Color(0xff15121a)],
    };
    final labelColor = switch (widget.preset) {
      0 => googleMuted,
      1 => blue,
      2 => mint,
      _ => gold,
    };
    return PopScope(
      canPop: _preview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: widget.preset == customPreset
          ? Scaffold(
              body: _CustomCallScreen(
                design: widget.design,
                name: _name,
                number: widget.number,
                elapsed: _connected ? _elapsed : null,
                onAnswer: _answer,
                onEnd: _finish,
              ),
            )
          : Scaffold(
              body: AnnotatedRegion<SystemUiOverlayStyle>(
                value: light
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors,
                    ),
                  ),
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, viewport) => SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 448,
                              minHeight: viewport.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  20,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _preview
                                          ? 'Preview · ${presets[widget.preset]}'
                                          : 'Exit Call',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: labelColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Spacer(flex: 3),
                                    _caller(context, labelColor),
                                    const SizedBox(height: 32),
                                    const Spacer(flex: 4),
                                    _controls(labelColor),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _caller(BuildContext context, Color accent) {
    final light = widget.preset == 0;
    final voice = widget.preset == 2;
    final textColor = light ? googleInk : const Color(0xfff4f7ff);
    final secondary = light ? googleMuted : const Color(0xffc2d0d1);
    final status = Text(
      _connected ? _elapsed : (voice ? 'Incoming voice call' : 'Incoming call'),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: accent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final details = Column(
      children: [
        Text(
          _name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (widget.number.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            widget.number,
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: 15),
          ),
        ],
      ],
    );
    return Column(
      children: [
        if (light) ...[
          status,
          const SizedBox(height: 14),
          details,
          const SizedBox(height: 28),
          _avatar(),
        ] else if (voice) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xff28483f),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_calling_3_outlined, color: accent, size: 17),
                  const SizedBox(width: 7),
                  Flexible(child: status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _avatar(),
          const SizedBox(height: 23),
          details,
        ] else ...[
          _avatar(),
          const SizedBox(height: 23),
          details,
          const SizedBox(height: 12),
          status,
        ],
      ],
    );
  }

  Widget _avatar() {
    final (size, fill, text) = switch (widget.preset) {
      0 => (146.0, const Color(0xffb9d2e9), googleInk),
      1 => (112.0, const Color(0xff52739f), Colors.white),
      2 => (116.0, const Color(0xff316254), const Color(0xffd5f5e4)),
      _ => (104.0, gold, const Color(0xff493423)),
    };
    final shape = widget.preset == 0
        ? const BorderRadius.only(
            topLeft: Radius.circular(54),
            topRight: Radius.circular(32),
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(54),
          )
        : BorderRadius.circular(size / 2);
    return ExcludeSemantics(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: fill.withValues(alpha: .48)),
            borderRadius: widget.preset == 0
                ? const BorderRadius.only(
                    topLeft: Radius.circular(66),
                    topRight: Radius.circular(42),
                    bottomLeft: Radius.circular(42),
                    bottomRight: Radius.circular(66),
                  )
                : BorderRadius.circular(size / 2 + 12),
            color: fill.withValues(alpha: .13),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(fill, Colors.white, .15)!, fill],
                ),
              ),
              child: Text(
                _initial,
                style: TextStyle(
                  color: text,
                  fontSize: size * .43,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(Color accent) {
    if (_connected) {
      return Center(
        child: _button('End call', Icons.call_end_rounded, rose, _finish),
      );
    }
    switch (widget.preset) {
      case 0:
        return _googleControls();
      case 1:
        return _pairedControls(
          hint: 'Drag a control to answer or decline',
          drag: _DragDirection.any,
        );
      case 2:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff203833),
            border: Border.all(color: const Color(0xff35554a)),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
            child: _pairedControls(
              hint: 'Swipe up or tap',
              drag: _DragDirection.up,
            ),
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _button('Answer', Icons.call_rounded, accent, _answer),
            const SizedBox(height: 8),
            _button('Decline', Icons.call_end_rounded, rose, _finish),
          ],
        );
    }
  }

  Widget _googleControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Swipe left to decline or right to answer',
          textAlign: TextAlign.center,
          style: TextStyle(color: googleMuted, fontSize: 13),
        ),
        const SizedBox(height: 9),
        _CallDrag(
          direction: _DragDirection.horizontal,
          onCommit: _answer,
          onReverse: _finish,
          builder: (offset) => Container(
            padding: const EdgeInsets.all(6),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xffd9e5f1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Expanded(
                      child: _trackAction(
                        'Decline',
                        const Color(0xff753f4d),
                        const Color(0xffebdee7),
                        _finish,
                      ),
                    ),
                    const SizedBox(width: 68),
                    Expanded(
                      child: _trackAction(
                        'Answer',
                        const Color(0xff275b4e),
                        const Color(0xffd4e7e3),
                        _answer,
                      ),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(offset.dx.clamp(-78.0, 78.0), 0),
                        child: Container(
                          alignment: Alignment.center,
                          width: 54,
                          height: 44,
                          decoration: BoxDecoration(
                            color: offset.dx < -12
                                ? const Color(0xff733848)
                                : googleInk,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            offset.dx < -12
                                ? Icons.call_end_rounded
                                : Icons.call_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trackAction(
    String label,
    Color foreground,
    Color background,
    VoidCallback action,
  ) {
    return TextButton(
      onPressed: action,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  Widget _pairedControls({required String hint, required _DragDirection drag}) {
    final voice = drag == _DragDirection.up;
    final answer = _roundControl(
      'Answer',
      Icons.call_rounded,
      mint,
      drag,
      _answer,
    );
    final decline = _roundControl(
      'Decline',
      Icons.call_end_rounded,
      rose,
      drag,
      _finish,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: voice ? decline : answer),
            Expanded(child: voice ? answer : decline),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xffc2d0d1), fontSize: 13),
        ),
      ],
    );
  }

  Widget _roundControl(
    String label,
    IconData icon,
    Color tint,
    _DragDirection direction,
    VoidCallback action,
  ) {
    final voice = direction == _DragDirection.up;
    return _CallDrag(
      direction: direction,
      onCommit: action,
      builder: (offset) => Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: action,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Column(
                children: [
                  if (voice)
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: tint,
                      size: 22,
                    ),
                  Transform.translate(
                    offset: Offset(
                      offset.dx.clamp(-23.0, 23.0),
                      offset.dy.clamp(-23.0, 23.0),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(voice ? 4 : 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tint.withValues(alpha: .43)),
                        color: tint.withValues(alpha: .09),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tint,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Icon(
                            icon,
                            color: const Color(0xff172721),
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String label,
    IconData icon,
    Color color,
    VoidCallback action,
  ) {
    return FilledButton.icon(
      onPressed: action,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: const Color(0xff222435),
        minimumSize: const Size(48, 52),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, textAlign: TextAlign.center),
    );
  }
}

enum _DragDirection { horizontal, any, up, down }

class _CallDrag extends StatefulWidget {
  const _CallDrag({
    required this.direction,
    required this.onCommit,
    required this.builder,
    this.onReverse,
  });

  final _DragDirection direction;
  final VoidCallback? onCommit;
  final VoidCallback? onReverse;
  final Widget Function(Offset offset) builder;

  @override
  State<_CallDrag> createState() => _CallDragState();
}

class _CallDragState extends State<_CallDrag> {
  Offset _offset = Offset.zero;

  void _move(DragUpdateDetails details) {
    setState(() => _offset += details.delta);
  }

  void _reset() {
    if (_offset != Offset.zero) setState(() => _offset = Offset.zero);
  }

  void _end(DragEndDetails _) {
    const threshold = 42.0;
    final forward = switch (widget.direction) {
      _DragDirection.horizontal => _offset.dx,
      _DragDirection.any => _offset.distance,
      _DragDirection.up => -_offset.dy,
      _DragDirection.down => _offset.dy,
    };
    _reset();
    final action = forward >= threshold
        ? widget.onCommit
        : forward <= -threshold
        ? widget.onReverse
        : null;
    if (action != null) {
      unawaited(HapticFeedback.selectionClick());
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.direction == _DragDirection.horizontal;
    final upward = widget.direction == _DragDirection.up;
    final vertical = upward || widget.direction == _DragDirection.down;
    final free = widget.direction == _DragDirection.any;
    final displayOffset = upward
        ? Offset(0, _offset.dy.clamp(-23.0, 0.0))
        : _offset;
    return GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: horizontal ? _move : null,
      onHorizontalDragEnd: horizontal ? _end : null,
      onHorizontalDragCancel: horizontal ? _reset : null,
      onVerticalDragUpdate: vertical ? _move : null,
      onVerticalDragEnd: vertical ? _end : null,
      onVerticalDragCancel: vertical ? _reset : null,
      onPanUpdate: free ? _move : null,
      onPanEnd: free ? _end : null,
      onPanCancel: free ? _reset : null,
      child: widget.builder(displayOffset),
    );
  }
}
