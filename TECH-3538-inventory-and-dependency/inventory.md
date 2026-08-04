# Theme A — SQL Server EC2 Inventory and Dependency Reassessment
# [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538)

> **Status:** Closed — Investigation complete. Cost case closed by Hermann Lotter 2026-07-29. Full PRD assessment not required — NO-GO recommendation confirmed.
> **Last Updated:** 2026-07-28

---

## Closure — Why This Ticket Is Closed Without Full PRD Assessment

The original plan was to run all discovery queries against all 4 instances (DEV, REL, PRD x2). The cost case was closed by Hermann Lotter on 2026-07-29 before the full PRD assessment was completed.

**Key facts that close this ticket:**
- EC2 costs $45,600/year (measured, March 2026)
- RDS costs $83,200/year (list pricing, db.r6i.2xlarge SQL Ent LI Multi-AZ, eu-west-2)
- Gap: ~$37,600/year more on RDS
- Passive node licence exemption (~$26,000/year) does not exist on RDS
- No BYOL commitment to unwind — AWS License Included
- No 3-year RI — no migration window constraint

Running the full PRD assessment would not change the recommendation. The cost gap is too large to be closed by technical findings.

## Closure — Action Plan

| # | Action | Owner | Status |
|---|---|---|---|
| A1 | Close TECH-3538 in Jira | Lunga | Pending |
| A2 | Note in Jira: full PRD assessment not completed — cost case closed investigation early | Lunga | Pending |
| A3 | If migration is reconsidered in future — complete DEV and PRD assessments as first step | Platform Engineering | Future |

---

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
| ew2p-mssql-01 | London (eu-west-2) | PRD | 2019 (15.0.4455.2) CU32 | Enterprise Edition (64-bit) | **AWS License Included — confirmed 2026-07-29** | r6i.2xlarge (8 vCPU, 64 GB) | 2,680 GB total (80 + 1,400 + 800 + 400) | InvestorPress_Encore — Always On primary |
| ew2p-mssql-02 | London (eu-west-2) | PRD | 2019 (15.0.4455.2) CU32 | Enterprise Edition (64-bit) | **AWS License Included — confirmed 2026-07-29** | r6i.2xlarge (8 vCPU, 64 GB) | 2,680 GB total (80 + 1,400 + 800 + 400) | InvestorPress_Encore — Always On secondary |

> **How this was confirmed:** Edition and version confirmed 2026-07-23 via OPENQUERY through EW1R-REP-01 linked servers. Instance type and storage confirmed from INFO_AWS_EC2_Detail in DBA_VCC_AWS on EW1R-REP-01. License model confirmed by Hermann Lotter 2026-07-29 (TECH-3431) — AWS License Included, moved off SoftCat. No BYOL commitment to unwind.
>
> **Instance type history:** Both nodes ran on r6i.4xlarge from at least July 2023 until February 2024, then were downsized to r6i.2xlarge in February 2024 and have remained on r6i.2xlarge since. This is confirmed by 18+ months of weekly snapshots in INFO_AWS_EC2_Detail.
>
> **Storage encryption note:** The 80 GB OS disk on both nodes is unencrypted. The three data disks (1,400 GB, 800 GB, 400 GB) are encrypted. This is a compliance finding — the OS disk should be encrypted before or during migration.

---

## SQL Server Licensing — AWS License Included (Confirmed 2026-07-29)

> Source: Hermann Lotter, TECH-3431 comment, 2026-07-29.

Both PRD nodes are AWS License Included, having moved off SoftCat. There is no BYOL commitment to unwind. The passive node (ew2p-mssql-02) bills at the plain Windows rate ($0.96/hr) with no SQL Server licence charge — worth ~$26,000/year. This exemption does not exist on RDS.

RDS for SQL Server does not offer License Included for Enterprise Edition. BYOL is the only RDS path for Enterprise. Since Kurtosys does not own the licences, migrating to RDS Enterprise would require purchasing new Enterprise licences with Software Assurance — not cost-effective.

### Q8 — Resolved

| # | Question | Status | Evidence |
|---|---|---|---|
| Q8 | Is BYOL already in place? | **Closed — NOT BYOL. AWS License Included.** | Hermann Lotter confirmed 2026-07-29 on TECH-3431. Moved off SoftCat. No Microsoft licence commitment to unwind. |

---

## Actual EC2 Cost — Confirmed 2026-07-29

> Source: Hermann Lotter, TECH-3431 comment, 2026-07-29. March 2026, full 744-hour month, both instances plus storage, at the effective rate after commitment discounts. Cross-checked against Cost Explorer to within one percent.

| Item | Monthly |
|---|---|
| ew2p-mssql-01 — compute and SQL licence | $2,753.92 |
| ew2p-mssql-02 — compute only (passive node, no SQL licence) | $512.95 |
| EBS — 5,360 GiB gp3 + provisioned throughput | $532.21 |
| **Total** | **$3,799.08 (~$45,600/year)** |

> **Do not use the datalake CUR table for cost baselines on this epic.** Use Cost Explorer and deduplicated CUR line items only.

### Historical Monthly Cost — from MON_AWS_Entity_Cost (context only)

> Source: `MON_AWS_Entity_Cost` on EW1R-REP-01. Duplicates removed using MIN per day before summing. Provided for context — authoritative figures are from Hermann's Cost Explorer data above.

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

### Commitment Position — Confirmed 2026-07-29

| Item | Confirmed Fact |
|---|---|
| RI on ew2p-mssql-01 | No 3-year RI. 1-year convertible ended 2025-12-02. Current coverage ends 2026-09-08 |
| ew2p-mssql-02 | Covered by Compute Savings Plan (not RI) |
| Compute Savings Plans | End 2026-10-18, 2026-11-06, 2027-06-14. Cover EC2 but not RDS |

> The cost drop seen in April 2025 was a short-term convertible RI managed by ProsperOps, not a 3-year term. Coverage is continuous by design as RIs roll off — which is why cost stayed flat through April 2026.

### RDS Cost Comparison — Confirmed 2026-07-29

| Option | Compute & Licence | Storage | Annual |
|---|---|---|---|
| EC2 today (after commitments) | $38,413 | $6,387 | ~$45,600 |
| RDS SQL Ent LI Multi-AZ (list) | $66,094 | $17,109 | ~$83,200 |
| **Difference** | | | **~$37,600/year more on RDS** |

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
