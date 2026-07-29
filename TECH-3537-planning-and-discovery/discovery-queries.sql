-- ============================================================
-- EC2 to RDS Feasibility — Discovery & Verification Queries
-- All queries are READ-ONLY. No changes are made to any data.
--
-- Two connection contexts are used:
--   A) Run directly on ew2p-mssql-01 (PRD) via SSMS
--   B) Run on EW1R-REP-01 via SSMS — uses OPENQUERY through
--      linked servers or reads from DBA_VCC_AWS monitoring data
--
-- Author  : DBA Discovery Pass — 2026
-- Status  : COMPLETE for REL (ew1r-mssql-01) — 2026-07-23
--           COMPLETE for PRD via OPENQUERY — 2026-07-24
--           Cost investigation queries added — 2026-07-24
-- ============================================================


-- ============================================================
-- SECTION 1 — INSTANCE BASICS
-- Run on: ew2p-mssql-01 directly, OR via OPENQUERY on EW1R-REP-01
-- Purpose: Confirm SQL Server version, edition, collation, HA status
-- Expected: SQL Server 2019 (15.0.4455.2) CU32, Enterprise Edition,
--           Latin1_General_CI_AS, Always On enabled
-- ============================================================

-- 1.1 Run directly on PRD instance
SELECT
    SERVERPROPERTY('ServerName')        AS server_name,
    SERVERPROPERTY('ProductVersion')    AS version,
    SERVERPROPERTY('ProductLevel')      AS patch_level,
    SERVERPROPERTY('Edition')           AS edition,
    SERVERPROPERTY('EngineEdition')     AS engine_edition,
    SERVERPROPERTY('Collation')         AS collation,
    SERVERPROPERTY('IsClustered')       AS is_clustered,
    SERVERPROPERTY('IsHadrEnabled')     AS is_hadr_enabled;

-- 1.2 Via OPENQUERY on EW1R-REP-01 (no direct PRD access needed)
-- Replace [EW2P-MSSQL-01] with the exact linked server name on EW1R-REP-01
SELECT * FROM OPENQUERY([EW2P-MSSQL-01], '
    SELECT
        SERVERPROPERTY(''ServerName'')      AS server_name,
        SERVERPROPERTY(''ProductVersion'')  AS version,
        SERVERPROPERTY(''Edition'')         AS edition,
        SERVERPROPERTY(''Collation'')       AS collation,
        SERVERPROPERTY(''IsHadrEnabled'')   AS is_hadr_enabled
');


-- ============================================================
-- SECTION 2 — DATABASE INVENTORY
-- Run on: ew2p-mssql-01 directly
-- Purpose: Full list of user databases — size, recovery model,
--          compatibility level, collation
-- Expected: ~20 user databases, ~803 GB total, all FULL recovery,
--           mostly compat level 130, Latin1_General_CI_AS
-- ============================================================

SELECT
    d.name,
    d.state_desc,
    d.recovery_model_desc,
    d.compatibility_level,
    d.collation_name,
    CAST(SUM(f.size * 8.0 / 1024) AS DECIMAL(10,2))        AS size_mb,
    CAST(SUM(f.size * 8.0 / 1024 / 1024) AS DECIMAL(10,2)) AS size_gb
FROM sys.databases d
JOIN sys.master_files f ON d.database_id = f.database_id
WHERE d.name NOT IN ('master','tempdb','model','msdb')
GROUP BY d.name, d.state_desc, d.recovery_model_desc, d.compatibility_level, d.collation_name
ORDER BY size_gb DESC;


-- ============================================================
-- SECTION 3 — SQL AGENT JOBS
-- Run on: ew2p-mssql-01 directly
-- Purpose: Full job list — enabled status, step types, last run
-- Key things to look for: CmdExec/PowerShell steps (RDS blocker),
--   SSIS steps (RDS blocker), T-SQL steps (supported on RDS)
-- ============================================================

-- 3.1 All jobs with last run outcome
SELECT
    j.name                                          AS job_name,
    j.enabled,
    ISNULL(s.name, 'No schedule')                   AS schedule_name,
    js.last_run_date,
    js.last_run_time,
    CASE js.last_run_outcome
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 3 THEN 'Cancelled'
        ELSE 'Unknown'
    END                                             AS last_outcome
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules jsch ON j.job_id = jsch.job_id
LEFT JOIN msdb.dbo.sysschedules s ON jsch.schedule_id = s.schedule_id
LEFT JOIN msdb.dbo.sysjobservers js ON j.job_id = js.job_id
ORDER BY j.name;

-- 3.2 Job steps — identify CmdExec, PowerShell, SSIS step types
-- subsystem = 'CmdExec'    → not supported on RDS
-- subsystem = 'PowerShell' → not supported on RDS
-- subsystem = 'SSIS'       → not supported on RDS
-- subsystem = 'TSQL'       → supported on RDS
SELECT
    j.name      AS job_name,
    j.enabled,
    s.step_id,
    s.step_name,
    s.subsystem,
    s.database_name
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps s ON j.job_id = s.job_id
ORDER BY j.name, s.step_id;


-- ============================================================
-- SECTION 4 — LINKED SERVERS
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm all outbound linked servers — RDS does not
--          support linked servers. Any active linked server is
--          a blocker unless it can be dropped before migration.
-- Expected: One linked server — UDM_MEM (dead MemSQL) — safe to drop
-- ============================================================

SELECT
    name,
    product,
    provider,
    data_source,
    modify_date
FROM sys.servers
WHERE is_linked = 1
ORDER BY name;


-- ============================================================
-- SECTION 5 — CLR ASSEMBLIES
-- Run on: ew2p-mssql-01 directly
-- Purpose: Identify CLR assemblies and their permission sets
-- SAFE     → supported on RDS
-- EXTERNAL → not supported on RDS
-- UNSAFE   → not supported on RDS — hard blocker
-- Expected: 25 UNSAFE assemblies in SECURITYBENEFIT and RWC
-- ============================================================

-- 5.1 CLR enabled at instance level
SELECT name, value_in_use
FROM sys.configurations
WHERE name = 'clr enabled';

-- 5.2 All user-defined assemblies with permission set
SELECT
    DB_NAME(a.database_id)  AS db_name,
    a.name                  AS assembly_name,
    a.clr_name,
    CASE a.permission_set
        WHEN 1 THEN 'SAFE'
        WHEN 2 THEN 'EXTERNAL_ACCESS'
        WHEN 3 THEN 'UNSAFE'
    END                     AS permission_set,
    a.create_date,
    a.modify_date
FROM sys.assemblies a
WHERE a.is_user_defined = 1
ORDER BY db_name, permission_set DESC, assembly_name;

-- 5.3 Count UNSAFE assemblies per database
SELECT
    DB_NAME(database_id)    AS db_name,
    COUNT(*)                AS unsafe_assembly_count
FROM sys.assemblies
WHERE is_user_defined = 1
AND permission_set = 3
GROUP BY database_id
ORDER BY unsafe_assembly_count DESC;


-- ============================================================
-- SECTION 6 — CROSS-DATABASE DEPENDENCIES
-- Run on: ew2p-mssql-01 directly — run per database
-- Purpose: Confirm no real cross-database queries exist
-- RDS does not support cross-database queries
-- Expected: No real dependencies — false positives only
-- ============================================================

-- Run this in each user database context
SELECT DISTINCT
    OBJECT_NAME(object_id)      AS proc_name,
    DB_NAME()                   AS current_db,
    referenced_database_name    AS target_db
FROM sys.sql_expression_dependencies
WHERE referenced_database_name IS NOT NULL
AND referenced_database_name NOT IN ('master','tempdb','model','msdb')
ORDER BY target_db;


-- ============================================================
-- SECTION 7 — WINDOWS LOGINS AND SERVICE ACCOUNTS
-- Run on: ew2p-mssql-01 directly
-- Purpose: Identify Windows logins — not supported on standard RDS
-- Windows logins for DBA access must be replaced with SQL logins
-- Application logins should already be SQL auth
-- Expected: 10 Windows logins (NT Service*, SHPRD\sqlsrv, SHPRD\ssis),
--           51 SQL logins for all application accounts
-- ============================================================

SELECT
    name,
    type_desc,
    is_disabled,
    create_date,
    modify_date
FROM sys.server_principals
WHERE type IN ('U', 'G', 'S')   -- U=Windows login, G=Windows group, S=SQL login
AND name NOT LIKE '##%'         -- exclude internal accounts
AND name NOT IN ('sa', 'public')
ORDER BY type_desc, name;


-- ============================================================
-- SECTION 8 — DATABASE MAIL
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm Database Mail config — not supported on RDS
-- Must be replaced with Amazon SES or SNS before migration
-- Expected: profile 'dba', account 'dba@kurtosys.com'
-- ============================================================

SELECT
    p.name          AS profile_name,
    a.name          AS account_name,
    a.email_address,
    a.mailserver_name,
    a.port
FROM msdb.dbo.sysmail_profile p
JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id
JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id;


-- ============================================================
-- SECTION 9 — SSRS DATABASES
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm SSRS is installed — not supported on RDS
-- SSRS must be moved to a separate EC2 before migration
-- Expected: ReportServer and ReportServerTempDB present
-- ============================================================

SELECT
    name,
    state_desc,
    recovery_model_desc,
    compatibility_level,
    collation_name
FROM sys.databases
WHERE name IN ('ReportServer', 'ReportServerTempDB', 'SSISDB')
ORDER BY name;


-- ============================================================
-- SECTION 10 — STORAGE LAYOUT
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm file locations, sizes, and growth settings
-- Expected: 4 disks — 80 GB OS, 1,400 GB + 800 GB + 400 GB data
-- ============================================================

SELECT
    DB_NAME(database_id)    AS db_name,
    name                    AS logical_name,
    physical_name,
    type_desc,
    CAST(size * 8.0 / 1024 AS DECIMAL(10,2))    AS size_mb,
    growth,
    is_percent_growth
FROM sys.master_files
ORDER BY size DESC;


-- ============================================================
-- SECTION 11 — FILESTREAM / FILETABLE
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm FILESTREAM is not in use — not supported on RDS
-- Expected: All NULL — no FILESTREAM usage
-- ============================================================

SELECT
    DB_NAME(database_id)    AS db_name,
    type_desc,
    physical_name
FROM sys.master_files
WHERE type = 2  -- FILESTREAM
ORDER BY db_name;


-- ============================================================
-- SECTION 12 — TDE (TRANSPARENT DATA ENCRYPTION)
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm TDE status — supported on RDS
-- If TDE is enabled, the certificate must be exported and
-- imported into RDS before migration
-- ============================================================

SELECT
    d.name                  AS db_name,
    dek.encryption_state,
    CASE dek.encryption_state
        WHEN 0 THEN 'No encryption'
        WHEN 1 THEN 'Unencrypted'
        WHEN 2 THEN 'Encryption in progress'
        WHEN 3 THEN 'Encrypted'
        WHEN 4 THEN 'Key change in progress'
        WHEN 5 THEN 'Decryption in progress'
    END                     AS encryption_state_desc,
    dek.percent_complete,
    dek.key_algorithm,
    dek.key_length
FROM sys.databases d
LEFT JOIN sys.dm_database_encryption_keys dek ON d.database_id = dek.database_id
WHERE d.name NOT IN ('master','tempdb','model','msdb')
ORDER BY d.name;


-- ============================================================
-- SECTION 13 — RESOURCE GOVERNOR
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm Resource Governor status — not supported on RDS
-- If enabled and actively used, workload management must be
-- handled via instance sizing on RDS
-- ============================================================

SELECT
    is_enabled,
    classifier_function_id,
    max_outstanding_io_per_volume
FROM sys.resource_governor_configuration;

SELECT
    name,
    min_cpu_percent,
    max_cpu_percent,
    min_memory_percent,
    max_memory_percent
FROM sys.resource_governor_resource_pools
WHERE name NOT IN ('default', 'internal');


-- ============================================================
-- SECTION 14 — ALWAYS ON AVAILABILITY GROUP STATUS
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm AG topology — primary/secondary, databases in AG
-- RDS Multi-AZ replaces Always On — all AG databases migrate together
-- Expected: ew2p-mssql-01 = primary, ew2p-mssql-02 = secondary
-- ============================================================

-- 14.1 AG overview
SELECT
    ag.name                     AS ag_name,
    ars.role_desc               AS role,
    ar.replica_server_name,
    ars.operational_state_desc,
    ars.synchronization_health_desc
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;

-- 14.2 Databases in the AG
SELECT
    ag.name                     AS ag_name,
    d.name                      AS db_name,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.is_primary_replica
FROM sys.availability_groups ag
JOIN sys.availability_databases_cluster adc ON ag.group_id = adc.group_id
JOIN sys.databases d ON adc.database_name = d.name
JOIN sys.dm_hadr_database_replica_states drs ON d.database_id = drs.database_id
ORDER BY ag_name, db_name;


-- ============================================================
-- SECTION 15 — EC2 COST INVESTIGATION
-- Run on: EW1R-REP-01 (reporting server)
-- Purpose: Investigate the Nov 2025 cost drop on ew2p-mssql-01
--          and confirm the current EC2 baseline for cost comparison
-- Source tables: MON_AWS_Entity_Cost, INFO_AWS_EC2_Detail in DBA_VCC_AWS
-- ============================================================

-- 15.1 Last 60 days of cost data for both PRD nodes
-- Look for the point where ew2p-mssql-01 dropped from ~$103/day to ~$9/day
SELECT TOP 120
    EntityName,
    Period,
    Cost,
    Currency
FROM DBA_VCC_AWS.dbo.MON_AWS_Entity_Cost
WHERE EntityName IN ('ew2p-mssql-01', 'ew2p-mssql-02', 'LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE')
ORDER BY Period DESC, EntityName;

-- 15.2 Monthly average cost per node — full history
-- Shows the cost trend over time — confirms the Feb 2024 downsize
-- and the Oct/Nov 2025 drop as two separate events
SELECT
    EntityName,
    FORMAT(CAST(Period AS DATE), 'yyyy-MM')     AS month,
    AVG(Cost)                                   AS avg_daily_cost,
    SUM(Cost)                                   AS total_monthly_cost,
    COUNT(*)                                    AS days_recorded
FROM DBA_VCC_AWS.dbo.MON_AWS_Entity_Cost
WHERE EntityName IN ('ew2p-mssql-01', 'ew2p-mssql-02')
GROUP BY EntityName, FORMAT(CAST(Period AS DATE), 'yyyy-MM')
ORDER BY month DESC, EntityName;

-- 15.3 Instance type history from EC2 snapshots
-- Confirms whether ew2p-mssql-01 was resized around Oct/Nov 2025
-- Look for a change in InstanceType column around that date
SELECT
    InstanceId,
    InstanceType,
    State,
    DateChecked
FROM DBA_VCC_AWS.dbo.INFO_AWS_EC2_Detail
WHERE Tags LIKE '%mssql%'
   OR InstanceId IN (
       -- Add the actual EC2 instance IDs for ew2p-mssql-01 and ew2p-mssql-02
       -- if known — otherwise the Tags filter above will catch them
       SELECT DISTINCT InstanceId
       FROM DBA_VCC_AWS.dbo.INFO_AWS_EC2_Detail
       WHERE Tags LIKE '%mssql%'
   )
ORDER BY DateChecked DESC;

-- 15.4 Storage layout from EC2 snapshots — confirm disk sizes and encryption
-- Confirms the 80 GB OS disk (unencrypted) + 3 data disks (encrypted)
-- finding from the investigation
SELECT TOP 10
    InstanceId,
    InstanceType,
    StorageInfo,
    DateChecked
FROM DBA_VCC_AWS.dbo.INFO_AWS_EC2_Detail
WHERE Tags LIKE '%mssql%'
ORDER BY DateChecked DESC;

-- 15.5 Current cost baseline — last 30 days combined
-- Use this as the "current" EC2 cost figure for the cost comparison
SELECT
    EntityName,
    AVG(Cost)   AS avg_daily_cost,
    AVG(Cost) * 30 AS estimated_monthly_cost
FROM DBA_VCC_AWS.dbo.MON_AWS_Entity_Cost
WHERE EntityName IN ('ew2p-mssql-01', 'ew2p-mssql-02')
AND Period >= DATEADD(DAY, -30, GETDATE())
GROUP BY EntityName
ORDER BY EntityName;


-- ============================================================
-- SECTION 16 — SSISDB USAGE CONFIRMATION
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm whether SSIS packages are actively running
-- SSISDB is present but SSIS steps were not found in Agent jobs
-- Need to confirm whether packages run via another mechanism
-- ============================================================

-- 16.1 Recent SSIS package executions
SELECT TOP 20
    e.execution_id,
    p.name          AS package_name,
    e.status,
    e.start_time,
    e.end_time,
    DATEDIFF(SECOND, e.start_time, e.end_time) AS duration_sec
FROM SSISDB.catalog.executions e
JOIN SSISDB.catalog.packages p ON e.package_id = p.package_id
ORDER BY e.start_time DESC;

-- 16.2 All SSIS packages deployed
SELECT
    p.name          AS package_name,
    f.name          AS folder_name,
    proj.name       AS project_name,
    p.deployed_by_name,
    p.last_deployed_time
FROM SSISDB.catalog.packages p
JOIN SSISDB.catalog.projects proj ON p.project_id = proj.project_id
JOIN SSISDB.catalog.folders f ON proj.folder_id = f.folder_id
ORDER BY p.last_deployed_time DESC;


-- ============================================================
-- SECTION 17 — BACKUP HISTORY
-- Run on: ew2p-mssql-01 directly
-- Purpose: Confirm backup destination (local disk vs S3)
-- Local disk backups are not supported on RDS — S3 only
-- Expected: Backups going to S3 via Ola Hallengren + S3 upload script
-- ============================================================

SELECT TOP 20
    d.name                          AS db_name,
    b.type,
    b.backup_start_date,
    b.backup_finish_date,
    b.physical_device_name,
    CAST(b.backup_size / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS backup_size_mb
FROM msdb.dbo.backupset b
JOIN sys.databases d ON b.database_name = d.name
JOIN msdb.dbo.backupmediafamily bmf ON b.media_set_id = bmf.media_set_id
WHERE b.backup_start_date >= DATEADD(DAY, -7, GETDATE())
ORDER BY b.backup_start_date DESC;
