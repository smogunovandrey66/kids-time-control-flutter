# ktc_service

Служба Windows на Dart ([архитектура](../../docs/architecture.md#служба-ktc_service-appsservice)).
Следующий шаг этапа 1: консольная программа (`dart compile exe`), регистрация службой через WinSW,
отслеживание процессов через пакет `win32`, приостановка и закрытие игр, named pipe для агента,
состояние в `%ProgramData%\KidsTimeControl`.
