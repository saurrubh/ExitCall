import 'dart:async';
import 'dart:convert';

// Keep the Material import compatible with Flutter SDKs before Material UI moved.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'incoming_call.dart';
part 'custom_call.dart';
part 'call_design_editor.dart';

const calls = MethodChannel('local.exitcall/calls');
const presets = ['Google Phone', 'Samsung', 'WhatsApp', 'Classic', 'Custom'];
const customPreset = 4;
const durations = [10, 30, 60, 300, 600, 1800];
const delayLabels = [
  '10 seconds',
  '30 seconds',
  '1 minute',
  '5 minutes',
  '10 minutes',
  '30 minutes',
  'Choose date and time',
];

void main() => runApp(const ExitCall());

class ExitCall extends StatelessWidget {
  const ExitCall({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Exit Call',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffcbb6ff),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff15131e),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      routes: {'/': (_) => const Scheduler()},
      onGenerateInitialRoutes: (route) {
        final uri = Uri.parse(route);
        final query = uri.queryParameters;
        return [
          MaterialPageRoute<void>(
            builder: (_) => uri.path == '/call'
                ? IncomingCall(
                    name: query['name'] ?? 'Unknown caller',
                    number: query['number'] ?? '',
                    preset: (int.tryParse(query['style'] ?? '') ?? 0).clamp(
                      0,
                      customPreset,
                    ),
                    design: CallDesign.decode(query['design']),
                    expires: DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(query['expires'] ?? '') ?? 0,
                    ),
                  )
                : const Scheduler(),
          ),
        ];
      },
    );
  }
}

class Scheduler extends StatefulWidget {
  const Scheduler({super.key});

  @override
  State<Scheduler> createState() => _SchedulerState();
}

class _SchedulerState extends State<Scheduler> with WidgetsBindingObserver {
  final _name = TextEditingController();
  final _number = TextEditingController();
  Map<String, dynamic> _status = {};
  int _preset = 0;
  int _delay = 0;
  bool _fullScreen = true;
  bool _busy = false;
  DateTime? _custom;
  Timer? _refreshTimer;
  CallDesign _design = const CallDesign();

  String get caller =>
      _name.text.trim().isEmpty ? 'Unknown caller' : _name.text.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh(restore: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _apply(Map<String, dynamic> status, {bool restore = false}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (restore) {
        _name.text = status['name'] as String;
        _number.text = status['number'] as String;
        _preset = (status['style'] as int).clamp(0, customPreset);
        _fullScreen = status['full'] as bool;
        _design = CallDesign.decode(status['design'] as String?);
      }
    });
    _refreshTimer?.cancel();
    final remaining =
        (status['time'] as int) - DateTime.now().millisecondsSinceEpoch;
    if (remaining > 0) {
      _refreshTimer = Timer(Duration(milliseconds: remaining + 100), _refresh);
    }
  }

  Future<void> _refresh({bool restore = false}) async {
    try {
      final status = await calls.invokeMapMethod<String, dynamic>('status');
      if (status != null) _apply(status, restore: restore);
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not read Android call settings.');
    }
  }

  String _format(DateTime time) {
    final format = MaterialLocalizations.of(context);
    final hour = format.formatTimeOfDay(
      TimeOfDay.fromDateTime(time),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '${format.formatMediumDate(time)} · $hour';
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final next = now.add(const Duration(minutes: 1));
    final initial = _custom?.isAfter(now) == true ? _custom! : next;
    final last = DateTime(now.year + 5, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: last,
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _custom = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _schedule() async {
    setState(() => _busy = true);
    try {
      final status = await calls.invokeMapMethod<String, dynamic>('status');
      if (status == null || !mounted) return;
      if (status['notifications'] != true) {
        final granted = await calls.invokeMethod<bool>('notifications');
        if (granted != true || !mounted) return;
      }
      if (status['alarms'] != true) {
        await calls.invokeMethod<void>('alarms');
        return;
      }
      if (_delay == durations.length &&
          (_custom == null || !_custom!.isAfter(DateTime.now()))) {
        _message('Choose a future date and time.');
        await _pickTime();
        if (!mounted || _custom?.isAfter(DateTime.now()) != true) return;
      }
      var full = _fullScreen;
      if (full && status['fullScreen'] != true) {
        final useNotification = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lock-screen access'),
            content: const Text(
              'Allow full-screen alerts in Android settings or use a notification for this call.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Open settings'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use notification'),
              ),
            ],
          ),
        );
        if (useNotification == null || !mounted) return;
        if (!useNotification) {
          await calls.invokeMethod<void>('fullScreen');
          return;
        }
        full = false;
      }
      if ((status['time'] as int) > DateTime.now().millisecondsSinceEpoch) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace scheduled call?'),
            content: const Text(
              'Exit Call keeps one scheduled call at a time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted) return;
      }
      final time = _delay == durations.length
          ? _custom!
          : DateTime.now().add(Duration(seconds: durations[_delay]));
      final scheduled = await calls
          .invokeMapMethod<String, dynamic>('schedule', {
            'time': time.millisecondsSinceEpoch,
            'name': caller,
            'number': _number.text.trim(),
            'style': _preset,
            'full': full,
            if (_preset == customPreset) 'design': _design.encode(),
          });
      if (scheduled != null) _apply(scheduled);
      _message('Call scheduled');
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not schedule the call.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDesign() async {
    final design = await Navigator.of(context).push<CallDesign>(
      MaterialPageRoute(
        builder: (_) => _CallDesignEditor(
          design: _design,
          name: caller,
          number: _number.text.trim(),
        ),
      ),
    );
    if (design == null || !mounted) return;
    try {
      await calls.invokeMethod<void>('saveDesign', {
        'design': design.encode(),
        'appearance': customPreset,
      });
      if (mounted) {
        setState(() {
          _design = design;
          _preset = customPreset;
        });
      }
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not save your call design.');
    }
  }

  Future<void> _selectAppearance(int value) async {
    setState(() => _preset = value);
    try {
      await calls.invokeMethod<void>('setAppearance', value);
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not save your call appearance.');
    }
  }

  Future<void> _cancel() async {
    try {
      final status = await calls.invokeMapMethod<String, dynamic>('cancel');
      if (status != null) _apply(status);
    } on PlatformException catch (error) {
      _message(error.message ?? 'Could not cancel the call.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = _status['time'] as int? ?? 0;
    final pending = time > DateTime.now().millisecondsSinceEpoch;
    final permission = switch (_status) {
      {'notifications': false} =>
        'Allow notifications when scheduling your first call.',
      {'alarms': false} => 'Enable Alarms & reminders for precise delivery.',
      {'fullScreen': false} when _fullScreen =>
        'Enable full-screen access to show the call on the lock screen.',
      _ => null,
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
              children: [
                Text(
                  'Exit Call',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                const Text('Schedule a simulated incoming call.'),
                const SizedBox(height: 18),
                _dropdown(
                  'Call appearance',
                  presets,
                  _preset,
                  _selectAppearance,
                ),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  onPressed: _busy || _status.isEmpty ? null : _editDesign,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Customize call screen'),
                ),
                if (pending) ...[
                  const SizedBox(height: 18),
                  ListTile(
                    tileColor: colors.secondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: const Icon(Icons.alarm),
                    title: Text('Scheduled · ${_status['name']}'),
                    subtitle: Text(
                      _format(DateTime.fromMillisecondsSinceEpoch(time)),
                    ),
                    trailing: IconButton(
                      tooltip: 'Cancel scheduled call',
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _name,
                          maxLength: 70,
                          decoration: const InputDecoration(
                            labelText: 'Caller name',
                            hintText: 'e.g. Alex',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _number,
                          keyboardType: TextInputType.phone,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: 'Phone number (optional)',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _dropdown(
                          'Ring after',
                          delayLabels,
                          _delay,
                          (value) => setState(() => _delay = value),
                        ),
                        if (_delay == durations.length) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.event),
                            label: Text(
                              _custom == null
                                  ? 'Set date and time'
                                  : _format(_custom!),
                            ),
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show on lock screen'),
                          value: _fullScreen,
                          onChanged: (value) =>
                              setState(() => _fullScreen = value),
                        ),
                      ],
                    ),
                  ),
                ),
                if (permission != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      permission,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy || _status.isEmpty ? null : _schedule,
                  icon: const Icon(Icons.alarm_add),
                  label: const Text('Schedule call'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => IncomingCall(
                        name: caller,
                        number: _number.text.trim(),
                        preset: _preset,
                        design: _design,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.phone_in_talk_outlined),
                  label: const Text('Preview incoming call'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    List<String> options,
    int current,
    ValueChanged<int> onChange,
  ) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          isDense: true,
          value: current,
          items: [
            for (var i = 0; i < options.length; i++)
              DropdownMenuItem(value: i, child: Text(options[i])),
          ],
          onChanged: (value) {
            if (value != null) onChange(value);
          },
        ),
      ),
    );
  }
}
