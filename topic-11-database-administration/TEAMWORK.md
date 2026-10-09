# TEAMWORK - Topic 11 (Database Administration)

## Склад команди
- Команда: Team 4
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Oleksandr | Database Administrator (Memberships) | Створив 2 ролі для зони абонементів: `fc_membership_analyst` (read-only: SELECT на `membership_plans`, `memberships` і звітні views, без доступу до персональних даних `members`) та `fc_membership_manager` (read-write: SELECT/INSERT на `memberships` і column-level UPDATE лише `status` та `end_date`, лише SELECT на тарифи, column-level SELECT на `members` без `phone` і `birth_date`, UPDATE через view з CHECK OPTION). Створив 2 користувачі та призначив їм ролі. REVOKE: усі права для PUBLIC на схему й таблиці, DELETE на `memberships` для менеджера. Створення ролей і користувачів обгорнуто в `DO`-блоки з `IF NOT EXISTS`, щоб скрипт можна було запускати повторно. Додав перевірку прав через `has_table_privilege`/`has_column_privilege`, демо з `SET ROLE` і закоментований cleanup. | database_administration.sql (секція Oleksandr) |
| ... | ... | ... | ... |
| ... | ... | ... | ... |

## Контекст теми
Опишіть, хто відповідав за: створення ролей і користувачів, `GRANT`/`REVOKE`, логіку least privilege, тестування прав доступу та optional cleanup у `database_administration.sql`.

## Коротке обґрунтування командного підходу
1. Чому обрали саме такі ролі та рівні доступу: ...
2. Як розподілили відповідальність за безпекову модель: ...
3. Як перевірили, що ролі реально відрізняються правами: ...
