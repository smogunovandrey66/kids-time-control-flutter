# ktc_agent

Приложение в трее на Flutter для Windows ([архитектура](../../docs/architecture.md#агент-ktc_agent-appsagent)).
Спрашивает, кто играет (имя и PIN), показывает предупреждения об остатке времени, кнопку
«Выйти (сменить игрока)». Со службой общается по [протоколу](../../docs/architecture.md#протокол-служба--агент)
на `127.0.0.1:47291` и сам ничего не решает.

| Файл | Что внутри |
|---|---|
| `lib/src/agent_controller.dart` | подключение к службе (с переподключением), вопрос, уведомление, статус |
| `lib/src/agent_app.dart` | окно: «Кто играет?», уведомление, статус |
| `lib/src/desktop.dart` | окно поверх всех и значок в трее (`window_manager`, `tray_manager`) |
| `lib/src/windows.dart` | сессия Windows, один экземпляр на сессию, сокет к службе |
| `lib/src/strings.dart` | тексты на русском и английском (по языку Windows) |

```bash
flutter test                   # тесты (на любой ОС)
flutter build windows          # сборка (на Windows): build\windows\x64\runner\Release
```

Проверка вручную на Windows: запустите `ktc service --data-dir <папка>` в одном окне и
`flutter run -d windows` в другом, затем запустите игру из `config.json`.

Иконка — `tools/make_icon.py` (рисует часы, без зависимостей).
