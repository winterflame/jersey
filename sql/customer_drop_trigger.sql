-- Triggers that fire when the customer table is dropped.
-- A DROP TABLE is DDL, so a regular row-level trigger cannot catch it; a
-- DDL / event trigger is required. Variants for SQL Server and PostgreSQL.

-------------------------------------------------------------------------------
-- SQL Server: audit the drop and block it
-------------------------------------------------------------------------------
CREATE TABLE ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_type  NVARCHAR(100),
    object_name NVARCHAR(256),
    login_name  NVARCHAR(256),
    command_txt NVARCHAR(MAX),
    event_time  DATETIME2 DEFAULT SYSDATETIME()
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @e XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) = @e.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO ddl_audit_log (event_type, object_name, login_name, command_txt)
        VALUES (
            @e.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
            @obj,
            @e.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
            @e.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
        ROLLBACK;  -- cancels the DROP TABLE
    END
END;
GO

-- To intentionally drop the table: DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;

-------------------------------------------------------------------------------
-- PostgreSQL: block the drop (event trigger; requires superuser to create)
-------------------------------------------------------------------------------
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
