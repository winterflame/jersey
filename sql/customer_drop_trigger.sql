-- DDL trigger fired when the Customer table is dropped (SQL Server / T-SQL).
-- Logs every DROP TABLE attempt against Customer and blocks it.
-- To allow the drop, remove the ROLLBACK (keep the audit insert).

-- Audit table
IF OBJECT_ID('dbo.DropAudit', 'U') IS NULL
CREATE TABLE dbo.DropAudit (
    AuditId     INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(256) NULL,
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

    DECLARE @event XML = EVENTDATA();
    DECLARE @table SYSNAME =
        @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @table = 'Customer'
    BEGIN
        INSERT INTO dbo.DropAudit (LoginName, ObjectName, CommandText)
        VALUES (
            @event.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
            @table,
            @event.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- Remove the trigger:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

/* Oracle equivalent:
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the Customer table is not allowed.');
    END IF;
END;
/
*/
