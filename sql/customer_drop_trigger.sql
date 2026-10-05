-- Triggers that fire when the Customer table is dropped.
-- Each one audits the attempt and blocks the drop.

---------------------------------------------------------------------
-- SQL Server (DDL trigger)
---------------------------------------------------------------------
CREATE TABLE dbo.DdlAuditLog (
    LogId      INT IDENTITY(1,1) PRIMARY KEY,
    EventTime  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName  NVARCHAR(128) NOT NULL,
    EventType  NVARCHAR(100) NOT NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj SYSNAME =
        @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DdlAuditLog (LoginName, EventType, CommandText)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @evt.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

---------------------------------------------------------------------
-- Oracle (schema-level DDL trigger)
---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the Customer table is not allowed.');
    END IF;
END;
/

---------------------------------------------------------------------
-- PostgreSQL (event trigger; requires superuser)
---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_drop_customer()
RETURNS event_trigger AS $$
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
EXECUTE FUNCTION fn_prevent_drop_customer();
