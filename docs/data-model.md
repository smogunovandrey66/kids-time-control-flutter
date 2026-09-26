# Модель данных (Firestore)

JSON-схемы документов — в `shared/schema/`, примеры — в `shared/examples/`.
CI проверяет, что примеры соответствуют схемам.

```
families/{familyId}
  ├─ parents: [uid]
  ├─ timeZone: "Europe/Moscow"
  │
  ├─ children/{childId}          — child.schema.json
  ├─ apps/{appId}                — app.schema.json
  ├─ devices/{deviceId}          — device.schema.json
  └─ usage/{childId}_{YYYY-MM-DD} — usage.schema.json
```

## Правила

- Даты в `usage` — локальные даты семьи (поле `timeZone`), а не UTC: «сегодня» для ребёнка
  начинается в полночь по местному времени.
- Время хранится в секундах (целые числа).
- PIN хранится только в виде хэша в формате `pbkdf2-sha256$<итерации>$<соль base64>$<хэш base64>`.
  Android-приложение вычисляет хэш при смене PIN, ПК проверяет PIN по хэшу без обращения к сети.
  Параметры: 100 000 итераций, соль 16 байт, хэш 32 байта.
- Удалённые дети и игры помечаются `archived: true`, а не удаляются, чтобы сохранилась статистика.
