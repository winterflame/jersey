-- DDL trigger guarding the Customer table against DROP TABLE (SQL Server / T-SQL).
-- Every attempt is written to an audit table and then rolled back.

IF OBJECT_ID('dbo.DropAudit', 'U') IS NULL
    CREATE TABLE dbo.DropAudit (
        AuditId    INT IDENTITY(1,1) PRIMARY KEY,
        EventTime  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
        LoginName  NVARCHAR(128)  NOT NULL,
        ObjectName NVARCHAR(256)  NULL,
        CommandText NVARCHAR(MAX) NULL
    );
GO

CREATE OR ALTER TRIGGER trg_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) = @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @obj = 'Customer'
    BEGIN
        INSERT INTO dbo.DropAudit (LoginName, ObjectName, CommandText)
        VALUES (ORIGINAL_LOGIN(), @obj,
                @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)'));

        ROLLBACK;
        RAISERROR ('Dropping the Customer table is not allowed.', 16, 1);
    END
END;
GO

-- To allow the drop intentionally:  DISABLE TRIGGER trg_drop_customer ON DATABASE;
-- To remove the trigger:            DROP TRIGGER trg_drop_customer ON DATABASE;

/* Oracle equivalent:

CREATE OR REPLACE TRIGGER trg_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping the CUSTOMER table is not allowed.');
    END IF;
END;
/
*/
