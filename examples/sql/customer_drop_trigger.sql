-- Triggers that fire when the CUSTOMER table is dropped.
-- Each one logs the attempt to an audit table and blocks the drop.
-- Remove the ROLLBACK / RAISE EXCEPTION line if you only want auditing.

------------------------------------------------------------------
-- SQL Server (DDL trigger)
------------------------------------------------------------------
CREATE TABLE ddl_audit_log (
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
    SET NOCOUNT ON;
    DECLARE @e XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) = @e.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO ddl_audit_log (event_type, object_name, login_name, command_text)
        VALUES (
            @e.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
            @obj,
            @e.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
            @e.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );
        RAISERROR('Dropping table CUSTOMER is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove it: DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

------------------------------------------------------------------
-- PostgreSQL (event trigger)
------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ddl_audit_log (
    id          SERIAL PRIMARY KEY,
    event_type  TEXT,
    object_name TEXT,
    login_name  TEXT DEFAULT current_user,
    event_time  TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION fn_prevent_drop_customer() RETURNS event_trigger AS $$
DECLARE
    obj RECORD;
BEGIN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
        IF obj.object_type = 'table' AND obj.object_name = 'customer' THEN
            INSERT INTO ddl_audit_log (event_type, object_name)
            VALUES (TG_TAG, obj.object_identity);
            RAISE EXCEPTION 'Dropping table CUSTOMER is not allowed.';
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER trg_prevent_drop_customer
    ON sql_drop
    WHEN TAG IN ('DROP TABLE')
    EXECUTE FUNCTION fn_prevent_drop_customer();

-- Note: the RAISE EXCEPTION rolls back the audit insert too; log via
-- dblink/NOTIFY if the attempt must be persisted.
-- To remove it: DROP EVENT TRIGGER trg_prevent_drop_customer;
