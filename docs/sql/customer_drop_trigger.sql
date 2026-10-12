-- DDL triggers that react to DROP TABLE on the customer table.

-- ===== SQL Server =====
-- Audit table for dropped objects
CREATE TABLE dbo.ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    object_name NVARCHAR(256) NULL,
    command_txt NVARCHAR(MAX) NULL
);
GO

-- Blocks DROP TABLE on customer and logs the attempt
CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) =
        @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF @obj = 'customer'
    BEGIN
        INSERT INTO dbo.ddl_audit_log (login_name, object_name, command_txt)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );
        -- Roll back the drop (the log insert is rolled back too; remove the
        -- ROLLBACK/RAISERROR below if you only want auditing, not blocking).
        RAISERROR('Dropping table customer is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To remove the trigger (needed before the table can be dropped):
-- DROP TRIGGER trg_prevent_drop_customer ON DATABASE;

-- ===== Oracle =====
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table customer is not allowed.');
--     END IF;
-- END;
-- /
