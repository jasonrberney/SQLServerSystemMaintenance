/*
1) Sproc to check the data integrity of all databases on your SQL Server.

2) Sproc to back all databases on your SQL Server if there is no data integrity error.

3) Sproc to purge the transaction logs for all databases if the backup succeeds. 
*/

USE AdventureWorks2012

/* One method for using CHECKDB on all databases excluding sys dbs
EXEC master..sp_MSForeachdb '
USE [?]
IF ''?'' <> ''master'' AND ''?'' <> ''model'' AND ''?'' <> ''msdb'' AND ''?'' <> ''tempdb''
BEGIN
   DBCC CHECKDB(''?'')
END
'
*/

Create Procedure pCheckDbOnAllSQLServer
/* Author: <JBerney>
** Desc: Checks the logical and physical integrity of all the objects in the database
** Change Log: When,Who,What
** <2018-05-13>,<JBerney>,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
	DECLARE @database_name SYSNAME = NULL

	BEGIN
	   DECLARE database_cursor CURSOR FOR
	   SELECT name 
	   FROM sys.databases db
	   WHERE name NOT IN ('master','model','msdb','tempdb') 
	   AND db.state_desc = 'ONLINE'
	   AND source_database_id IS NULL -- REAL DBS ONLY (Not Snapshots)
	   AND is_read_only = 0

	   OPEN database_cursor
	   FETCH next FROM database_cursor INTO @database_name
	   WHILE @@FETCH_STATUS=0
	   BEGIN

		  EXEC ('dbcc checkdb(''' + @database_name + ''')')

		  FETCH next FROM database_cursor INTO @database_name
	   END

	   CLOSE database_cursor
	   DEALLOCATE database_cursor
	END 
   Set @RC = +1
  End Try
  Begin Catch
   Rollback Transaction
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
go

EXEC pCheckDbOnAllSQLServer

/* ---------------------------------------------------------------------------------------------------- */

Create Procedure pBackupAllDatabases
/* Author: <JBerney>
** Desc: Backs up all databases on the SQL Server
** Change Log: When,Who,What
** <2018-05-13>,<JBerney>,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
	DECLARE @name VARCHAR(50) -- database name  
	DECLARE @path VARCHAR(256) -- path for backup files  
	DECLARE @fileName VARCHAR(256) -- filename for backup  
	DECLARE @fileDate VARCHAR(20) -- used for file name
 
	-- specify database backup directory
	SET @path = 'C:\BackupFiles\'  
 
	-- specify filename format
	SELECT @fileDate = CONVERT(VARCHAR(20),GETDATE(),112) 
 
	DECLARE db_cursor CURSOR READ_ONLY FOR  
	SELECT name 
	FROM master.dbo.sysdatabases 
	WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
 
	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @name   
 
	WHILE @@FETCH_STATUS = 0   
	BEGIN   
	   SET @fileName = @path + @name + '_' + @fileDate + '.BAK'  
	   BACKUP DATABASE @name TO DISK = @fileName  
 
	   FETCH NEXT FROM db_cursor INTO @name   
	END   

	CLOSE db_cursor   
	DEALLOCATE db_cursor

   Set @RC = +1
  End Try
  Begin Catch
   Rollback Transaction
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
go

EXEC pBackupAllDatabases

/* ---------------------------------------------------------------------------------------------------- */

Create Procedure pShrinkDbTranLog
/* Author: <JBerney>
** Desc: Shrink DB Transaction Logs
** Change Log: When,Who,What
** <2018-05-13>,<JBerney>,Created Sproc.
*/
AS
 Begin
  Declare @RC int = 0;
  Begin Try
	DECLARE @name VARCHAR(50) -- database name
 
	DECLARE db_cursor CURSOR FOR  
	SELECT name 
	FROM sys.databases db
	WHERE name NOT IN ('master','model','msdb','tempdb')  -- exclude these databases
	AND db.state_desc = 'ONLINE'
	AND source_database_id IS NULL -- REAL DBS ONLY (Not Snapshots)
	AND is_read_only = 0
 
	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @name   
 
	WHILE @@FETCH_STATUS = 0   
	BEGIN  

	   DBCC SHRINKDATABASE(@name)
 
	   FETCH NEXT FROM db_cursor INTO @name   
	END   

	CLOSE db_cursor   
	DEALLOCATE db_cursor

   Set @RC = +1
  End Try
  Begin Catch
   Rollback Transaction
   Print Error_Message()
   Set @RC = -1
  End Catch
  Return @RC;
 End
go

EXEC pShrinkDbTranLog