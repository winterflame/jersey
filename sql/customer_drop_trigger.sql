-- DDL trigger that fires when the Customer table is dropped (SQL Server).
-- It logs the attempt to an audit table and blocks the drop.

CREATE TABLE dbo.DropAudit (
    AuditId     INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NOT NULL,
    ObjectName  NVARCHAR(128) NOT NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @evt  XML           = EVENTDATA();
    DECLARE @name NVARCHAR(128) = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @name = 'Customer'
    BEGIN
        -- Insert first, then roll back would erase the row, so log after the rollback.
        DECLARE @login NVARCHAR(128) = @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)');
        DECLARE @cmd   NVARCHAR(MAX) = @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)');

        ROLLBACK;

        INSERT INTO dbo.DropAudit (LoginName, ObjectName, CommandText)
        VALUES (@login, @name, @cmd);

        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
    END
END;
GO

-- To remove the trigger:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
