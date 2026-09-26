/// Conversion between plain JSON values and Firestore REST `Value` objects.
/// See https://firebase.google.com/docs/firestore/reference/rest/v1/Value
library;

Map<String, Object?> encodeValue(Object? value) => switch (value) {
  null => {'nullValue': null},
  final bool b => {'booleanValue': b},
  final int i => {'integerValue': '$i'},
  final double d => {'doubleValue': d},
  final String s => {'stringValue': s},
  final List<Object?> list => {
    'arrayValue': {
      'values': [for (final item in list) encodeValue(item)],
    },
  },
  final Map<String, Object?> map => {
    'mapValue': {'fields': encodeFields(map)},
  },
  _ => throw ArgumentError.value(value, 'value', 'Unsupported Firestore type'),
};

Map<String, Object?> encodeFields(Map<String, Object?> json) => {
  for (final MapEntry(:key, :value) in json.entries) key: encodeValue(value),
};

Object? decodeValue(Map<String, Object?> value) {
  final MapEntry(:key, value: raw) = value.entries.single;
  return switch (key) {
    'nullValue' => null,
    'booleanValue' => raw! as bool,
    'integerValue' => int.parse(raw! as String),
    'doubleValue' => (raw! as num).toDouble(),
    'stringValue' || 'timestampValue' || 'referenceValue' => raw! as String,
    'arrayValue' => [
      for (final item
          in (raw! as Map<String, Object?>)['values'] as List<Object?>? ??
              const [])
        decodeValue(item! as Map<String, Object?>),
    ],
    'mapValue' => decodeFields(
      (raw! as Map<String, Object?>)['fields'] as Map<String, Object?>? ??
          const {},
    ),
    _ => throw FormatException('Unsupported Firestore value: $key'),
  };
}

Map<String, Object?> decodeFields(Map<String, Object?> fields) => {
  for (final MapEntry(:key, :value) in fields.entries)
    key: decodeValue(value! as Map<String, Object?>),
};

/// The last path segment of a document name: `projects/.../documents/a/b` → `b`.
String documentId(String name) => name.substring(name.lastIndexOf('/') + 1);
