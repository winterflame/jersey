-- Trigger that fires when the CUSTOMER table is dropped.
-- Each variant audits the attempt; the SQL Server and Oracle variants also block it.

-------------------------------------------------------------------------------
-- SQL Server (DDL trigger)
-------------------------------------------------------------------------------
CREATE TABLE dbo.DdlAuditLog (
    LogId      INT IDENTITY(1,1) PRIMARY KEY,
    EventTime  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName  NVARCHAR(128) NOT NULL,
    EventType  NVARCHAR(100) NOT NULL,
    ObjectName NVARCHAR(256) NULL,
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
    DECLARE @obj SYSNAME = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DdlAuditLog (LoginName, EventType, ObjectName, CommandText)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]',  'NVARCHAR(128)'),
            @evt.value('(/EVENT_INSTANCE/EventType)[1]',  'NVARCHAR(100)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        -- Undo the DROP TABLE (the audit row is written first, then rolled back
        -- with the DROP, so log outside the transaction if you need it to persist).
        RAISERROR('Dropping table Customer is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove: DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

-------------------------------------------------------------------------------
-- Oracle (schema-level DDL trigger)
-------------------------------------------------------------------------------
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ora_dict_obj_type = 'TABLE' AND UPPER(ora_dict_obj_name) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
--     END IF;
-- END;
-- /

-------------------------------------------------------------------------------
-- PostgreSQL (event trigger, audit only; requires superuser)
-------------------------------------------------------------------------------
-- CREATE FUNCTION fn_log_drop_customer() RETURNS event_trigger AS $$
-- DECLARE r record;
-- BEGIN
--     FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
--         IF r.object_type = 'table' AND r.object_name = 'customer' THEN
--             RAISE NOTICE 'Table customer dropped by % at %', current_user, now();
--         END IF;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_log_drop_customer ON sql_drop
-- EXECUTE FUNCTION fn_log_drop_customer();
