# TEAMWORK - Topic 04 (SQL DDL)

## Склад команди
- Команда: Team 4
- Варіант предметної області: Fitness Center Management

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Vasyl | Database Developer | Розробив DDL для таблиці `attendance`, створив PRIMARY KEY з автоматичною генерацією IDENTITY для `attendance_id` та зовнішні ключі до `members` і `classes`. Додав UNIQUE для пари (`member_id`, `class_id`), NOT NULL для обов’язкових полів та індекс `idx_attendance_class_id`. Для часу відвідування використав поле `checked_in_at` типу TIMESTAMPTZ. | `ddl.sql` (attendance section) |
| Oleksandr | Database Developer | Розробив DDL для `membership_plans` і `memberships`, створив `membership_status` ENUM, PK/FK, CHECK constraints та indexes для `member_id` і `plan_id`. | `ddl.sql` (membership section) |
| Oksana | Database Developer | Розробила DDL для таблиці `trainers`, створила PRIMARY KEY для `trainer_id` та налаштувала для нього автоматичну генерацію значень `IDENTITY`. Для моєї таблиці додаткові constraints не потрібні. Також немає додаткових полів, для яких потрібно створювати індекси. | `ddl.sql` (trainers section) |
| Boris | Database Developer | Розробив DDL для таблиці `members`, створив PRIMARY KEY для `member_id` та налаштував для нього автоматичну генерацію значень IDENTITY, додавши обмеження UNIQUE для `email`, NOT NULL для `first_name` та `last_name` й DEFAULT для `registration_date`. Також створив індекси `idx_members_phone` та `idx_members_last_first_name` для оптимізації пошуку за номером телефону та прізвищем/ім'ям. | `ddl.sql` (members & indexes section) |

## Контекст теми
Опишіть, хто відповідав за: створення таблиць, PK/FK, constraints, indexes, порядок секцій у `ddl.sql` та перевірку виконання скрипта у PostgreSQL.

## Коротке обґрунтування командного підходу
1. Як ви розподілили DDL-об'єкти між учасниками: ...
2. Чому обрали саме такий поділ роботи: ...
3. Як перевіряли відповідність DDL вашій ER-діаграмі: ...
