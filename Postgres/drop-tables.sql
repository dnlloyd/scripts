DROP TABLE "Table1" CASCADE;
DROP TABLE "Table2" CASCADE;
COMMIT;

SELECT * FROM information_schema.tables WHERE table_schema = 'public';
SELECT * FROM pg_indexes WHERE schemaname = 'public';
