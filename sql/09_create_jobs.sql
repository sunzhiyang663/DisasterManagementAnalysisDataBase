-- 第九部分：SQL Agent 定时作业脚本（手动执行版本）
-- 若 SQL Server Agent 不可用，可手动定期执行以下语句：
--
-- 每天过期标记：
--   EXEC sp_MarkExpiredBatches;
--
-- 每 30 分钟释放超时预留：
--   EXEC sp_ReleaseStaleReservations @p_timeout_hours = 2;
--
-- 若 SQL Server Agent 可用，使用以下脚本创建作业：
-- （需要 msdb 权限）

/*
USE msdb;
GO

-- 9.1 过期标记作业（每日凌晨 2:00）
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Job_MarkExpiredBatches')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Job_MarkExpiredBatches';

EXEC msdb.dbo.sp_add_job
    @job_name = N'Job_MarkExpiredBatches',
    @enabled = 1,
    @description = N'每日自动标记过期库存批次';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Job_MarkExpiredBatches',
    @step_name = N'MarkExpired',
    @subsystem = N'TSQL',
    @command = N'EXEC DisasterResourceDB.dbo.sp_MarkExpiredBatches;',
    @database_name = N'DisasterResourceDB';

EXEC msdb.dbo.sp_add_schedule
    @job_name = N'Job_MarkExpiredBatches',
    @name = N'Daily_2AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 20000;

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Job_MarkExpiredBatches',
    @server_name = @@SERVERNAME;
GO

-- 9.2 预留超时释放作业（每 30 分钟）
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'Job_ReleaseStaleReservations')
    EXEC msdb.dbo.sp_delete_job @job_name = N'Job_ReleaseStaleReservations';

EXEC msdb.dbo.sp_add_job
    @job_name = N'Job_ReleaseStaleReservations',
    @enabled = 1,
    @description = N'每30分钟释放超过2小时未确认的预留';

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Job_ReleaseStaleReservations',
    @step_name = N'ReleaseReservations',
    @subsystem = N'TSQL',
    @command = N'EXEC DisasterResourceDB.dbo.sp_ReleaseStaleReservations @p_timeout_hours = 2;',
    @database_name = N'DisasterResourceDB';

EXEC msdb.dbo.sp_add_schedule
    @job_name = N'Job_ReleaseStaleReservations',
    @name = N'Every30Min',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 30;

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'Job_ReleaseStaleReservations',
    @server_name = @@SERVERNAME;
GO
*/

