-- Triggers that fire when the CUSTOMER table is dropped.
-- Each variant audits the attempt and blocks the drop.
-- Pick the section for your database.

------------------------------------------------------------------
-- SQL Server (DDL trigger)
------------------------------------------------------------------
CREATE TABLE dbo.ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NULL,
    event_type  NVARCHAR(100) NULL,
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
    DECLARE @e XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) = @e.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @obj = N'customer'
    BEGIN
        INSERT INTO dbo.ddl_audit_log (login_name, event_type, object_name, command_txt)
        VALUES (
            @e.value('(/EVENT_INSTANCE/LoginName)[1]',  'NVARCHAR(128)'),
            @e.value('(/EVENT_INSTANCE/EventType)[1]',  'NVARCHAR(100)'),
            @obj,
            @e.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

------------------------------------------------------------------
-- Oracle (schema-level DDL trigger)
------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the customer table is not allowed.');
    END IF;
END;
/

------------------------------------------------------------------
-- PostgreSQL (event trigger; requires superuser)
------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_drop_customer()
RETURNS event_trigger
LANGUAGE plpgsql AS $$
DECLARE
    obj record;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
        IF obj.object_type = 'table' AND obj.object_name = 'customer' THEN
            RAISE EXCEPTION 'Dropping the customer table is not allowed.';
        END IF;
    END LOOP;
END;
$$;

CREATE EVENT TRIGGER trg_prevent_drop_customer
ON sql_drop
EXECUTE FUNCTION fn_prevent_drop_customer();

-- To remove a trigger when a drop is genuinely intended:
--   SQL Server : DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
--   Oracle     : DROP TRIGGER trg_prevent_drop_customer;
--   PostgreSQL : DROP EVENT TRIGGER trg_prevent_drop_customer;
