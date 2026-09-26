"""Checks that every example in shared/examples matches its schema (examples/<name>.json -> schema/<name>.schema.json)."""
import json
import pathlib
import sys

from jsonschema import Draft202012Validator, FormatChecker

root = pathlib.Path(__file__).parent
failed = False
for schema_path in sorted((root / "schema").glob("*.schema.json")):
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    name = schema_path.name.removesuffix(".schema.json")
    example_path = root / "examples" / f"{name}.json"
    if not example_path.exists():
        print(f"MISSING example for {schema_path.name}")
        failed = True
        continue
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    errors = list(validator.iter_errors(json.loads(example_path.read_text(encoding="utf-8"))))
    for error in errors:
        print(f"{example_path.name}: {error.json_path}: {error.message}")
    failed |= bool(errors)
    print(f"{'FAIL' if errors else 'OK  '} {example_path.name}")

sys.exit(1 if failed else 0)
