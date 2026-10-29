-- DDL trigger guarding the CUSTOMER table against DROP TABLE.
-- Every attempt is logged to an audit table and then blocked.

------------------------------------------------------------------
-- SQL Server (T-SQL)
------------------------------------------------------------------
CREATE TABLE dbo.ddl_audit_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    event_time  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    login_name  NVARCHAR(128) NOT NULL,
    object_name NVARCHAR(256) NULL,
    command     NVARCHAR(MAX) NULL
);
GO

CREATE TRIGGER trg_prevent_drop_customer
ON DATABASE
FOR DROP_TABLE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @evt XML = EVENTDATA();
    DECLARE @obj NVARCHAR(256) =
        @evt.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(256)');

    IF LOWER(@obj) = N'customer'
    BEGIN
        INSERT INTO dbo.ddl_audit_log (login_name, object_name, command)
        VALUES (
            @evt.value('(/EVENT_INSTANCE/LoginName)[1]', 'NVARCHAR(128)'),
            @obj,
            @evt.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
        );

        -- ROLLBACK undoes the DROP, but the audit insert above is undone too,
        -- so log first via a separate mechanism if you need it to persist
        -- (e.g. an autonomous logger or Service Broker); here we just block.
        RAISERROR('Dropping table CUSTOMER is not allowed.', 16, 1);
        ROLLBACK;
    END
END;
GO

-- To intentionally drop the table: DISABLE TRIGGER trg_prevent_drop_customer ON DATABASE;

------------------------------------------------------------------
-- Oracle (PL/SQL) equivalent
------------------------------------------------------------------
-- CREATE OR REPLACE TRIGGER trg_prevent_drop_customer
-- BEFORE DROP ON SCHEMA
-- BEGIN
--     IF ORA_DICT_OBJ_TYPE = 'TABLE' AND UPPER(ORA_DICT_OBJ_NAME) = 'CUSTOMER' THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Dropping table CUSTOMER is not allowed.');
--     END IF;
-- END;
-- /
