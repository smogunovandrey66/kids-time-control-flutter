# ktc_service

Служба Windows на Dart ([архитектура](../../docs/architecture.md#служба-ktc_service-appsservice))
и утилита командной строки `ktc`. Служба ставится через WinSW ([packaging/windows](../../packaging/windows/README.md));
команды утилиты помогают проверить распознавание игр и учёт времени.

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

### `ktc pair` — подключить ПК к семье
```bat
ktc pair --api-key <Web API Key> --project-id <ID проекта> --name "Домашний ПК"
```
Показывает код вида `K7QM-4XP2`. Введите его в приложении родителя: *Компьютеры → Привязать компьютер*.
Web API Key и ID проекта — в консоли Firebase: *Project settings → General*.

### `ktc sync` — синхронизация с облаком
```bat
ktc sync
```
Скачивает детей и игры в `config.json`, отправляет статистику за 7 дней и статус ПК
(«на связи», версия). Пока служба не готова, запускайте вручную или через Планировщик заданий.

## Папка данных

По умолчанию `%ProgramData%\KidsTimeControl` (задаётся `--data-dir`):

| Файл | Что в нём |
|---|---|
| `config.json` | дети и игры (из облака после `ktc sync` или вручную) |
| `cloud.json` | проект Firebase, анонимная учётная запись ПК, id семьи — **не публикуйте** |
| `usage\<ребёнок>_<дата>.json` | сыгранное время за день; `ktc run` восстанавливает его после перезапуска |

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
(подстрока командной строки), `folder` (любая программа из папки и её подпапок). Регистр не важен,
должны совпасть все указанные поля.

`folder` защищает от переименования: если ребёнок скопирует `RobloxPlayerBeta.exe` под другим именем
в папке игры, правило всё равно сработает. `*` заменяет одно имя папки, поэтому одно правило
`C:\Users\*\AppData\Local\Roblox` работает для всех пользователей Windows.

### `ktc service` — цикл службы
Запускается службой Windows (см. [packaging/windows](../../packaging/windows/README.md)).
Для проверки без агента в трее: `ktc service --console` — спрашивает, кто играет, прямо в консоли.

## Что дальше

Агент в трее (Flutter) и связь со службой через named pipe: окно «Кто играет?», уведомления,
кнопка «Выйти». Завершение сессии при блокировке экрана.
