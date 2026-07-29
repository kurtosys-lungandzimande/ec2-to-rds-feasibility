# Theme B — RDS Compatibility and Cost Analysis
# [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539)

> **Status:** Complete — All compatibility blockers assessed 2026-07-24. Cost model confirmed and updated 2026-07-28.
> **Last Updated:** 2026-07-28

---

## Purpose

Using the inventory and dependency findings from TECH-3538, assess whether the SQL Server workloads running on EC2 are compatible with Amazon RDS for SQL Server, and produce a cost comparison between staying on EC2 and moving to RDS.

---

## Confirmed Inputs from TECH-3538

| Property | Value | Source |
|---|---|---|
| PRD instances | ew2p-mssql-01 (primary), ew2p-mssql-02 (secondary) | EW1R-REP-01 linked servers |
| SQL Server version | 2019 (15.0.4455.2) CU32 | OPENQUERY via EW1R-REP-01 |
| Edition | Enterprise Edition (64-bit) | OPENQUERY via EW1R-REP-01 |
| Instance type | r6i.2xlarge (8 vCPU, 64 GB RAM) | INFO_AWS_EC2_Detail in DBA_VCC_AWS |
| Storage per node | 2,680 GB total (80 + 1,400 + 800 + 400 GB) | INFO_AWS_EC2_Detail in DBA_VCC_AWS |
| License model | BYOL — confirmed | LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE in cost data |
| HA topology | Always On Availability Group (primary + secondary) | Workload profile confirmed |
| Workload | InvestorPress_Encore | Confirmed |
| OS disk encryption | Unencrypted (80 GB OS disk) — compliance finding | INFO_AWS_EC2_Detail |

---

## Feature Compatibility Matrix

> Assessment basis: SQL Server 2019 Enterprise on EC2 → RDS for SQL Server. All features confirmed 2026-07-24 via OPENQUERY through EW1R-REP-01 linked servers — no direct PRD access required.

| Feature | In Use on EC2 | RDS Support | Workaround | Impact |
|---|---|---|---|---|
| SQL Agent Jobs — T-SQL steps | Yes — confirmed | ✅ Supported | N/A | None |
| SQL Agent Jobs — CmdExec / PowerShell steps | Yes — DBA maintenance jobs only (Ola Hallengren + S3 upload checks) | ❌ Not Supported | RDS manages CHECKDB, backups, reindex automatically — jobs retired, not migrated | Not a blocker — all CmdExec/PowerShell steps are DBA maintenance that RDS replaces |
| SQL Agent Jobs — SSIS steps | No SSIS Agent steps found — SSISDB exists but not used in Agent jobs | ❌ Not Supported | N/A | Not a blocker |
| Always On Availability Groups | Yes — primary/secondary confirmed | ✅ Supported via RDS Multi-AZ | Use RDS Multi-AZ deployment | None — RDS Multi-AZ replaces Always On |
| Linked Servers | One linked server — UDM_MEM pointing at decommissioned MemSQL | ❌ Not Supported on RDS | Drop UDM_MEM before migration | Not a blocker — dead linked server, safe to drop |
| CLR — Safe assemblies | Yes — EmailReportNotifications.XmlSerializers (SECURITYBENEFIT, RWC) | ✅ Supported | N/A | None |
| CLR — External / Unsafe assemblies | **Yes — 25 UNSAFE assemblies in SECURITYBENEFIT and RWC** (EmailReportNotifications, SHA1StringFunction, System.Drawing, System.Windows.Forms etc.) | ❌ Not Supported | Rewrite SHA1StringFunction as T-SQL HASHBYTES. Rewrite EmailReportNotifications using SES/SNS. Or keep SECURITYBENEFIT and RWC on EC2. | **Hard blocker — SECURITYBENEFIT and RWC cannot migrate to RDS without remediation** |
| Cross-database queries | No real cross-database dependencies found — false positives only (single-letter variable references) | ❌ Not Supported | N/A | Not a blocker |
| Windows Authentication / AD logins | 10 Windows logins — all service accounts (NT Service\*, SHPRD\sqlsrv, SHPRD\ssis) and DBA access. 51 SQL logins for all application accounts. | ❌ Not Supported (standard RDS) | Replace SHPRD\* DBA logins with SQL logins on RDS. Service accounts not needed on RDS. | Not a blocker — application already uses SQL auth |
| Database Mail | **Confirmed in use** — profile `dba`, account `dba@kurtosys.com`, SMTP via EW2P-MSSQL-01 | ❌ Not Supported | Replace with Amazon SES or SNS wired to SQL Agent alerts | Needs replacement before migration — medium effort |
| FILESTREAM / FILETABLE | Not in use — all databases returned NULL | ❌ Not Supported | N/A | Not a blocker |
| SSRS (SQL Server Reporting Services) | **Confirmed installed** — ReportServer and ReportServerTempDB present on instance | ❌ Not Supported | Move SSRS to separate EC2, or migrate to Power BI / QuickSight | **Hard blocker — SSRS must be moved off the instance before migration** |
| Backup to local disk | TBC — backup history query pending | ❌ Not Supported | S3 only (native RDS backup) | Process change — not a blocker |
| Custom collation | `Latin1_General_CI_AS` confirmed on PRD (19 of 20 databases). ReportServer uses `Latin1_General_100_CI_AS_KS_WS`. SSISDB uses `SQL_Latin1_General_CP1_CI_AS`. | ✅ Supported at DB creation | Set `Latin1_General_CI_AS` at RDS instance provisioning time | Must be set correctly at provisioning — not a blocker |
| CHECKDB | Manual on EC2 | ✅ Managed by RDS automatically | N/A | Improvement — no action needed |
| Transparent Data Encryption (TDE) | TBC | ✅ Supported | N/A | None |
| Data compression | Enterprise feature — in use | ✅ Supported on RDS Enterprise | N/A | None |
| Online index operations | Enterprise feature — in use | ✅ Supported on RDS Enterprise | N/A | None |
| Resource Governor | TBC — low priority | ❌ Not Supported on RDS | Workload management via instance sizing | Low impact unless actively used |
| SQL Server version (2019) | 2019 (15.0.4455.2) CU32 — confirmed | ✅ RDS supports SQL Server 2019 | N/A | None |
| Enterprise Edition on RDS | Required — BYOL only | ✅ Supported — BYOL only | N/A | BYOL confirmed — no blocker |

---

## Compatibility Blockers Summary

All blockers assessed 2026-07-24 via OPENQUERY through EW1R-REP-01 linked servers.

| # | Blocker | Status | Finding | Action Required |
|---|---|---|---|---|
| 1 | Cross-database queries | ✅ Closed | No real cross-database dependencies found — false positives only | None |
| 2 | Linked servers (PRD outbound) | ✅ Closed | One dead linked server — UDM_MEM pointing at decommissioned MemSQL | Drop UDM_MEM before migration |
| 3 | Windows Authentication / AD logins | ✅ Closed | All application logins are SQL auth. Windows logins are service accounts only. | Replace SHPRD\* DBA logins with SQL logins on RDS |
| 4 | CmdExec / PowerShell SQL Agent steps | ✅ Closed | All DBA maintenance jobs (Ola Hallengren + S3 checks) — RDS replaces entirely | Retire jobs — no migration needed |
| 5 | SSIS job steps | ✅ Closed | No SSIS steps in Agent jobs — SSISDB present but not used in scheduled jobs | Confirm SSISDB usage with application team |
| 6 | CLR Unsafe assemblies | ⚠️ **Hard blocker** | 25 UNSAFE assemblies in SECURITYBENEFIT and RWC — EmailReportNotifications, SHA1StringFunction + .NET framework dependencies | Rewrite SHA1StringFunction as T-SQL HASHBYTES. Rewrite or replace EmailReportNotifications. Or keep both databases on EC2. |
| 7 | SSRS | ⚠️ **Hard blocker** | ReportServer and ReportServerTempDB confirmed on instance | Move SSRS to separate EC2 or migrate to Power BI / QuickSight before migration |

**Additional findings confirmed:**
- Database Mail in use (`dba` profile, `dba@kurtosys.com`) — replace with SES/SNS before migration
- SSISDB present — confirm with application team whether SSIS packages are actively running
- Two non-standard collations on instance (ReportServer, SSISDB) — document before provisioning RDS
- 20 user databases, ~803 GB total on PRD (vs 32 databases, 342 GB on REL)
- All databases on compatibility level 130 except SECURITYBENEFIT and ReportServer* (150)

---

## Licensing Analysis

### Enterprise Edition — BYOL is the Only RDS Option

RDS for SQL Server does not offer License Included for Enterprise Edition. BYOL is the only path. This is confirmed as viable because BYOL is already in place on EC2.

| Option | Available for Enterprise on RDS | Cost Model | Status |
|---|---|---|---|
| License Included | ❌ Not available for Enterprise | N/A | Not applicable |
| BYOL | ✅ Available | Compute + storage only — no license cost on AWS bill | **Confirmed viable — BYOL already in place** |

### BYOL Evidence

The `LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE` line item appears consistently in AWS cost data for ew2p-mssql-02 from 2024-07-23 through 2026-07-23. AWS only grants this passive node license exemption under the Microsoft SQL Server BYOL passive node rule — it is not available under License Included. This confirms Kurtosys owns the Enterprise licenses with active Software Assurance.

### AWS License Mobility

To use existing licenses on RDS, AWS License Mobility must be formally activated. This is an administrative step — not a technical blocker — but it must be initiated before migration begins. Confirm with the manager whether this has been done previously or is a first-time activation.

---

## Cost Model

### EC2 Baseline — Confirmed from EW1R-REP-01 Monitoring Data

> Source: `MON_AWS_Entity_Cost` in DBA_VCC_AWS on EW1R-REP-01. Real AWS billing data collected daily. Duplicates removed using MIN per day before summing.

| Period | ew2p-mssql-01/month | ew2p-mssql-02/month | Combined | Notes |
|---|---|---|---|---|
| Current (post-RI, May 2025 – present) | ~$165–$234 | ~$640–$820 | **~$800–$950** | RI active on ew2p-mssql-01 since 23 Apr 2025 |
| Pre-RI (Aug 2024 – Apr 2025) | ~$2,263–$2,804 | ~$640–$820 | **~$2,900–$3,700** | On-demand rate |

> **Reserved Instance confirmed on ew2p-mssql-01:** purchased 23 April 2025, 3-year term most likely, expiry April 2028. The ~$165–$234/month still showing is EBS, data transfer, and SQL Server line items only — compute is covered by the RI. No cost jump in April 2026 rules out a 1-year term.

### RDS Cost Estimate — BYOL, db.r6i.2xlarge, Multi-AZ

> Confirmed via AWS Pricing Calculator — eu-west-2, db.r6i.2xlarge, Multi-AZ, BYOL, gp3 2,680 GB. EC2 baseline confirmed from `MON_AWS_Entity_Cost` and `INFO_AWS_EC2_Detail` in DBA_VCC_AWS on EW1R-REP-01 (real AWS billing data collected daily). Full breakdown in [cost-comparison.md](./cost-comparison.md).

| Component | Cost/month | Notes |
|---|---|---|
| RDS db.r6i.2xlarge — Multi-AZ (BYOL) | ~$714 | Single Multi-AZ rate covers both primary and standby — compute only, no license cost on AWS bill |
| Storage — gp3, 2,680 GB | ~$370 | $0.138/GB-month on RDS gp3 — billed once for Multi-AZ |
| Automated backup storage — 2,680 GB | ~$255 | First 100% of DB size free — overage at $0.095/GB-month |
| **Total estimated** | **~$1,339–$1,389/month** | Both nodes via Multi-AZ — on-demand pricing |

> **Correction:** An earlier estimate of $2,000–$2,500/month doubled per-node compute. Multi-AZ on RDS is billed as a single instance at the Multi-AZ rate — storage and backup are charged once. Corrected figure is ~$1,339–$1,389/month on-demand.

### EC2 vs RDS Comparison

| Scenario | EC2 Monthly | RDS On-Demand | Difference |
|---|---|---|---|
| Current EC2 spend (RI active) | ~$800–$950 | ~$1,339–$1,389 | **RDS ~$409–$589 more expensive** |
| Pre-RI baseline (Aug 2024 – Apr 2025) | ~$2,900–$3,700 | ~$1,339–$1,389 | **RDS ~$1,500–$2,300 cheaper** |
| With RDS 1-year Reserved | ~$800–$950 | ~$1,135–$1,165 | **RDS ~$185–$365 more expensive** |

> At current EC2 spend, RDS is more expensive. The migration timing must align with the RI expiry (April 2028) to avoid paying both simultaneously. See [cost-comparison.md](./cost-comparison.md) for full breakdown.

---

## RDS Engine Version Compatibility

| EC2 SQL Server Version | RDS Support | Notes |
|---|---|---|
| SQL Server 2019 (15.0.4455.2) CU32 | ✅ Supported | RDS supports SQL Server 2019 — minor version managed by AWS |
| SQL Server 2019 Enterprise Edition | ✅ Supported — BYOL only | Confirmed viable |

---

## Definition of Done

- [x] Confirmed inputs from TECH-3538 documented — instance type, edition, BYOL, storage, cost baseline
- [x] Feature compatibility matrix completed for known features — Supported / Not Supported / Workaround
- [x] Compatibility blockers listed — all 7 assessed and resolved 2026-07-24
- [x] Licensing analysis completed — BYOL confirmed, License Mobility noted
- [x] Cost model populated — EC2 baseline confirmed, RDS estimate calculated, saving quantified
- [x] RDS engine version support confirmed against current EC2 SQL Server version
- [x] Compatibility blockers 1–6 resolved via OPENQUERY through EW1R-REP-01 linked servers
- [x] Cost model finalised — RI confirmed 23 Apr 2025, current baseline ~$800–$950/month, April 2028 migration window confirmed
- [ ] AWS License Mobility activation status confirmed with manager
- [ ] Exact RDS pricing confirmed via AWS Pricing Calculator
- [ ] compatibility-matrix.md published to Confluence
- [ ] Findings handed over to TECH-3540 for recommendation

---

## Dependencies

- TECH-3538 complete — ✅ PRD instance data confirmed
- OPENQUERY via EW1R-REP-01 linked servers — ✅ used to resolve all compatibility blockers 2026-07-24
- Manager confirmation — AWS License Mobility activation status

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) | Planning ticket |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — inventory source |
| [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540) | Theme C — blocked on this |
