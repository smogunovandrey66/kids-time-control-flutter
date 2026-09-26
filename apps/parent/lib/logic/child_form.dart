import 'dart:isolate';

import 'package:ktc_core/ktc_core.dart';

/// Validation of the child editor; returns error keys, not texts, so it is testable
/// without localizations.
enum ChildFormError {
  nameEmpty,
  nameTooLong,
  pinInvalid,
  pinRequired,
  limitInvalid,
}

final _pinPattern = RegExp(r'^\d{4,6}$');

List<ChildFormError> validateChild({
  required String name,
  required String pin,
  required bool isNew,
  required String weekdayMinutes,
  required String weekendMinutes,
}) {
  final errors = <ChildFormError>[];
  final trimmed = name.trim();
  if (trimmed.isEmpty) errors.add(ChildFormError.nameEmpty);
  if (trimmed.length > 40) errors.add(ChildFormError.nameTooLong);
  if (pin.isEmpty && isNew) errors.add(ChildFormError.pinRequired);
  if (pin.isNotEmpty && !_pinPattern.hasMatch(pin)) {
    errors.add(ChildFormError.pinInvalid);
  }
  for (final value in [weekdayMinutes, weekendMinutes]) {
    final minutes = int.tryParse(value);
    if (minutes == null || minutes < 0 || minutes > 24 * 60) {
      errors.add(ChildFormError.limitInvalid);
      break;
    }
  }
  return errors;
}

/// PBKDF2 with 100 000 iterations takes a noticeable time on a phone:
/// run it off the UI thread.
Future<String> hashPinInBackground(
  String pin, {
  int iterations = defaultPinIterations,
}) => Isolate.run(() => hashPin(pin, iterations: iterations));
