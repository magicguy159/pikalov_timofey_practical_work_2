# Развёртывание FoodExpress

Требуется PostgreSQL 15+ и заранее подготовленная преподавателем схема \`exts\` с расширением \`uuid-ossp\`.

Из корня репозитория выполните от администратора БД:

\`\`\`bash
psql -d foodexpress -v ON_ERROR_STOP=1 -f db/schema/foodexpress.sql
psql -d foodexpress -v ON_ERROR_STOP=1 -f db/schema/zz_fixes.sql
psql -d foodexpress -v ON_ERROR_STOP=1 -f db/schema/zzz_contract_fixes.sql
psql -d foodexpress -v ON_ERROR_STOP=1 -f db/schema/grants.sql
\`\`\`

После этого задайте роли \`inspector\` пароль, указанный в задании курса, через интерактивную команду администратора:

\`\`\`bash
psql -d foodexpress
\password inspector
\`\`\`

Проверка генератора:

\`\`\`sql
SET ROLE inspector;
SET search_path TO pikalov_food, exts, public;
CALL insert_test_data(10);
\`\`\`

Создание требуемого custom-format backup:

\`\`\`bash
PGDATABASE=foodexpress PGUSER=postgres bash db/create_backup.sh
\`\`\`

Команда создаст \`db/foodexpress_pikalov.backup\`. Это бинарный архив PostgreSQL; его нужно сгенерировать в окружении с работающим PostgreSQL и затем добавить в GitHub отдельным коммитом.
