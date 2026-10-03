-- Triggers that react to DROP TABLE on the customer table.
-- Row-level triggers cannot fire on DROP; DDL triggers (SQL Server) or
-- event triggers (PostgreSQL) are required.

---------------------------------------------------------------------
-- SQL Server: log the drop attempt, then block it.
---------------------------------------------------------------------
CREATE TABLE ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    event_type  NVARCHAR(100) NOT NULL,
    object_name NVARCHAR(256) NULL,
    command_text NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @e XML = EVENTDATA();
    DECLARE @obj SYSNAME = @e.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = 'customer'
    BEGIN
        ROLLBACK;  -- undo the DROP TABLE
        INSERT INTO ddl_audit_log (login_name, event_type, object_name, command_text)
        VALUES (
            @e.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            'DROP_TABLE (blocked)',
            @obj,
            @e.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );
        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
    END
END;
GO

-- Remove the trigger when the drop is genuinely intended:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

---------------------------------------------------------------------
-- PostgreSQL equivalent: event trigger.
---------------------------------------------------------------------
-- CREATE OR REPLACE FUNCTION fn_prevent_drop_customer() RETURNS event_trigger AS $$
-- DECLARE r record;
-- BEGIN
--     FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
--         IF r.object_type = 'table' AND r.object_name = 'customer' THEN
--             RAISE EXCEPTION 'Dropping the customer table is not allowed.';
--         END IF;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_prevent_drop_customer
--     ON sql_drop EXECUTE FUNCTION fn_prevent_drop_customer();
