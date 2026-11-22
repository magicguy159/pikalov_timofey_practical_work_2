# Протокол самопроверки

**Статус:** SQL подготовлен, но запуск на PostgreSQL 15+ в этой среде не выполнялся. Фактические результаты не выдумываются; после реального прогона заполни факты и вердикты.

## Подготовка
\`\`\`bash
createdb foodexpress
psql -d foodexpress -f db/schema/foodexpress.sql
psql -d foodexpress -f db/schema/zz_fixes.sql
psql -d foodexpress -f db/schema/grants.sql
\`\`\`
Перед этим администратор БД должен обеспечить существование схемы exts и расширения uuid-ossp в ней.

## FOOD-102 — обязательная проверка
\`\`\`sql
SET ROLE inspector;
SET search_path TO pikalov_food, exts, public;
CALL erase_test_data();
CALL insert_test_data(10);
\`\`\`
После первого запуска ожидается: client=10, courier=10, product_category=10, restaurant=10, address=50, product=50, "order"=50, review=50, payment=50. Связующие таблицы и courier_pay наполняются процедурой.

## Повторный запуск
\`\`\`sql
CALL insert_test_data(10);
\`\`\`
Ожидается добавление новой независимой партии без удаления ранее созданных строк.

## Контрольные запросы
\`\`\`sql
SELECT count(*) FROM "order" WHERE total_amount < 1000;
SELECT count(*) FROM "order" WHERE round(order_amount*0.10,2) <> commission;
SELECT count(*) FROM order_structure os
JOIN product p USING(product_id)
JOIN "order" o USING(order_id)
WHERE p.restaurant_id <> o.restaurant_id;
SELECT * FROM get_statistic();
CALL courier_salary();
SELECT * FROM how_much_money ORDER BY year_month;
\`\`\`
**Факт / вердикт:** заполнить после выполнения на целевом PostgreSQL.
