-- DDL trigger that fires when the Customer table is dropped (SQL Server / T-SQL).
-- It writes an audit row and then rolls back the DROP to protect the table.
-- To allow the drop, remove the ROLLBACK statement (or disable the trigger).

IF OBJECT_ID('dbo.DdlAuditLog') IS NULL
    CREATE TABLE dbo.DdlAuditLog (
        Id          INT IDENTITY(1,1) PRIMARY KEY,
        EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
        LoginName   NVARCHAR(128) NOT NULL,
        ObjectName  NVARCHAR(256) NULL,
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
    DECLARE @obj NVARCHAR(256) = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');
    DECLARE @cmd NVARCHAR(MAX) = @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DdlAuditLog (LoginName, ObjectName, CommandText)
        VALUES (ORIGINAL_LOGIN(), @obj, @cmd);

        RAISERROR('Dropping the Customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- Disable / remove:
-- DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
