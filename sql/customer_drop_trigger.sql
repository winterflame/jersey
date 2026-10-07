-- Triggers that fire when the CUSTOMER table is dropped.
-- Pick the section for your database.

------------------------------------------------------------------
-- SQL Server: DDL trigger that blocks DROP TABLE on dbo.customer
-- and records the attempt in an audit table.
------------------------------------------------------------------
CREATE TABLE dbo.ddl_audit (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_type  NVARCHAR(100),
    object_name NVARCHAR(256),
    login_name  NVARCHAR(256),
    event_time  DATETIME2 DEFAULT SYSDATETIME(),
    command_text NVARCHAR(MAX)
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @obj  NVARCHAR(256) = EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');
    DECLARE @sch  NVARCHAR(256) = EVENTDATA().value('(/EVENT_INSTANCE/SchemaName)[1]', 'NVARCHAR(256)');

    IF @sch = 'dbo' AND @obj = 'customer'
    BEGIN
        INSERT INTO dbo.ddl_audit (event_type, object_name, login_name, command_text)
        VALUES ('DROP_TABLE', @sch + '.' + @obj,
                EVENTDATA().value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
                EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'));

        ROLLBACK;  -- cancels the DROP
        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
    END
END;
GO

-- To remove the protection later:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

------------------------------------------------------------------
-- PostgreSQL: event trigger that blocks dropping the customer table
------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prevent_drop_customer() RETURNS event_trigger AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
        IF obj.object_type = 'table' AND obj.object_name = 'customer' THEN
            RAISE EXCEPTION 'Dropping the customer table is not allowed.';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER trg_prevent_drop_customer
    ON sql_drop
    EXECUTE FUNCTION prevent_drop_customer();

------------------------------------------------------------------
-- Oracle: schema-level BEFORE DROP trigger
------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the customer table is not allowed.');
    END IF;
END;
/
