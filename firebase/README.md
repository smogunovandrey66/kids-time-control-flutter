# Firebase

Работает на **бесплатном тарифе Spark**: только Authentication и Firestore, без Cloud Functions.

| Файл | Что это |
|---|---|
| `firestore.rules` | правила безопасности: кто что может читать и писать |
| `firestore.indexes.json` | индексы Firestore |
| `tests/rules.test.mjs` | тесты правил в эмуляторе (запускаются в CI) |
| `firebase.json`, `.firebaserc` | настройки Firebase CLI; `demo-…` — проект для эмулятора |

## Тесты правил локально

Нужны Node.js 22+ и Java 21+.

```bash
cd firebase
npm ci
npm test        # запускает эмулятор Firestore и тесты
```

## Создание своего проекта Firebase

1. [console.firebase.google.com](https://console.firebase.google.com) → *Add project* (Google Analytics не нужна).
2. *Authentication* → *Sign-in method*: включите **Google** (для родителей) и **Anonymous** (для ПК).
3. *Firestore Database* → *Create database* → *Production mode*, регион ближе к вам (например, `eur3`).
4. Разверните правила и индексы:
   ```bash
   npm i -g firebase-tools
   firebase login
   cd firebase
   firebase use --add          # выберите свой проект
   firebase deploy --only firestore
   ```
5. Приложение родителя: см. [apps/parent/README.md](../apps/parent/README.md) (`flutterfire configure`).
6. ПК: нужны *Web API Key* и *Project ID* (*Project settings* → *General*).
