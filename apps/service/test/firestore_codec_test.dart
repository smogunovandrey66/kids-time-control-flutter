import 'package:ktc_service/ktc_service.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips every JSON type', () {
    final json = <String, Object?>{
      'text': 'Иван',
      'count': 42,
      'ratio': 1.5,
      'flag': true,
      'nothing': null,
      'list': [1, 'two'],
      'map': {
        'nested': {'deep': 1},
      },
    };

    expect(decodeFields(encodeFields(json)), json);
  });

  test('integers are strings on the wire', () {
    expect(encodeValue(7), {'integerValue': '7'});
  });

  test('documentId takes the last path segment', () {
    expect(
      documentId('projects/p/databases/(default)/documents/families/f1'),
      'f1',
    );
  });
}
