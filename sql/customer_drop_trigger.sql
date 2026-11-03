-- DDL trigger fired on DROP TABLE (SQL Server / T-SQL).
-- Logs every attempt to drop the Customer table and blocks it.

-- 1. Audit table
IF OBJECT_ID('dbo.DropAudit') IS NULL
CREATE TABLE dbo.DropAudit (
    AuditId     INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NOT NULL,
    ObjectName  NVARCHAR(256) NOT NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

-- 2. Trigger
CREATE OR ALTER TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj SYSNAME = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DropAudit (LoginName, ObjectName, CommandText)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        -- Note: ROLLBACK also undoes the audit insert; remove the next two
        -- lines if you only want to log (allow the drop).
        RAISERROR('Dropping table Customer is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove the trigger (required before the table can be dropped):
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
