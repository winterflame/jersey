-- DDL triggers that fire when the CUSTOMER table is dropped.
-- Row-level triggers cannot fire on DROP TABLE; a DDL trigger is required.

--------------------------------------------------------------------
-- SQL Server (T-SQL): log the attempt and block the drop
--------------------------------------------------------------------
CREATE TABLE dbo.DropAuditLog (
    LogId       INT IDENTITY(1,1) PRIMARY KEY,
    EventTime   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    LoginName   NVARCHAR(128) NOT NULL,
    ObjectName  NVARCHAR(256) NULL,
    CommandText NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj SYSNAME =
        @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'SYSNAME');

    IF @obj = N'customer'
    BEGIN
        INSERT INTO dbo.DropAuditLog (LoginName, ObjectName, CommandText)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        RAISERROR('Dropping table CUSTOMER is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- Remove the trigger when a drop is legitimately required:
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

--------------------------------------------------------------------
-- Oracle (PL/SQL): block the drop
--------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
BEFORE DROP ON SCHEMA
BEGIN
    IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
    END IF;
END;
/
