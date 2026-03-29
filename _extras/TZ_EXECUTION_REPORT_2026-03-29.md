# WAPB — виконання ТЗ по доступах і ролях

Дата пакування: 2026-03-29

## Що дороблено

### 1. Рольова модель
- Уніфіковано ієрархію ролей: `guest < viewer < operator < maintainer < admin < sysadmin < owner`.
- Вирівняно відображення ролей у клієнті та сервері.
- Прибрано неявні fallback-схеми доступу за роллю як робочий механізм.
- Додано аварійний прапорець міграції `WAPB_ACCESS_MIGRATION_MODE` для контрольованого тимчасового email-bridge.

### 2. Ідентифікація користувача
- Основний режим: строгий `Session.getTemporaryActiveUserKey()`.
- ACCESS використовується як основний реєстр доступу.
- Пошук користувача: `user_key_current` -> `user_key_prev` -> ротація ключа при збігу по prev.
- Якщо ключ не знайдено, користувач не піднімається до viewer/admin за замовчуванням.

### 3. Viewer-security
- Viewer може відкривати тільки власну картку за `person_callsign`.
- Viewer не має доступу до детального зведення.
- Обмеження реалізовано і в UI, і на сервері.
- Спроби обійти обмеження логуються як порушення.

### 4. Робочі та системні дії
- SEND_PANEL, робочі дії, зведення, перемикання місяця, перевірки відпусток/ДН закрито серверними перевірками за ролями.
- Maintenance/admin/sysadmin маршрути розведені по рівнях доступу.
- Для клієнта додано рольовий захист кнопок та legacy-compatible guard, щоб старі виклики не ламали runtime.

### 5. Порушення доступу, аудит, сповіщення
- Порушення пишуться в `ALERTS_LOG`.
- Дублюються в `AUDIT_LOG` і компактно в `LOG`.
- Налаштовано email best-effort сповіщення для ролей `admin/sysadmin/owner`.
- Для onEdit/onChange службових листів додано контроль і best-effort сигналізацію.

### 6. Службові листи та bootstrap
- Bootstrap доповнено створенням/забезпеченням `AUDIT_LOG` разом із runtime/alerts листами.
- Список службових листів під захист і аудит вирівняно:
  - ACCESS
  - OPS_LOG
  - ACTIVE_OPERATIONS
  - CHECKPOINTS
  - AUDIT_LOG
  - JOB_RUNTIME_LOG
  - ALERTS_LOG

### 7. UI / сервісний блок
- Блок `🧑‍💻` показує поточну роль, реєстрацію, source access, user key, дозволені дії та пояснення.
- Додано/залишено кнопки копіювання звіту та user key.
- Для елементів sidebar введено `data-role-min` і централізоване приховування/показ.

## Ключові змінені файли
- `AccessControl.gs`
- `AccessEnforcement.gs`
- `UseCases.gs`
- `SidebarServer.gs`
- `Stage5MaintenanceApi.gs`
- `AccessSheetTriggers.gs`
- `ServiceSheetsBootstrap.gs`
- `Sidebar.html`
- `Js.Helpers.html`

## Що перевірено тут перед пакуванням
- Статичний синтаксичний прогін пакета: `73 / 73 OK` через `_extras/validate-gs-syntax.js`.

## Важливе практичне зауваження
Повноцінний інтеграційний прогін Google Apps Script-тригерів, Session API, MailApp та Spreadsheet protection у цьому контейнері недоступний. Тому пакет підготовлено як готовий GAS-friendly архів, але бойову перевірку `onEdit/onChange/MailApp/Protections` потрібно виконати вже у вашій книзі після заливки.
