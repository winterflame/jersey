-- ============================================================
-- SQL Server: DDL trigger that fires on DROP TABLE.
-- Blocks the drop when the table is "Customer" and logs the attempt.
-- ============================================================
CREATE TABLE dbo.DropAuditLog (
    LogId       INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NULL,
    ObjectName  NVARCHAR(128) NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

CREATE OR ALTER TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj NVARCHAR(128) = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DropAuditLog (LoginName, ObjectName, CommandText)
        VALUES (@evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
                @obj,
                @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'));

        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To intentionally drop the table later:
-- DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
-- DROP TABLE dbo.Customer;
-- ENABLE TRIGGER trg_prevent_drop_customer ON DATABASE;

-- ============================================================
-- PostgreSQL equivalent (event trigger)
-- ============================================================
-- CREATE OR REPLACE FUNCTION fn_prevent_drop_customer() RETURNS event_trigger AS $$
-- DECLARE obj record;
-- BEGIN
--   FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects() WHERE object_type = 'table' LOOP
--     IF obj.object_name = 'customer' THEN
--       RAISE EXCEPTION 'Dropping the customer table is not allowed.';
--     END IF;
--   END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
--
-- CREATE EVENT TRIGGER trg_prevent_drop_customer ON sql_drop
--   EXECUTE FUNCTION fn_prevent_drop_customer();

-- ============================================================
-- Oracle equivalent
-- ============================================================
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--   IF ORA_DICT_OBJ_TYPE = 'TABLE' AND ORA_DICT_OBJ_NAME = 'CUSTOMER' THEN
--     RAISE_APPLICATION_ERROR(-20001, 'Dropping the CUSTOMER table is not allowed.');
--   END IF;
-- END;
-- /
