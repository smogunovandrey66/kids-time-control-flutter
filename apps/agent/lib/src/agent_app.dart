import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ktc_core/ktc_core.dart';

import 'agent_controller.dart';
import 'strings.dart';

/// The agent's window content: the login question, a notification, or the
/// current status. The window itself is shown and hidden by `desktop.dart`.
class AgentApp extends StatelessWidget {
  const AgentApp({required this.controller, required this.strings, super.key});

  final AgentController controller;
  final Strings strings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: strings.title,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: Scaffold(
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: switch ((controller.prompt, controller.notice)) {
            (final LoginRequest prompt, _) => LoginView(
              key: ValueKey(prompt.id),
              prompt: prompt,
              strings: strings,
              onAnswer: controller.answer,
              onCancel: controller.cancel,
            ),
            (_, final Notice notice) => NoticeView(
              text: strings.notice(notice),
              strings: strings,
              onClose: controller.dismissNotice,
            ),
            _ => Center(child: Text(statusText(controller, strings))),
          },
        ),
      ),
    ),
  );
}

/// One line for the tray tooltip and the idle window.
String statusText(AgentController controller, Strings strings) {
  if (!controller.connected) return strings.connecting;
  final AgentStatus(:childName, :remainingSeconds) = controller.status;
  if (childName == null) return strings.nobodyPlaying;
  return strings.playing(childName, ((remainingSeconds ?? 0) + 59) ~/ 60);
}

class LoginView extends StatefulWidget {
  const LoginView({
    required this.prompt,
    required this.strings,
    required this.onAnswer,
    required this.onCancel,
    super.key,
  });

  final LoginRequest prompt;
  final Strings strings;
  final void Function(String childId, String pin) onAnswer;
  final VoidCallback onCancel;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  late String? _childId = widget.prompt.children.length == 1
      ? widget.prompt.children.single.id
      : null;

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  bool get _canPlay => _childId != null && _pin.text.isNotEmpty;

  void _play() {
    if (_canPlay) widget.onAnswer(_childId!, _pin.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    final error = widget.prompt.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.whoIsPlaying(widget.prompt.appName),
          style: theme.textTheme.headlineSmall,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              strings.loginError(error),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in widget.prompt.children)
              ChoiceChip(
                selected: _childId == child.id,
                onSelected: (_) {
                  setState(() => _childId = child.id);
                  _pinFocus.requestFocus();
                },
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name),
                    if (strings.remainingToday(child.remainingSeconds)
                        case final remaining?)
                      Text(
                        remaining,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pin,
          focusNode: _pinFocus,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(labelText: strings.pin),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _play(),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: widget.onCancel, child: Text(strings.cancel)),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _canPlay ? _play : null,
              child: Text(strings.play),
            ),
          ],
        ),
      ],
    );
  }
}

class NoticeView extends StatelessWidget {
  const NoticeView({
    required this.text,
    required this.strings,
    required this.onClose,
    super.key,
  });

  final String text;
  final Strings strings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.timer, size: 48),
      const SizedBox(height: 16),
      Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Spacer(),
      Center(
        child: FilledButton(onPressed: onClose, child: Text(strings.ok)),
      ),
    ],
  );
}
