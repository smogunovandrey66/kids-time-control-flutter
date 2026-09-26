# ktc_service

Служба Windows на Dart ([архитектура](../../docs/architecture.md#служба-ktc_service-appsservice))
и утилита командной строки `ktc`. Сейчас готова утилита: с ней можно проверить распознавание игр
и учёт времени до установки службы.

## Где взять `ktc.exe`

- Готовый файл: GitHub → *Actions* → последний успешный прогон **CI** → артефакт `ktc-windows`.
- Или собрать самому (нужен Flutter/Dart):
  ```bat
  dart pub get
  dart compile exe apps\service\bin\ktc.dart -o ktc.exe
  ```
- Или запускать без сборки: `dart run apps\service\bin\ktc.dart <команда>`.

## Команды

### `ktc processes` — как игра выглядит в списке процессов
```bat
ktc processes                      :: всё, кроме C:\Windows
ktc processes --filter minecraft   :: только нужное
ktc processes --all                :: вместе с системными
```
Запустите игру и посмотрите её путь и командную строку. Из этого получается правило для `config.json`.
Процессы других пользователей и системные службы видны только при запуске от администратора.

### `ktc hash-pin` — PIN для config.json
```bat
ktc hash-pin 1234
```
Выводит строку для поля `pinHash`.

### `ktc match` — какие запущенные процессы считаются играми
```bat
ktc match --config config.json
```

### `ktc run` — учёт времени в консоли
```bat
ktc run --config config.json --child ivan
ktc run --config config.json --child ivan --limit-minutes 3 --enforce
```
Спрашивает PIN, раз в 2 секунды проверяет процессы, считает время, пока запущена игра,
предупреждает за 10, 5 и 1 минуту. По умолчанию это **пробный режим**: по окончании времени
пишет, какие игры закрыл бы. С `--enforce` действительно закрывает их.
`--limit-minutes` задаёт короткий лимит для проверки. Остановить — Ctrl+C.

## config.json

Формат — `shared/schema/config.schema.json`, пример — `shared/examples/config.json`:

```json
{
  "children": {
    "ivan": {
      "name": "Иван",
      "pinHash": "<вывод ktc hash-pin>",
      "limits": { "weekdaySeconds": 3600, "weekendSeconds": 7200 },
      "archived": false
    }
  },
  "apps": {
    "minecraft": {
      "name": "Minecraft",
      "match": { "exeName": "javaw.exe", "commandLineContains": "minecraft" },
      "archived": false
    }
  }
}
```

В `match` можно указать `exePath` (полный путь), `exeName` (имя файла) и `commandLineContains`
(подстрока командной строки). Регистр не важен, должны совпасть все указанные поля.

## Что дальше

Установка службой через WinSW, приостановка игры до ввода PIN, связь с агентом в трее
через named pipe, сохранение использованного времени между перезапусками.
