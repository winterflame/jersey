-- DDL trigger (SQL Server) that fires when the customer table is dropped.
-- It records the attempt in an audit table and blocks the drop.

CREATE TABLE ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_type  NVARCHAR(100),
    object_name NVARCHAR(256),
    login_name  NVARCHAR(256),
    event_time  DATETIME DEFAULT GETDATE(),
    command_text NVARCHAR(MAX)
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @event XML = EVENTDATA();
    DECLARE @object NVARCHAR(256) =
        @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @object = 'customer'
    BEGIN
        INSERT INTO ddl_audit_log (event_type, object_name, login_name, command_text)
        VALUES (
            @event.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)'),
            @object,
            @event.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
            @event.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR ('Dropping the customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove the trigger:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
