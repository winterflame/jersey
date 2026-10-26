-- Triggers that fire when someone tries to DROP the customer table.
-- Both variants block the drop; remove the rollback/raise to audit only.

-- ===== SQL Server: DDL trigger =====
CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @obj NVARCHAR(128) =
        EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @obj = 'customer'
    BEGIN
        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- ===== PostgreSQL: event trigger =====
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
