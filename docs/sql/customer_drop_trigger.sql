-- DDL trigger (SQL Server) that fires when the Customer table is dropped.
-- It logs the attempt to an audit table and blocks the drop.

CREATE TABLE dbo.DropAudit (
    AuditId     INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NOT NULL,
    ObjectName  NVARCHAR(128) NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    DECLARE @obj NVARCHAR(128) =
        EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DropAudit (LoginName, ObjectName, CommandText)
        VALUES (
            ORIGINAL_LOGIN(),
            @obj,
            EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        ROLLBACK;  -- undo the DROP TABLE
        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
    END
END;
GO

-- To allow the drop intentionally:
--   DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
--   DROP TABLE dbo.Customer;
--   ENABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
