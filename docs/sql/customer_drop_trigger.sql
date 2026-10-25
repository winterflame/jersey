-- DDL trigger that fires when a table is dropped and blocks the drop
-- if the table is "Customer". Dialect: SQL Server (T-SQL).

-- Optional audit table for attempted drops.
IF OBJECT_ID('dbo.DdlAuditLog') IS NULL
    CREATE TABLE dbo.DdlAuditLog (
        LogId      INT IDENTITY(1,1) PRIMARY KEY,
        EventTime  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
        LoginName  NVARCHAR(256) NOT NULL,
        EventType  NVARCHAR(128) NOT NULL,
        ObjectName NVARCHAR(256) NULL,
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
    DECLARE @table SYSNAME =
        @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @table = N'Customer'
    BEGIN
        INSERT INTO dbo.DdlAuditLog (LoginName, EventType, ObjectName, CommandText)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)'),
            @evt.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(128)'),
            @table,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        -- Roll back the DROP TABLE statement.
        ROLLBACK;
        THROW 50001, 'Dropping the Customer table is not allowed.', 1;
    END
END;
GO

-- To intentionally drop the table later:
--   DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
--   DROP TABLE dbo.Customer;
--   ENABLE TRIGGER trg_prevent_drop_customer ON DATABASE;
--
-- MySQL/PostgreSQL note: MySQL has no DDL triggers. PostgreSQL equivalent is
-- an EVENT TRIGGER on ddl_command_start / sql_drop calling a plpgsql function.
