# SQL Server EC2 to RDS Feasibility — Planning & Discovery
# [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) — Investigation and Discovery Planning

> **Status:** In Progress
> **Purpose:** Define the investigation scope, discovery approach, and definition of done for each child ticket before any investigation work begins.
> **Last Updated:** 2026-07-23 — Discovery queries validated live on ew1r-mssql-01 (REL). Early findings documented below.

---

## What This Ticket Delivers

- Repo and folder structure set up
- Discovery query plan for EC2 inventory
- Definition of Done for TECH-3538, 3539, and 3540
- Open questions and blockers identified before investigation starts

---

## Scope Reminder

**In scope:**
- Inventory of self-managed SQL Server EC2 instances
- Reassessment of historical blocking dependencies
- RDS feature and version compatibility analysis
- Licensing and cost comparison
- High-level migration approach options
- Go/no-go recommendation

**Out of scope:**
- Any migration execution
- Pilot cutover or production instance moves
- Application code changes
- Engine change (SQL Server to PostgreSQL — same engine only)

---

## Definition of Done — Per Child Ticket

### TECH-3538 — Theme A: Inventory and Dependency Reassessment

- [ ] All self-managed SQL Server EC2 instances catalogued: hostname, region, version, edition, instance type, storage size, workload profile
- [ ] Dependent applications and integrations mapped per instance
- [ ] Service accounts and connection strings documented per instance
- [ ] Historical blockers listed and each assessed as **still applies** or **removed** with evidence
- [ ] inventory.md, dependency-map.md, and historical-blockers.md published

### TECH-3539 — Theme B: RDS Compatibility and Cost Analysis

- [ ] Feature compatibility matrix completed: agent jobs, linked servers, CLR, cross-database queries, service accounts, unsupported RDS features — each marked as Supported / Not Supported / Workaround Available
- [ ] RDS engine version support confirmed against current EC2 SQL Server versions
- [ ] Licensing model comparison documented: License Included vs BYOL — cost per instance
- [ ] Cost model completed: RDS running cost vs current EC2 spend including HA and backup
- [ ] compatibility-matrix.md, cost-comparison.md, and licensing-analysis.md published

### TECH-3540 — Theme C: Recommendation and Handover

- [ ] Candidate migration approaches documented with downtime and cutover implications (native backup/restore, AWS DMS — documented only, not executed)
- [ ] Risk register completed with mitigation notes
- [ ] Go/no-go recommendation written with evidence from Theme A and Theme B
- [ ] Phased migration outline written for follow-on epic (if recommendation is go)
- [ ] Manager sign-off obtained
- [ ] go-no-go-recommendation.md published

---

## Investigation Approach — Theme A

For each EC2 instance, run the following directly on the SQL Server:

### 1. Instance basics
```sql
SELECT
    SERVERPROPERTY('ServerName')        AS server_name,
    SERVERPROPERTY('ProductVersion')    AS version,
    SERVERPROPERTY('ProductLevel')      AS patch_level,
    SERVERPROPERTY('Edition')           AS edition,
    SERVERPROPERTY('EngineEdition')     AS engine_edition,
    SERVERPROPERTY('Collation')         AS collation,
    SERVERPROPERTY('IsClustered')       AS is_clustered,
    SERVERPROPERTY('IsHadrEnabled')     AS is_hadr_enabled;
```

### 2. Database inventory
```sql
SELECT
    name,
    state_desc,
    recovery_model_desc,
    compatibility_level,
    collation_name,
    SUM(size * 8 / 1024) AS size_mb
FROM sys.databases d
JOIN sys.master_files f ON d.database_id = f.database_id
WHERE name NOT IN ('master','tempdb','model','msdb')
GROUP BY name, state_desc, recovery_model_desc, compatibility_level, collation_name
ORDER BY size_mb DESC;
```

### 3. SQL Agent jobs
```sql
SELECT
    name,
    enabled,
    description
FROM msdb.dbo.sysjobs
ORDER BY enabled DESC, name;
```

### 4. Linked servers
```sql
SELECT
    name,
    provider,
    data_source,
    is_linked
FROM sys.servers
WHERE is_linked = 1
ORDER BY name;
```

### 5. CLR usage
```sql
SELECT
    SERVERPROPERTY('IsSingleUser') AS is_single_user;

SELECT
    name,
    is_clr_enabled
FROM sys.configurations
WHERE name = 'clr enabled';

SELECT
    a.name AS assembly_name,
    a.clr_name,
    DB_NAME(a.database_id) AS db_name
FROM sys.assemblies a
WHERE a.is_user_defined = 1;
```

### 6. Cross-database queries
```sql
SELECT DISTINCT
    OBJECT_NAME(object_id) AS proc_name,
    DB_NAME() AS current_db,
    referenced_database_name AS target_db
FROM sys.sql_expression_dependencies
WHERE referenced_database_name IS NOT NULL
AND referenced_database_name NOT IN ('master','tempdb','model','msdb')
ORDER BY target_db;
```

### 7. Storage layout
```sql
SELECT
    DB_NAME(database_id) AS db_name,
    name AS logical_name,
    physical_name,
    type_desc,
    size * 8 / 1024 AS size_mb,
    growth,
    is_percent_growth
FROM sys.master_files
ORDER BY size DESC;
```

---

---

## Instances in Scope

| Instance | Environment | Region | Hostname | IP |
|---|---|---|---|---|
| ew1d-mssql-01 | DEV | Ireland (eu-west-1) | ew1d-mssql-01.dev.kurtosys-internal.net | 10.62.10.5 |
| ew1r-mssql-01 | REL | Ireland (eu-west-1) | ew1r-mssql-01.gen-rel.kurtosys-internal.net | 10.79.22.22 |
| ew2p-mssql-01 | PRD | London (eu-west-2) | ew2p-mssql-01.gen-prd.kurtosys-internal.net | 10.119.30.57 |
| ew2p-mssql-02 | PRD | London (eu-west-2) | ew2p-mssql-02.gen-prd.kurtosys-internal.net | 10.119.37.228 |

All instances are part of the InvestorPress_Encore workload. REL is the test environment — PRD (ew2p-mssql-01 and ew2p-mssql-02) are the primary migration targets.

---

## Assessment Summary — REL Instance (ew1r-mssql-01)

> Discovery queries validated live on ew1r-mssql-01 on 2026-07-23. REL is a representative sample of what runs in production — same schema, same setup, lower risk. All queries confirmed working and ready to run on PRD.

### Instance Basics

| Property | Value | Notes |
|---|---|---|
| SQL Server Version | 2019 (15.0.4455.2) CU32 | RDS supports SQL Server 2019 ✅ |
| Edition | Developer Edition | REL only — PRD will be Standard or Enterprise ⚠️ |
| Collation | Latin1_General_CI_AS | Supported on RDS — must be set at provisioning time ✅ |
| Always On | Enabled but not in use on REL | PRD has Always On active — RDS Multi-AZ will replace it ⚠️ |
| Windows Auth Only | No — mixed auth | SQL logins exist — cleaner migration path ✅ |

### Database Inventory

- 32 user databases, ~342 GB total, all FULL recovery model
- Compatibility levels: mostly 130 (SQL Server 2016 compat), some 150 (SQL Server 2019 compat)
- Collation consistent across all databases except ReportServer and ReportServerTempDB which use `Latin1_General_100_CI_AS_KS_WS`

### Early Findings — Blockers Identified

| # | Finding | Blocker? | Proposed Solution |
|---|---|---|---|
| 1 | SSISDB present and actively running — SSIS_SFTP_Master.dtsx ran today, 4,413 successful runs | ❌ Hard blocker — SSIS not supported on RDS | Keep SSIS on a dedicated EC2 pointing at RDS, or rewrite as AWS Transfer Family + Lambda |
| 2 | SSRS databases present — ReportServer and ReportServerTempDB | ❌ Blocker — SSRS not supported on RDS | Move SSRS to a separate EC2 or migrate to Power BI |
| 3 | SQL Agent jobs use CmdExec and PowerShell steps — CHECKDB, ReIndex, backup jobs | ⚠️ Rework needed — not supported on RDS | Rewrite maintenance steps as T-SQL — backup jobs become redundant on RDS |
| 4 | Windows logins in use — 6 Windows logins and 1 Windows group | ⚠️ Not supported on RDS | Convert to SQL logins or IAM authentication before migration |
| 5 | UDM_MEM linked server (MemSQL) | ✅ Not a blocker — orphaned | Nothing references it — safe to drop |
| 6 | CLR assemblies | ✅ Clean | None found |
| 7 | Cross-database dependencies | ✅ Clean | Only dead references and query aliases — no real cross-database calls |
| 8 | donovan.vangraan SQL login still active | ⚠️ Security — ex-employee | Disable immediately |

### Executive Summary — What This Means

A straight lift-and-shift of SQL Server from EC2 to RDS is not possible in its current state. Four blockers were identified on REL. None are showstoppers — all have clear solutions. The migration is feasible but requires a phased approach:

- **Phase 1 — Resolve blockers:** Move SSIS to a dedicated EC2, move SSRS to a separate EC2 or Power BI, convert Windows logins to SQL logins, rewrite CmdExec/PowerShell Agent steps as T-SQL
- **Phase 2 — Migrate databases to RDS:** Use native backup/restore, configure RDS Multi-AZ to replace Always On on PRD
- **Phase 3 — Decommission old EC2 instances:** Once stable on RDS and all applications confirmed connecting to new endpoints

### What Is Still Needed Before a Final Recommendation

- PRD assessment not yet done — ew2p-mssql-01 and ew2p-mssql-02 must be assessed. REL is the test environment — PRD is what the business case depends on
- Historical blockers not yet documented — what previously prevented this migration and what has changed must be confirmed with Platform Engineering before TECH-3537 can be closed
- Cost comparison still to come — EC2 vs RDS cost per instance needed for TECH-3539

---

## Open Questions

| # | Question | Why It Matters | Status |
|---|---|---|---|
| Q1 | How many SQL Server EC2 instances are in scope — full list with hostnames? | Cannot start inventory without knowing what to inventory | **Closed** — 4 instances confirmed, see Instances in Scope above |
| Q2 | Which recent platform changes removed the historical blockers? | Theme A cannot assess blockers without knowing what changed | Open — needs Platform Engineering input |
| Q3 | Who are the application/service owners for each instance? | Dependency mapping requires their input | Open |
| Q4 | Do we have access to all EC2 instances to run discovery queries directly? | Blocks all of Theme A | **Closed** — access confirmed, queries validated on REL 2026-07-23 |
| Q5 | What is the current EC2 cost per instance — do we have Cost Explorer access? | Required for Theme B cost comparison | **Closed** — confirmed from `MON_AWS_Entity_Cost` and `INFO_AWS_EC2_Detail` in DBA_VCC_AWS on EW1R-REP-01. No Cost Explorer access needed. See cost-comparison.md. |
| Q6 | Are any instances using SQL Server features known to be unsupported on RDS? | Early signal for compatibility blockers | **Closed** — SSIS, SSRS, CmdExec/PowerShell steps, Windows logins all identified on REL |
| Q7 | What SQL Server versions and editions are currently running across all instances? | Determines RDS engine version options | **Closed** — SQL Server 2019 (15.0.4455.2) CU32, Enterprise Edition confirmed on PRD via OPENQUERY through EW1R-REP-01. REL is Developer Edition. |
| Q8 | Is BYOL licensing already in place or are instances running License Included on EC2? | Required for licensing comparison in Theme B | **Closed** — BYOL confirmed from LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE line item in AWS cost data for ew2p-mssql-02. See inventory.md. |

---

## Links

| Resource | Location |
|---|---|
| Epic | [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) |
| Theme A | [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) |
| Theme B | [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) |
| Theme C | [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540) |
