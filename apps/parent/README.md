# Родительское приложение (Flutter, Android)

Экраны:
- **Сегодня** — сколько каждый ребёнок играл сегодня, сколько осталось, топ игр, график за 7 дней,
  кнопки «+15 / +30 / +60 мин» (бонус на сегодня).
- **Дети** — добавить, переименовать, сменить PIN, лимиты на будни и выходные, удалить.
- **Игры** — правила распознавания: имя exe, путь, подстрока командной строки.
- **Компьютеры** — привязка ПК по коду, статус «на связи», отвязка.

Вход — через Google. PIN хэшируется на телефоне (PBKDF2, `ktc_core`) и в облако не попадает.

## Архитектура

- `lib/data/repositories.dart` — интерфейсы; `firebase_repositories.dart` — реализация на
  Firebase Auth и Cloud Firestore; `providers.dart` — провайдеры Riverpod.
- `lib/logic/` — чистая логика (статистика, бонус, проверка формы) с тестами.
- `lib/features/` — экраны.
- Тесты (`test/`) работают на фейковых репозиториях, без Firebase.

## Подключение к своему Firebase

1. Создайте проект и включите Google-вход, Anonymous-вход и Firestore — см. [firebase/README.md](../../firebase/README.md).
2. Установите FlutterFire CLI и сгенерируйте настройки:
   ```bash
   dart pub global activate flutterfire_cli
   cd apps/parent
   flutterfire configure --platforms=android
   ```
   Команда перезапишет `lib/firebase_options.dart` значениями вашего проекта. Пока там заглушка,
   приложение показывает экран «Firebase не настроен». Сгенерированный файл не содержит секретов,
   но если не хотите публиковать ID своего проекта, не коммитьте его.
3. Вход через Google: в консоли Firebase → *Project settings* → ваше Android-приложение добавьте
   SHA-1 отладочного ключа (`cd android && ./gradlew signingReport`).
4. Запуск: `flutter run`.

## Команды

```bash
flutter test
flutter build apk --debug      # APK также собирается в CI (артефакт parent-app-debug)
```
