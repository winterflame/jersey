-- Triggers fired when the "customer" table is dropped.
-- Each variant blocks the DROP and logs the attempt. Pick the one for your DBMS.

--------------------------------------------------------------------------------
-- SQL Server (DDL trigger)
--------------------------------------------------------------------------------
CREATE TABLE ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    event_type  NVARCHAR(100) NOT NULL,
    command_txt NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @obj NVARCHAR(128) =
        EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO ddl_audit_log (login_name, event_type, command_txt)
        VALUES (
            ORIGINAL_LOGIN(),
            'DROP_TABLE',
            EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR ('Dropping table "customer" is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

--------------------------------------------------------------------------------
-- PostgreSQL (event trigger; requires superuser)
--------------------------------------------------------------------------------
-- CREATE FUNCTION fn_prevent_drop_customer() RETURNS event_trigger AS $$
-- DECLARE obj record;
-- BEGIN
--     FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
--         IF obj.object_type = 'table' AND obj.object_name = 'customer' THEN
--             RAISE EXCEPTION 'Dropping table "customer" is not allowed.';
--         END IF;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_prevent_drop_customer
--     ON sql_drop EXECUTE FUNCTION fn_prevent_drop_customer();

--------------------------------------------------------------------------------
-- Oracle (schema-level DDL trigger)
--------------------------------------------------------------------------------
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
--     END IF;
-- END;
-- /
