# Kids Time Control (Flutter/Dart)

[![CI](https://github.com/smogunovandrey66/kids-time-control-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/smogunovandrey66/kids-time-control-flutter/actions/workflows/ci.yml)

Открытая (open source) система контроля времени, которое дети проводят в играх на домашнем ПК с Windows.
Проект некоммерческий, делается для практического использования в семье и открыт для всех.
Всё написано на **Dart и Flutter**: служба на ПК, приложение в трее и родительское приложение
используют общий код.

## Идея

- На ПК работает **служба Windows** (Dart), которая отслеживает запуск выбранных родителем игр.
- Дети пользуются **одной учётной записью Windows**, а внутри программы у каждого ребёнка свой
  профиль с PIN-кодом. При первом запуске игры **агент в трее** (Flutter) спрашивает, кто играет.
- Время считается по каждому ребёнку. Когда лимит заканчивается, программа предупреждает и закрывает игру.
- **Родительское приложение** (Flutter, Android) показывает статистику по детям и дням, позволяет задавать
  лимиты, добавлять детей и менять PIN-коды.
- ПК и телефон синхронизируются через **Firebase**. ПК продолжает работать и без интернета.

Подробности: [ТЗ](docs/spec.md) · [архитектура](docs/architecture.md) · [модель данных](docs/data-model.md) ·
[план разработки](docs/roadmap.md).

## Структура (Dart workspace)

```
packages/
  ktc_core/      — чистый Dart: модели, распознавание игр, учёт времени, PIN; общий для всех приложений
apps/
  service/       — служба Windows (Dart + WinSW + пакет win32)          — этап 1
  agent/         — приложение в трее (Flutter Windows)                  — этап 1
  parent/        — родительское приложение (Flutter Android)            — этап 2
firebase/        — правила Firestore, Cloud Functions                   — этап 2
shared/          — JSON-схемы документов и примеры (контракт между ПК, телефоном и облаком)
docs/            — ТЗ, архитектура, модель данных, план
```

## Разработка

Нужен [Flutter](https://docs.flutter.dev/get-started/install) 3.35+ (с ним идёт Dart).

```bash
dart pub get                         # зависимости всего workspace
dart format .                        # форматирование
dart analyze                         # анализатор
cd packages/ktc_core && dart test    # тесты ядра
```

CI (GitHub Actions) на каждый push и pull request проверяет форматирование, анализатор и тесты
на Linux и Windows, а также соответствие примеров JSON-схемам.

## Статус

Этап 1 — программа для ПК, работающая локально. Готовы ядро `ktc_core` и утилита командной строки
[`ktc`](apps/service/README.md) для проверки распознавания игр и учёта времени. Следующий шаг — служба и агент.
См. [план](docs/roadmap.md).

## Лицензия

[MIT](LICENSE).
