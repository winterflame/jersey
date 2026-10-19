-- Triggers that guard and audit DROP TABLE on the CUSTOMER table.
-- Table-level DROP is a DDL event, so a DDL (event) trigger is needed;
-- ordinary row triggers cannot fire on DROP TABLE.
-- Pick the section for your database.

------------------------------------------------------------------------
-- SQL Server: DDL trigger (blocks the drop and logs the attempt)
------------------------------------------------------------------------
CREATE TABLE ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    event_type  NVARCHAR(100) NOT NULL,
    object_name NVARCHAR(256) NULL,
    command_txt NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj SYSNAME = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO ddl_audit_log (login_name, event_type, object_name, command_txt)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @evt.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR ('Dropping table CUSTOMER is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove the guard before an intentional drop:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

------------------------------------------------------------------------
-- Oracle: schema-level BEFORE DROP trigger
------------------------------------------------------------------------
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
--     END IF;
-- END;
-- /

------------------------------------------------------------------------
-- PostgreSQL: event trigger on sql_drop (aborts the dropping transaction)
------------------------------------------------------------------------
-- CREATE OR REPLACE FUNCTION fn_prevent_drop_customer() RETURNS event_trigger AS $$
-- DECLARE
--     obj RECORD;
-- BEGIN
--     FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
--         IF obj.object_type = 'table' AND obj.object_name = 'customer' THEN
--             RAISE EXCEPTION 'Dropping table customer is not allowed.';
--         END IF;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_prevent_drop_customer
--     ON sql_drop
--     EXECUTE FUNCTION fn_prevent_drop_customer();
