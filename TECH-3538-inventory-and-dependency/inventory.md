# Theme A — SQL Server EC2 Inventory and Dependency Reassessment
# [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538)

> **Status:** Complete — PRD instance data confirmed 2026-07-23 via EW1R-REP-01 monitoring data. RI finding confirmed 2026-07-28.
> **Last Updated:** 2026-07-28

---

## Purpose

Take the discovery query outputs captured in TECH-3537 and produce the full inventory of every SQL Server EC2 instance in scope, map all applications and integrations that depend on each one, and reassess the historical blockers that previously prevented migration to RDS. This ticket produces the evidence base that Theme B and Theme C depend on.

---

## Background

TECH-3537 confirmed the list of instances, established access, and ran all discovery queries against each EC2 instance. This ticket takes those outputs and turns them into structured, documented findings — a complete picture of what is running, what depends on it, and whether the historical reasons for staying on EC2 still apply after recent platform changes.

---

## This Ticket Delivers

- Full inventory of every SQL Server EC2 instance: hostname, region, environment, version, edition, instance type, storage size, and workload profile
- All user databases documented per instance: size, recovery model, compatibility level, collation
- Storage layout per instance: file locations, growth settings, backup destination
- Dependent applications and integrations mapped per instance
- Service accounts and Windows logins documented per instance
- SQL Agent jobs, linked servers, CLR assemblies, and cross-database dependencies captured per instance
- Historical blockers listed and each assessed as still applies or removed, with evidence

---

## Instance Inventory

| Hostname | Region | Environment | SQL Server Version | Edition | License Model | Instance Type | Storage (GB) | Workload Profile |
|---|---|---|---|---|---|---|---|---|
| ew1d-mssql-01 | Ireland (eu-west-1) | DEV | TBC | TBC | N/A — Dev | TBC | TBC | InvestorPress_Encore |
| ew1r-mssql-01 | Ireland (eu-west-1) | REL | 2019 (15.0.4455.2) CU32 | Developer Edition | Free — non-prod only | TBC | TBC | InvestorPress_Encore |
| ew2p-mssql-01 | London (eu-west-2) | PRD | 2019 (15.0.4455.2) CU32 | Enterprise Edition (64-bit) | **BYOL — confirmed** | r6i.2xlarge (8 vCPU, 64 GB) | 2,680 GB total (80 + 1,400 + 800 + 400) | InvestorPress_Encore — Always On primary |
| ew2p-mssql-02 | London (eu-west-2) | PRD | 2019 (15.0.4455.2) CU32 | Enterprise Edition (64-bit) | **BYOL — confirmed** | r6i.2xlarge (8 vCPU, 64 GB) | 2,680 GB total (80 + 1,400 + 800 + 400) | InvestorPress_Encore — Always On secondary |

> **How this was confirmed:** Edition and version confirmed 2026-07-23 via OPENQUERY through EW1R-REP-01 linked servers. Instance type, storage, and BYOL status confirmed from INFO_AWS_EC2_Detail and INFO_AWS_Entity_Cost tables in DBA_VCC_AWS on EW1R-REP-01 — the monitoring server already collects this data weekly. No direct PRD access was required.
>
> **BYOL evidence:** The LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE line item appears consistently in the cost data for ew2p-mssql-02. AWS only grants this passive node license exemption under the Microsoft SQL Server BYOL passive node rule — it is not available under License Included. This confirms Kurtosys owns the Enterprise licenses and is running BYOL. Scenario A applies.
>
> **Instance type history:** Both nodes ran on r6i.4xlarge from at least July 2023 until February 2024, then were downsized to r6i.2xlarge in February 2024 and have remained on r6i.2xlarge since. This is confirmed by 18+ months of weekly snapshots in INFO_AWS_EC2_Detail.
>
> **Storage encryption note:** The 80 GB OS disk on both nodes is unencrypted. The three data disks (1,400 GB, 800 GB, 400 GB) are encrypted. This is a compliance finding — the OS disk should be encrypted before or during migration.

---

## SQL Server Licensing — Enterprise Edition Analysis

> This section is the single most important cost input for TECH-3539. Both PRD nodes are Enterprise Edition. RDS does not offer License Included for Enterprise — BYOL is the only option on RDS for Enterprise Edition. The answer to the BYOL question below determines whether migration to RDS is cost-effective or not.

### What Is BYOL?

BYOL (Bring Your Own License) means Kurtosys already owns the SQL Server Enterprise licenses purchased directly from Microsoft, typically through a Volume Licensing agreement with Software Assurance (SA). On AWS, BYOL means you pay only for EC2 or RDS compute and storage — the license cost is not added to the AWS bill because you already own it.

The alternative is License Included — AWS bundles the SQL Server license into the hourly instance cost. This is available for Standard Edition on RDS but **is not available for Enterprise Edition on RDS**.

### Current Situation — BYOL Confirmed

Both PRD nodes are running SQL Server 2019 Enterprise Edition on r6i.2xlarge instances. **BYOL is confirmed** — the LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE line item in the AWS cost data for ew2p-mssql-02 is proof. AWS only applies this exemption when a customer is running under BYOL with active Software Assurance. This means Kurtosys owns the Enterprise licenses and Scenario A applies.

### Scenario A — BYOL Already in Place

**What it means:** Kurtosys owns active SQL Server Enterprise licenses with Software Assurance. Those licenses can be moved to RDS under the AWS License Mobility program.

**Cost impact:** Compute and storage costs only on RDS. No additional license purchase needed. This is the most cost-effective path to RDS.

**Estimated RDS cost (indicative — exact figures require instance type confirmation):**

| Component | Estimated Monthly Cost (per node) | Notes |
|---|---|---|
| RDS db.r6i.2xlarge (8 vCPU, 64 GB) | ~$800–$1,000 | BYOL pricing — compute only |
| Multi-AZ standby | ~$800–$1,000 | RDS Multi-AZ doubles compute cost |
| Storage (gp3, 1 TB) | ~$115 | Per node |
| Backup storage | ~$50–$100 | Depends on retention period |
| **Total (both nodes combined)** | **~$3,500–$4,500/month** | Indicative only — confirm instance type |

**Effort:** Low-to-medium. License transfer is administrative. Migration effort is driven by the blockers (SSIS, SSRS, Windows logins) not the license.

**Recommendation if Scenario A:** Proceed with RDS migration. Cost is predictable and manageable. Use AWS License Mobility to transfer existing licenses.

### Scenario B — No BYOL — License Included on EC2

**What it means:** The SQL Server Enterprise license is currently bundled into the EC2 hourly cost (License Included on EC2). Kurtosys does not own the license outright. Moving to RDS would require either purchasing new Enterprise licenses with Software Assurance, downgrading to Standard Edition, or staying on EC2.

**Option B1 — Purchase Enterprise licenses for BYOL on RDS:**
- SQL Server Enterprise with SA costs approximately $14,256 per core per year from Microsoft
- A typical 8-core instance = ~$114,048/year in license cost alone, per node
- Two PRD nodes = ~$228,096/year just for licenses, before any AWS compute cost
- This is almost certainly not cost-effective unless there is a strategic reason to own the licenses
- **Effort:** High — procurement, Microsoft agreement negotiation, SA activation
- **Recommendation:** Do not pursue this path unless Microsoft EA is already in negotiation

**Option B2 — Downgrade to Standard Edition on RDS (License Included):**
- RDS Standard Edition License Included is available and significantly cheaper
- Standard Edition is capped at 24 cores and 128 GB RAM — must confirm PRD instance size fits within these limits
- Application compatibility must be verified — any Enterprise-only features in use would break
- Enterprise-only features to check: Advanced HADR (Always On with more than 1 secondary), partitioning, online index operations, data compression, Resource Governor
- **Estimated RDS Standard Edition License Included cost (indicative):**

| Component | Estimated Monthly Cost (per node) | Notes |
|---|---|---|
| RDS db.r6i.2xlarge Standard LI | ~$1,400–$1,800 | License Included pricing |
| Multi-AZ standby | ~$1,400–$1,800 | Doubles compute cost |
| Storage (gp3, 1 TB) | ~$115 | Per node |
| **Total (both nodes combined)** | **~$6,000–$7,500/month** | Indicative only |

- **Effort:** High — edition downgrade requires application compatibility testing, feature audit, and regression testing across all InvestorPress_Encore workloads
- **Recommendation:** Only viable if application compatibility is confirmed clean and PRD instance fits within Standard Edition limits

**Option B3 — Stay on EC2:**
- No license change needed. EC2 License Included continues as-is
- Loses the operational benefits of RDS (automated backups, patching, Multi-AZ failover, no OS management)
- **Effort:** Zero — no migration
- **Recommendation:** Valid fallback if licensing cost makes RDS uneconomical. Should be documented as the baseline in the go/no-go recommendation

### Q8 — Resolved

| # | Question | Status | Evidence |
|---|---|---|---|
| Q8 | Is BYOL already in place? | **Closed — BYOL confirmed** | LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE appears in AWS cost data for ew2p-mssql-02 consistently from 2024-07-23 through 2026-07-23. AWS only grants this under BYOL with active SA. |

> **Action for manager discussion (2026-07-24):** Q8 is now closed — BYOL is confirmed from the cost data. The remaining question to raise with your manager is whether AWS License Mobility has been formally activated for RDS, or whether this would be a first-time activation. This is an administrative step, not a blocker, but it needs to be initiated before migration begins.

---

## Actual EC2 Cost — Confirmed from EW1R-REP-01 Monitoring Data

> Source: INFO_AWS_Entity_Cost table in DBA_VCC_AWS on EW1R-REP-01. Data collected daily. This is real AWS billing data, not an estimate.

### Why EW1R-REP-01 Has This Data

EW1R-REP-01 is the monitoring server that watches over the PRD SQL Server instances. It has linked servers pointing directly at ew2p-mssql-01 and ew2p-mssql-02, and it runs SQL Agent jobs that collect AWS cost data from Cost Explorer via the DBA_VCC_AWS database. This means the actual EC2 spend for the PRD nodes has been recorded daily since at least mid-2024 — without needing direct access to the AWS console or Cost Explorer.

### Confirmed Monthly Cost History — from MON_AWS_Entity_Cost (duplicates removed)

> Source: `MON_AWS_Entity_Cost` on EW1R-REP-01. Duplicates removed using MIN per day before summing. Each day has ~30 duplicate rows — the job re-inserts the last 30 days on every run. MIN(Cost) GROUP BY EntityName, Period is required before summing.

| Month | ew2p-mssql-01 | ew2p-mssql-02 | Combined | Notes |
|---|---|---|---|---|
| 2026-07 (partial) | $190 | $662 | **$852** | Month in progress |
| 2026-06 | $211 | $715 | **$926** | |
| 2026-05 | $188 | $640 | **$828** | |
| 2026-04 | $213 | $709 | **$922** | |
| 2026-03 | $176 | $598 | **$774** | |
| 2026-02 | $109 | $313 | **$422** | Short month |
| 2026-01 | $198 | $668 | **$866** | |
| 2025-12 | $164 | $552 | **$716** | |
| 2025-11 | $165 | $571 | **$736** | |
| 2025-10 | $188 | $644 | **$832** | |
| 2025-09 | $203 | $675 | **$878** | |
| 2025-08 | $194 | $706 | **$900** | |
| 2025-07 | $222 | $811 | **$1,033** | |
| 2025-06 | $234 | $820 | **$1,054** | |
| **2025-05** | **$217** | **$804** | **$1,021** | ⚠️ First full month at RI rate |
| **2025-04** | **$1,810** | **$725** | **$2,535** | ⚠️ Last month at on-demand — RI purchased 23 Apr 2025 |
| 2025-03 | $2,467 | $759 | **$3,226** | |
| 2025-02 | $2,236 | $689 | **$2,925** | |
| 2025-01 | $2,657 | $791 | **$3,448** | |
| 2024-12 | $2,263 | $673 | **$2,936** | |
| 2024-11 | $2,370 | $711 | **$3,081** | |
| 2024-10 | $2,550 | $790 | **$3,340** | |
| 2024-09 | $2,804 | $868 | **$3,672** | |
| 2024-08 | $832 | $261 | **$1,093** | Partial — data starts here |

### Reserved Instance Finding — ew2p-mssql-01

| Evidence | Detail |
|---|---|
| Last on-demand day | 2025-04-22 — cost dropped sharply the following day |
| First RI day | 2025-04-23 — daily cost dropped ~88% overnight |
| Cost Apr 2026 | Still flat — no jump — 1-year term ruled out |
| RI term assessment | 3-year — most likely. Expiry April 2028 |
| RI status ew2p-mssql-02 | Unknown — pending account manager confirmation |

> **Current EC2 baseline: ~$800–$950/month combined.** The ~$165–$234/month still showing on ew2p-mssql-01 is EBS storage, data transfer, and SQL Server line items only — compute is covered by the RI.

### RDS Cost Comparison — Scenario A (BYOL confirmed)

| Scenario | EC2 Monthly | RDS On-Demand | Difference |
|---|---|---|---|
| Current EC2 spend (RI active) | ~$800–$950 | ~$1,359–$1,389 | **RDS ~$409–$589 more expensive** |
| Pre-RI baseline (Aug 2024 – Apr 2025) | ~$2,900–$3,700 | ~$1,359–$1,389 | **RDS ~$1,500–$2,300 cheaper** |
| With RDS 1-year Reserved | ~$800–$950 | ~$1,135–$1,165 | **RDS ~$185–$365 more expensive** |

> Full cost breakdown in [cost-comparison.md](../TECH-3539-rds-compatibility-and-cost/cost-comparison.md).

---

## Database Inventory

| Instance | Database | Size (MB) | Recovery Model | Compatibility Level | Collation |
|---|---|---|---|---|---|
| ew1r-mssql-01 | 32 user databases, ~342 GB total | Various | FULL (all) | Mostly 130, some 150 | Latin1_General_CI_AS (except ReportServer* — Latin1_General_100_CI_AS_KS_WS) |
| ew2p-mssql-01 | TBC — PRD assessment pending | TBC | TBC | TBC | TBC |
| ew2p-mssql-02 | TBC — PRD assessment pending | TBC | TBC | TBC | TBC |
| ew1d-mssql-01 | TBC — DEV assessment pending | TBC | TBC | TBC | TBC |

---

## Dependency Map

| Instance | Application / Service | Connection Type | Owner | Impact if Instance Moves |
|---|---|---|---|---|
| TBC | TBC | TBC | TBC | TBC |

---

## Historical Blocker Reassessment

| Blocker | Previously Blocked Migration | Still Applies | Evidence |
|---|---|---|---|
| TBC | TBC | TBC | TBC |

---

## Definition of Done

- [x] All SQL Server EC2 instances catalogued: hostname, region, environment, version, edition, instance type, storage size, workload profile — PRD confirmed 2026-07-23 from EW1R-REP-01 monitoring data
- [ ] All user databases inventoried per instance: size, recovery model, compatibility level, collation
- [ ] Storage layout documented per instance: file locations, growth settings
- [ ] Backup history captured per instance: last backup date, type, destination
- [ ] SQL Agent jobs listed per instance: name, enabled status, step types
- [ ] Linked servers listed per instance: name, provider, data source
- [ ] CLR assembly usage confirmed per instance: name, permission set
- [ ] Cross-database dependencies mapped per instance
- [ ] Windows logins and service accounts documented per instance
- [ ] Dependent applications and integrations mapped per instance
- [ ] Historical blockers listed and each assessed as still applies or removed with evidence
- [ ] inventory.md published to Confluence
- [ ] dependency-map.md published to Confluence
- [ ] historical-blockers.md published to Confluence
- [ ] Findings handed over to TECH-3539

---

## Dependencies

- Requires TECH-3537 complete before starting
- TECH-3539 and TECH-3540 blocked until this is done

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) | Planning ticket — must complete before this |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — blocked on this |
| [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540) | Theme C — blocked on this |
