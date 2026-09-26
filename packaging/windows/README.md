# Установка службы на ПК

Архив `kids-time-control-windows.zip` собирается в CI (артефакт в GitHub Actions) и содержит:

| Файл | Что это |
|---|---|
| `ktc.exe` | программа (служба + утилита командной строки) |
| `KidsTimeControl.exe` | [WinSW](https://github.com/winsw/winsw) v2: регистрирует `ktc.exe service` как службу Windows |
| `KidsTimeControl.xml` | настройки службы: автозапуск, LocalSystem, перезапуск при сбое, журналы |
| `install.ps1`, `uninstall.ps1` | установка и удаление |

## Установка

В **PowerShell от имени администратора** в папке с распакованным архивом:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Скрипт:
1. копирует файлы в `C:\Program Files\KidsTimeControl`;
2. создаёт `C:\ProgramData\KidsTimeControl` и оставляет доступ к ней только SYSTEM и администраторам —
   ребёнок с обычной учётной записью не прочитает хэши PIN и не исправит статистику;
3. регистрирует и запускает службу **Kids Time Control** (автозапуск, перезапуск при сбое).

Затем привяжите ПК к семье (в том же окне администратора):

```powershell
& "$env:ProgramFiles\KidsTimeControl\ktc.exe" pair --api-key <Web API Key> --project-id <ID проекта> --name "Домашний ПК"
```

Служба сама синхронизируется раз в минуту. Журналы — `C:\ProgramData\KidsTimeControl\logs`.

## Важно: пока нет агента в трее

Служба не может показывать окна (она работает в отдельной сессии Windows). Окно «Кто играет?»
будет показывать агент в трее — он ещё в разработке. **До его появления служба закрывает все
контролируемые игры**, потому что спросить, кто играет, некому.

Проверить работу со входом можно без службы, в консоли администратора:

```powershell
& "$env:ProgramFiles\KidsTimeControl\ktc.exe" service --console
```

(перед этим остановите службу: `Stop-Service KidsTimeControl`).

## Удаление

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1              # данные сохраняются
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -RemoveData  # вместе с данными
```
