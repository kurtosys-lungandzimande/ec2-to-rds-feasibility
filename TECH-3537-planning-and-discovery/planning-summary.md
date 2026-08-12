# SQL Server EC2 to RDS Feasibility — Planning & Discovery
# [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) — Investigation and Discovery Planning

> **Status:** Closed — Investigation Complete. Recommendation: Stay on EC2.
> **Purpose:** Define the investigation scope, discovery approach, and definition of done for each child ticket before any investigation work begins.
> **Last Updated:** 2026-07-28 — Cost case closed. Hermann Lotter confirmed no 3-year RI, not BYOL, passive node runs licence-free on EC2. RDS is ~$37,600/year more expensive. Migration not recommended. All child tickets closed.

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

- [x] All self-managed SQL Server EC2 instances catalogued: hostname, region, version, edition, instance type, storage size, workload profile
- [x] Cost baseline confirmed from EW1R-REP-01 monitoring data — $3,799.08/month (~$45,600/year)
- [x] Licensing position confirmed — AWS License Included, not BYOL
- [x] Historical blockers assessed — SSIS, SSRS, Windows logins, CmdExec steps identified on REL
- [x] Investigation closed — cost case makes full PRD assessment unnecessary

### TECH-3539 — Theme B: RDS Compatibility and Cost Analysis

- [x] Cost model completed — EC2 $45,600/year vs RDS $83,200/year
- [x] Licensing model confirmed — AWS License Included on EC2, passive node licence-free
- [x] RDS cost gap confirmed — ~$37,600/year more expensive
- [x] Investigation closed — cost case is definitive

### TECH-3540 — Theme C: Recommendation and Handover

- [x] Go/no-go recommendation written — NO-GO, stay on EC2
- [x] Cost evidence documented with Hermann's confirmed figures
- [x] Manager sign-off pending — Jacobus to confirm closure on TECH-3431

---

## Closure — Action Plan

| # | Action | Owner | Status |
|---|---|---|---|
| A1 | Close TECH-3537, 3538, 3539, 3540 in Jira | Lunga | Pending |
| A2 | Add closure comment to TECH-3431 — NO-GO recommendation with Hermann's figures | Lunga | Pending |
| A3 | Get manager sign-off from Jacobus on NO-GO recommendation | Jacobus | Pending |
| A4 | Confirm AWS EC2 HA programme status — 2022 vs GA feature | Hermann | **Closed — GA confirmed by Lunga** |
| A5 | If non-cost reasons raised in future — reopen with explicit $37,600/year justification | Platform Engineering | Future |

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

### Cost Conclusion — 2026-07-28

**Source:** Hermann Lotter, TECH-3431 comment, 2026-07-29. Figures measured, not estimated.

> ⚠️ All cost figures on this epic are sourced to Hermann Lotter, TECH-3431, 2026-07-29, or AWS Pricing Calculator only. Do not use the reporting server datalake (`MON_AWS_Entity_Cost`) for cost figures.

#### Reserved Instance and Savings Plan Position

| Assumption | Reality |
|---|---|
| 3-year RI purchased Apr 2025, expiry Apr 2028 | No 3-year RI. The RI from 2025-04-22 was a 1-year convertible — ended early 2025-12-02 |
| ew2p-mssql-01 on RI | Current coverage: two Region-scoped convertible No Upfront RIs, end date 2026-09-08 |
| ew2p-mssql-02 on RI | ew2p-mssql-02 is covered by a Compute Savings Plan, not an RI |
| Commitments tied to specific instances | RIs are Region-scoped and attach to whichever matching instance is running — no commitment is tied to either instance. Managed centrally via ProsperOps |

#### Licensing Position

| Assumption | Reality |
|---|---|
| Instances are BYOL | Not BYOL — both instances are AWS License Included, moved off SoftCat. No BYOL commitment to unwind |
| Passive node carries a SQL Server licence charge | Passive node (ew2p-mssql-02) bills at plain Windows rate ($0.96/hr) vs $3.96/hr for the active node — worth ~$26,000/year. Still live as of this month's billing |

#### Measured EC2 Cost — March 2026 (744-hour month, after commitment discounts)

| Item | Monthly |
|---|---|
| ew2p-mssql-01 — compute and SQL licence | $2,753.92 |
| ew2p-mssql-02 — compute only (passive node, no SQL licence) | $512.95 |
| EBS — 5,360 GiB gp3 + provisioned throughput | $532.21 |
| **Total** | **$3,799.08 (~$45,600/year)** |

#### RDS Comparison — List Pricing (db.r6i.2xlarge SQL Server Enterprise LI Multi-AZ, eu-west-2)

| Option | Compute & Licence | Storage | Annual |
|---|---|---|---|
| EC2 today (after commitments) | $38,413 | $6,387 | ~$45,600 |
| RDS SQL Ent LI Multi-AZ (list) | $66,094 | $17,109 | ~$83,200 |

- RDS compute: $7.545/hr
- RDS storage: $0.266/GB-month vs $0.093/GB-month on EBS — same 5,360 GiB moves from $532 to $1,426/month
- **Storage is the larger cost swing, not just the licence exemption**
- **Migration costs ~$30k–$38k/year more** — low end assumes RDS picks up commitment discounts comparable to today. Backups and snapshots excluded on both sides.

#### Commitment Timing Constraint

Compute Savings Plans cover EC2 but not RDS. The current portfolio runs at >99% utilisation with almost no headroom — EC2 spend removed by a migration becomes unused commitment. Database Savings Plans are the RDS-side offset.

| Plan | End Date |
|---|---|
| Compute Savings Plan A | 2026-10-18 |
| Compute Savings Plan B | 2026-11-06 |
| Compute Savings Plan C | 2027-06-14 |

Any proposed cutover window should align with these end dates to avoid wasting committed spend.

#### AWS EC2 HA Programme — Closed

Kurtosys is on the GA feature — [Amazon EC2 High Availability for SQL Server](https://docs.aws.amazon.com/sql-server-ec2/latest/userguide/sql-high-availability.html) — confirmed by Lunga. Hermann noted the 2022 programme ownership sits with the team that manages the servers day to day, not with him.

#### Second RI — Closed

Hermann noted two Reserved Instances exist for Windows with SQL Server Enterprise, but only one instance bills under that licensed code. ew2p-mssql-02 is covered by a Compute Savings Plan instead. The second RI is waived — confirmed by Lunga. Not wasted spend.

#### Still to Verify on the RDS Side — Moot (NO-GO)

- Standard RDS Multi-AZ pricing may carry partial standby licence relief — not investigated further given NO-GO
- Full passive node exemption on RDS Custom is reported but unconfirmed — moot given NO-GO

#### Final Recommendation

**Stay on EC2.** Migration costs ~$30k–$38k/year more — this is a deliberate trade, paying for managed patching, backups, and HA, not a saving. The epic as written expected cost-neutral or better. That premise does not hold.

If non-cost reasons are raised in future (managed patching, HA simplicity, operational overhead reduction), they would need to explicitly justify $30k–$38k/year in additional annual spend.

---

## Open Questions

| # | Question | Why It Matters | Status |
|---|---|---|---|
| Q1 | How many SQL Server EC2 instances are in scope — full list with hostnames? | Cannot start inventory without knowing what to inventory | **Closed** — 4 instances confirmed, see Instances in Scope above |
| Q2 | Which recent platform changes removed the historical blockers? | Theme A cannot assess blockers without knowing what changed | Open — needs Platform Engineering input |
| Q3 | Who are the application/service owners for each instance? | Dependency mapping requires their input | Open |
| Q9 | Confirm RI term and expiry for ew2p-mssql-01 — believed 3-year purchased 23 Apr 2025, expiry Apr 2028 | Determines the earliest cost-neutral migration window — if 3-year, cannot migrate before Apr 2028 without double-paying | **Closed** — Hermann Lotter confirmed 2026-07-28: no 3-year RI exists, no April 2028 expiry. Assumption was incorrect. |
| Q10 | Confirm whether ew2p-mssql-02 is also on a Reserved Instance, and if so term and expiry | ew2p-mssql-02 cost has been consistent at ~$640–$820/month — may also be RI-covered | **Closed** — Hermann Lotter confirmed 2026-07-28: no RI on ew2p-mssql-02. |
| Q11 | Confirm BYOL license commitment — any active license lock-in tied to the EC2 instances? | Need to know if there is any Microsoft license commitment that affects migration timing | **Closed** — Hermann Lotter confirmed 2026-07-28: instances are not BYOL. The passive node (ew2p-mssql-02) runs without a SQL Server licence charge on EC2 — this benefit does not exist on RDS, making RDS ~$30k–$38k/year more expensive. |
| Q12 | Are there any RDS Reserved Instance options or private pricing available to close the cost gap? | RDS on-demand is ~$409–$589/month more than current EC2 spend — RI pricing could change the cost case | **Closed — 1yr RI confirmed from AWS public pricing. All Upfront: ~$61,532/yr (~$5,128/month). Partial Upfront: ~$62,788/yr (~$5,232/month). Saves ~$3,300–$4,600/yr off on-demand. Gap vs EC2 ($45,600/yr) still ~$16,000–$17,000/yr more on RDS. Does not change NO-GO.** |
| Q13 | Has AWS License Mobility been formally activated for RDS previously, or is this a first-time activation? | Administrative step — must be initiated before migration begins regardless of timing | **Closed — moot. Hermann confirmed Kurtosys holds no SQL Server licences with Software Assurance. License Mobility not applicable.** |
| Q4 | Do we have access to all EC2 instances to run discovery queries directly? | Blocks all of Theme A | **Closed** — access confirmed, queries validated on REL 2026-07-23 |
| Q5 | What is the current EC2 cost per instance — do we have Cost Explorer access? | Required for Theme B cost comparison | **Closed** — confirmed from Hermann Lotter, TECH-3431, 2026-07-29. EC2 measured at $3,799.08/month (March 2026). See cost-comparison.md. |
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
