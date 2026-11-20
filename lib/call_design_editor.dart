part of 'main.dart';

class _CallDesignEditor extends StatefulWidget {
  const _CallDesignEditor({
    required this.design,
    required this.name,
    required this.number,
  });

  final CallDesign design;
  final String name;
  final String number;

  @override
  State<_CallDesignEditor> createState() => _CallDesignEditorState();
}

class _CallDesignEditorState extends State<_CallDesignEditor> {
  late CallDesign _design = widget.design;
  _CallPart _part = _CallPart.name;
  bool _answered = false;
  int _resetVersion = 0;

  void _set(String key, Object value) =>
      setState(() => _design = _design.withValue(key, value));

  void _select(_CallPart part) {
    setState(() {
      _part = part;
      if (part.isAction) _answered = part == _CallPart.end;
    });
  }

  void _move(_CallPart part, Offset delta) {
    final position = _design.position(part);
    setState(() {
      _design = _design.withPosition(
        part,
        Alignment(
          (position.x + delta.dx).clamp(-1.0, 1.0),
          (position.y + delta.dy).clamp(-1.0, 1.0),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customize call'),
          actions: [
            IconButton(
              tooltip: 'Reset design',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => setState(() {
                _design = const CallDesign();
                _resetVersion++;
              }),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _design),
              child: const Text('Save'),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final previewHeight = (viewport.maxHeight * .44).clamp(
                0.0,
                390.0,
              );
              return Column(
                children: [
                  if (viewport.maxHeight >= 280) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Incoming')),
                          ButtonSegment(value: true, label: Text('Answered')),
                        ],
                        selected: {_answered},
                        onSelectionChanged: (value) =>
                            setState(() => _answered = value.single),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width:
                              previewHeight *
                              (screen.width / screen.height).clamp(.44, .88),
                          height: previewHeight,
                          child: _CustomCallScreen(
                            design: _design,
                            name: widget.name,
                            number: widget.number.isEmpty
                                ? '555 010 1234'
                                : widget.number,
                            elapsed: _answered ? '00:12' : null,
                            onAnswer: () {},
                            onEnd: () {},
                            editingPart: _part,
                            onSelect: _select,
                            onMove: _move,
                            scale: (previewHeight / screen.height).clamp(
                              .26,
                              .64,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const TabBar(
                    tabs: [
                      Tab(text: 'Layout'),
                      Tab(text: 'Colors'),
                      Tab(text: 'Controls'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _panel(_layout()),
                        _panel(_colors()),
                        _panel(_controls()),
                      ],
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

  Widget _panel(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: children,
  );

  List<Widget> _layout() {
    final part = _part;
    final position = _design.position(part);
    final visible = _design.visible(part);
    return [
      const Text('Drag an item in the preview or adjust its position below.'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 7,
        runSpacing: 4,
        children: [
          for (final item in _CallPart.values)
            ChoiceChip(
              label: Text(item.label),
              selected: part == item,
              onSelected: (_) => _select(item),
            ),
        ],
      ),
      if (part.canHide)
        SwitchListTile(
          title: Text('Show ${part.label.toLowerCase()}'),
          contentPadding: EdgeInsets.zero,
          value: visible,
          onChanged: (value) => _set(part.key('hidden'), !value),
        ),
      if (visible) ...[
        _slider(
          'Horizontal position',
          (position.x + 1) * 50,
          0,
          100,
          (value) => _set(part.key('x'), value / 50 - 1),
          suffix: '%',
        ),
        _slider(
          'Vertical position',
          (position.y + 1) * 50,
          0,
          100,
          (value) => _set(part.key('y'), value / 50 - 1),
          suffix: '%',
        ),
        if (part.isAction)
          ..._buttonDimensions(part)
        else
          _slider(
            part == _CallPart.avatar ? 'Size' : 'Text size',
            _design.size(part),
            part.minSize,
            part.maxSize,
            (value) => _set(part.key('size'), value),
          ),
        if (part == _CallPart.avatar)
          _option('Avatar shape', 'avatar_shape', const [
            'Circle',
            'Rounded square',
          ]),
        if (part == _CallPart.status)
          _labelField(
            'Incoming status text',
            'status_label',
            'Incoming call',
            40,
          ),
        if (!part.isAction && part != _CallPart.avatar) ...[
          _option('Typeface', part.key('font'), const [
            'System',
            'Serif',
            'Monospace',
          ]),
          _option('Text alignment', part.key('align'), const [
            'Center',
            'Left',
            'Right',
          ]),
          SwitchListTile(
            title: const Text('Bold text'),
            contentPadding: EdgeInsets.zero,
            value: _design.flag(
              part.key('bold'),
              fallback: part == _CallPart.name,
            ),
            onChanged: (value) => _set(part.key('bold'), value),
          ),
        ],
      ],
    ];
  }

  List<Widget> _colors() => [
    _swatch('Background', 'background', _design.background),
    SwitchListTile(
      title: const Text('Gradient background'),
      contentPadding: EdgeInsets.zero,
      value: _design.gradient,
      onChanged: (value) => _set('gradient', value),
    ),
    if (_design.gradient) ...[
      _swatch(
        'Second background color',
        'background_end',
        _design.backgroundEnd,
      ),
      _option('Gradient direction', 'gradient_direction', const [
        'Vertical',
        'Horizontal',
        'Diagonal',
      ]),
    ],
    const Divider(),
    for (final part in _CallPart.values)
      _swatch(
        '${part.label} color',
        part.key('color'),
        _design.partColor(part),
      ),
    _swatch('Avatar initial', 'avatar_ink', _design.avatarInk),
    _swatch('Button text and icons', 'action_ink', _design.actionInk),
  ];

  List<Widget> _controls() {
    final part = _part.isAction ? _part : _CallPart.answer;
    return [
      Wrap(
        spacing: 7,
        children: [
          for (final action in [
            _CallPart.answer,
            _CallPart.decline,
            _CallPart.end,
          ])
            ChoiceChip(
              label: Text(action.label),
              selected: part == action,
              onSelected: (_) => _select(action),
            ),
        ],
      ),
      ..._buttonDimensions(part),
      _option('Gesture', part.key('gesture'), [
        for (final gesture in _CallGesture.values) gesture.label,
      ]),
      const Text('Every control also works with a tap.'),
      const SizedBox(height: 8),
      _option('Button shape', part.key('shape'), const [
        'Pill',
        'Round',
        'Rounded rectangle',
      ]),
      _option('Button contents', part.key('display'), const [
        'Icon and label',
        'Icon only',
        'Label only',
      ]),
      if (_design.option(part.key('display'), 2) != 1)
        _slider(
          'Label size',
          _design.buttonLabelSize(part),
          CallDesign.minButtonContentSize,
          CallDesign.maxButtonLabelSize,
          (value) => _set(part.key('label_size'), value),
          suffix: ' dp',
        ),
      if (_design.option(part.key('display'), 2) != 2)
        _slider(
          'Icon size',
          _design.buttonIconSize(part),
          CallDesign.minButtonContentSize,
          CallDesign.maxButtonIconSize,
          (value) => _set(part.key('icon_size'), value),
          suffix: ' dp',
        ),
      _labelField('Button label', part.key('label'), part.label, 24),
      _swatch(
        'Label and icon color',
        part.key('ink'),
        _design.color(part.key('ink'), _design.actionInk.toARGB32()),
      ),
    ];
  }

  List<Widget> _buttonDimensions(_CallPart part) {
    final size = _design.buttonSize(part);
    return [
      _slider(
        'Button width',
        size.width,
        CallDesign.minButtonDimension,
        CallDesign.maxButtonWidth,
        (value) => _set(part.key('width'), value),
        suffix: ' dp',
      ),
      _slider(
        'Button height',
        size.height,
        CallDesign.minButtonDimension,
        CallDesign.maxButtonHeight,
        (value) => _set(part.key('height'), value),
        suffix: ' dp',
      ),
    ];
  }

  Widget _option(String label, String key, List<String> options) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _design.option(key, options.length - 1),
          isDense: true,
          isExpanded: true,
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(value: i, child: Text(options[i])),
          ],
          onChanged: (value) {
            if (value == null) return;
            _set(key, value);
          },
        ),
      ),
    ),
  );

  Widget _labelField(String label, String key, String fallback, int limit) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextFormField(
          key: ValueKey((key, _resetVersion)),
          initialValue: _design.text(key, fallback),
          maxLength: limit,
          decoration: InputDecoration(labelText: label, counterText: ''),
          onChanged: (value) => _set(key, value),
        ),
      );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change, {
    String suffix = '',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label · ${value.round()}$suffix'),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).round(),
        label: '${value.round()}$suffix',
        semanticFormatterCallback: (value) => '$label ${value.round()}$suffix',
        onChanged: change,
      ),
    ],
  );

  String _hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Widget _swatch(String label, String key, Color color) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    title: Text(label),
    trailing: Text(_hex(color)),
    onTap: () async {
      var input = _hex(color);
      String? error;
      final selected = await showDialog<Color>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(label),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: input,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Hex color',
                    hintText: '#AABBCC',
                    errorText: error,
                  ),
                  onChanged: (value) => input = value,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in const [
                      Colors.white,
                      Colors.black,
                      Color(0xffc6aaff),
                      Color(0xff9fe0bc),
                      Color(0xffb9d6fb),
                      Color(0xffffb2c0),
                      Color(0xff23374c),
                    ])
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, color),
                        child: Tooltip(
                          message: _hex(color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final hex = input.trim().replaceFirst(RegExp(r'^#'), '');
                  if (!RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(hex)) {
                    update(() => error = 'Enter six hex digits.');
                    return;
                  }
                  Navigator.pop(
                    context,
                    Color(0xff000000 | int.parse(hex, radix: 16)),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      );
      if (mounted && selected != null) _set(key, selected.toARGB32());
    },
  );
}
