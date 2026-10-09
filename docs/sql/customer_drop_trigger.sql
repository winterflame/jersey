-- DDL trigger that fires when the Customer table is dropped.
-- Dialect: SQL Server (T-SQL). An Oracle variant follows at the bottom.

-- 1) Audit table (optional, used by the logging variant).
IF OBJECT_ID('dbo.DropTableAudit') IS NULL
CREATE TABLE dbo.DropTableAudit (
    AuditId     INT IDENTITY(1,1) PRIMARY KEY,
    TableName   SYSNAME       NOT NULL,
    DroppedBy   SYSNAME       NOT NULL,
    DroppedAt   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    CommandText NVARCHAR(MAX) NULL
);
GO

-- 2) Trigger: blocks DROP TABLE on Customer and logs the attempt.
CREATE OR ALTER TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @event XML = EVENTDATA();
    DECLARE @table SYSNAME =
        @event.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @table = N'Customer'
    BEGIN
        INSERT INTO dbo.DropTableAudit (TableName, DroppedBy, CommandText)
        VALUES (@table,
                @event.value('(/EVENT_INSTANCE/LoginName)[1]', 'SYSNAME'),
                @event.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'));

        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To allow the drop: DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;

/* ---------------------------------------------------------------
   Oracle equivalent
   ---------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the CUSTOMER table is not allowed.');
    END IF;
END;
/
--------------------------------------------------------------- */
