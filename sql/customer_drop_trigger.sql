-- DDL trigger (SQL Server / T-SQL) fired when a table is dropped.
-- Logs every DROP TABLE on the "customer" table and blocks the drop.

CREATE TABLE dbo.ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(256) NOT NULL,
    object_name NVARCHAR(256) NOT NULL,
    command     NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @evt  XML = EVENTDATA();
    DECLARE @obj  NVARCHAR(256) = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');
    DECLARE @cmd  NVARCHAR(MAX) = @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)');
    DECLARE @user NVARCHAR(256) = @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(256)');

    IF @obj = 'customer'
    BEGIN
        ROLLBACK;  -- cancel the DROP TABLE
        INSERT INTO dbo.ddl_audit_log (login_name, object_name, command)
        VALUES (@user, @obj, @cmd);
        RAISERROR('Dropping the customer table is not allowed.', 16, 1);
    END
END;
GO

-- To remove the trigger later:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;
