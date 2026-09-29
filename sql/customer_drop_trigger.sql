-- Trigger that fires when the CUSTOMER table is dropped.
-- Each variant logs the attempt; the SQL Server / Oracle variants also block the drop.

------------------------------------------------------------------
-- SQL Server (DDL trigger)
------------------------------------------------------------------
CREATE TABLE dbo.ddl_audit_log (
    id          INT IDENTITY PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    command     NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @obj SYSNAME =
        EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO dbo.ddl_audit_log (login_name, command)
        VALUES (ORIGINAL_LOGIN(),
                EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'));

        RAISERROR ('Dropping table CUSTOMER is not allowed.', 16, 1);
        ROLLBACK;  -- cancels the DROP TABLE
    END
END;
GO
-- To allow the drop: DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;

------------------------------------------------------------------
-- Oracle (schema-level DDL trigger)
------------------------------------------------------------------
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
--     END IF;
-- END;
-- /

------------------------------------------------------------------
-- PostgreSQL (event trigger; requires superuser)
------------------------------------------------------------------
-- CREATE TABLE ddl_audit_log (
--     id BIGSERIAL PRIMARY KEY,
--     event_time TIMESTAMPTZ NOT NULL DEFAULT now(),
--     user_name TEXT NOT NULL DEFAULT current_user,
--     object_identity TEXT
-- );
--
-- CREATE OR REPLACE FUNCTION log_customer_drop() RETURNS event_trigger AS $$
-- DECLARE r RECORD;
-- BEGIN
--     FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
--         IF r.object_type = 'table' AND r.object_name = 'customer' THEN
--             INSERT INTO ddl_audit_log (object_identity) VALUES (r.object_identity);
--             -- PostgreSQL cannot cancel a drop from sql_drop; raise here to roll it back:
--             RAISE EXCEPTION 'Dropping table customer is not allowed.';
--         END IF;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_drop_customer ON sql_drop
--     EXECUTE FUNCTION log_customer_drop();
