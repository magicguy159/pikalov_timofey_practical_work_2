-- Run as PostgreSQL administrator after foodexpress.sql and zz_fixes.sql.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='inspector') THEN
    CREATE ROLE inspector LOGIN;
  END IF;
END $$;
GRANT USAGE ON SCHEMA pikalov_food, exts TO inspector;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pikalov_food TO inspector;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pikalov_food TO inspector;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA pikalov_food TO inspector;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA pikalov_food TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA pikalov_food GRANT ALL PRIVILEGES ON TABLES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA pikalov_food GRANT ALL PRIVILEGES ON SEQUENCES TO inspector;
ALTER DEFAULT PRIVILEGES IN SCHEMA pikalov_food GRANT ALL PRIVILEGES ON FUNCTIONS TO inspector;
-- Set the course-required password manually in your local admin session.
