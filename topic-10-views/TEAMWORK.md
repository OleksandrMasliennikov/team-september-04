# TEAMWORK - Topic 10 (SQL Views)

## Склад команди
- Команда: Team 4
- Варіант предметної області: Fitness Center Management System

## Таблиця внесків
| Учасник | Роль у команді | Що зроблено | Артефакти / файли |
|---|---|---|---|
| Boris | Boris	Views Developer (Members) | Створив horizontal, vertical, mixed, JOIN, subquery, UNION, view-from-view та CHECK OPTION views, підготував документацію та коментарі до views | views.sql |
| Oleksandr | Views Developer (Memberships) | Створив 8 views для `membership_plans` і `memberships`, по одному на кожен тип: horizontal (`view_plan_price_list`), vertical (`view_active_memberships`), mixed (`view_expiring_memberships`), JOIN з агрегацією (`view_plan_sales_summary`), subquery (`view_returning_members`), UNION (`view_membership_history`), view-from-view (`view_active_memberships_by_plan`), CHECK OPTION (`view_editable_active_memberships`). Додав коментарі, demo-`SELECT` і демонстрацію CHECK OPTION (дозволене оновлення в транзакції з `ROLLBACK` та два заборонені сценарії). | views.sql (секція Oleksandr, VIEW 13–20) |
| ... | ... | ... | ... |

## Контекст теми
Опишіть, хто відповідав за: horizontal/vertical/mixed views, join/subquery/UNION views, view-from-view, `WITH CHECK OPTION`, а також demo-`SELECT` і структуру `views.sql`.

## Коротке обгрунтування командного підходу
1. Як ви розподілили типи views між учасниками: ...
2. Чому ці views важливі для предметної області: ...
3. Як перевіряли практичну цінність і коректність кожного view: ...