# Go / No-Go Recommendation
# [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540)

> **Status:** Investigation Complete — Recommendation: NO-GO. Stay on EC2.
> **Last Updated:** 2026-08-06 — Cost case closed. Hermann Lotter confirmed no 3-year RI, not BYOL, passive node licence-free on EC2. RDS ~$37,600/year more expensive at list pricing, ~$16,000/year more with 1-year RI. BYOL confirmed not viable — Kurtosys holds no SQL Server licences with Software Assurance. NO-GO holds under all pricing scenarios.

---

## Recommendation — NO-GO. Stay on EC2.

**Migration from EC2 to RDS is not recommended. The cost case does not support it under any pricing scenario.**

Hermann Lotter confirmed on 2026-07-29 (TECH-3431) that the original cost assumptions were incorrect. RDS costs ~$37,600/year more than the current EC2 setup at list pricing. Even with a 1-year Reserved Instance, the gap is still ~$16,000/year. This is a deliberate trade — paying for managed patching, backups, and HA — not a saving. The EC2 Always On setup already provides HA. The epic as written expected cost-neutral or better. That premise does not hold under any RDS pricing option.

BYOL is also not a viable path. RDS does not offer License Included for Enterprise Edition — BYOL is the only RDS route for Enterprise. Kurtosys holds no SQL Server licences with Software Assurance (confirmed Hermann Lotter 2026-08-06), so BYOL on RDS would require purchasing new Enterprise licences — a significant capital cost on top of the RDS premium.

The technical investigation found 18 of 20 databases are clean and migration-ready, and 2 have hard CLR blockers. But the cost case closes the question before technical readiness matters.

---

## Plain English Summary — For Your Briefing

### What we were trying to find out
We needed to know: can we move our SQL Server databases from the EC2 virtual machine they currently live on, to Amazon RDS — which is AWS's managed database service? And if yes, what would break, what would it cost, and how do we do it safely?

### What we found

**The server is running 20 databases totalling ~803 GB.** These are production databases serving real clients — names like TROWEPRICE, JUPITER, BROWNCAPITAL, SECURITYBENEFIT, RWC and others. The server runs in London (eu-west-2) with a primary node and a secondary node for high availability.

---

### Why most databases are safe to migrate

**18 out of 20 databases have no blockers.** Here is why they are safe:

- **They use SQL logins** — this is important. A SQL login is a username and password stored inside SQL Server itself, like a local account on your laptop. The alternative is a Windows login, which is tied to the company's Active Directory (the same system you use to log into your work computer). RDS does not support Windows logins for applications. The good news is that all 51 application accounts on this server — the ones that applications use to connect to the database — are SQL logins. They will work on RDS exactly as they do today, no changes needed.

- **No cross-database dependencies** — some databases talk to each other by name (e.g. a stored procedure in database A queries a table in database B). RDS does not support this because each RDS instance is isolated. We checked all 20 databases and found none of them do this. They are self-contained.

- **No FILESTREAM** — FILESTREAM is a SQL Server feature that stores files (like PDFs or images) directly inside the database on the server's disk. RDS does not support this. We checked all 20 databases — none of them use it.

- **No application-level linked servers** — a linked server is a connection from one SQL Server to another, allowing queries to span two servers. RDS does not support these. The only linked server on PRD points at MemSQL, which was decommissioned in May 2026. It is dead and will be dropped before migration.

- **Maintenance jobs become redundant** — the server currently runs jobs to do backups, check database integrity (CHECKDB), and rebuild indexes. These jobs use CmdExec and PowerShell steps which RDS does not support. But this is not a problem — RDS does all of this automatically. These jobs are retired, not migrated.

---

### Why 2 databases are blocked

**SECURITYBENEFIT and RWC cannot move to RDS as-is.** Here is why:

These two databases use something called **CLR assemblies** — these are small programs written in C# or .NET that run inside SQL Server to do things T-SQL cannot do natively, like sending emails or doing certain types of encryption. SQL Server has three safety levels for these programs: SAFE, EXTERNAL_ACCESS, and UNSAFE.

RDS only allows SAFE assemblies. SECURITYBENEFIT and RWC both have **UNSAFE assemblies** — 25 each. The key ones are:
- `EmailReportNotifications` — sends emails from inside the database
- `SHA1StringFunction` — does SHA1 hashing (a type of encryption/fingerprinting)

The rest are .NET framework libraries that were loaded as dependencies of those two.

**Why UNSAFE is a hard blocker:** UNSAFE assemblies can access the server's operating system, memory, and network directly. AWS does not allow this on RDS because RDS is a shared managed service — one customer's code cannot be allowed to touch the underlying server. There are no exceptions to this rule.

**The options for these two databases:**
1. Rewrite `SHA1StringFunction` using T-SQL's built-in `HASHBYTES` function — low effort, T-SQL can do SHA1 natively
2. Rewrite `EmailReportNotifications` to use Amazon SES instead — medium effort
3. Leave SECURITYBENEFIT and RWC on EC2 and migrate everything else — valid if rewrite effort is too high right now

---

### Why SSRS needs to move first

**SSRS (SQL Server Reporting Services)** is a reporting tool that runs on the same server as SQL Server. We confirmed it is installed — the ReportServer and ReportServerTempDB databases are present on the instance.

RDS is a database-only service. It does not run SSRS or any other application alongside the database. Before we can migrate the SQL Server instance to RDS, SSRS needs to be moved to its own separate server first. The options are a separate EC2 instance running SSRS, or migrating reports to Power BI or Amazon QuickSight.

---

### Why Database Mail needs replacing

**Database Mail** is how SQL Server sends email alerts — for example, when a backup fails or a job errors. We confirmed it is configured on PRD with a profile called `dba` sending from `dba@kurtosys.com`.

RDS does not support Database Mail. Before migration, this needs to be replaced with **Amazon SES** (Simple Email Service) or **Amazon SNS** (Simple Notification Service) wired up to SQL Agent alerts. This is medium effort but straightforward.

---

### The cost case — confirmed 2026-07-29, updated 2026-08-06

**Source:** Hermann Lotter, TECH-3431 comment, 2026-07-29. 1-year RI figures from AWS Pricing Calculator, confirmed 2026-08-06. All figures measured, not estimated.

> NOTE: The original cost figures in this document were based on incorrect assumptions. All figures below are the corrected, confirmed numbers.

**Measured EC2 cost — March 2026 (744-hour month, after commitment discounts):**

| Item | Monthly |
|---|---|
| ew2p-mssql-01 — compute and SQL licence | $2,753.92 |
| ew2p-mssql-02 — compute only (passive node, no SQL licence) | $512.95 |
| EBS — 5,360 GiB gp3 + provisioned throughput | $532.21 |
| **Total** | **$3,799.08 (~$45,600/year)** |

**Full RDS comparison — all pricing options (db.r6i.2xlarge SQL Server Enterprise LI Multi-AZ, eu-west-2):**

| Option | Compute & Licence | Storage | Annual | Gap vs EC2 |
|---|---|---|---|---|
| EC2 today (after commitments) | $38,413 | $6,387 | ~$45,600 | baseline |
| RDS SQL Ent LI Multi-AZ — list (on-demand) | $66,094 | $17,109 | ~$83,200 | **+$37,600/year** |
| RDS 1-yr RI No Upfront | ~$45,605 | $17,109 | ~$62,700 | **+$17,100/year** |
| RDS 1-yr RI All Upfront | ~$44,283 | $17,109 | ~$61,400 | **+$15,800/year** |

> The 1-year RI cuts the gap roughly in half — from ~$37,600/year down to ~$16,000/year. The NO-GO recommendation holds under all pricing options. Even at best-case RI pricing, RDS is still ~$16,000/year more expensive than the current EC2 setup. Source: AWS Pricing Calculator — https://calculator.aws/#/estimate?id=4de608073e6897f7fc21deae0be40bd84e16537d

**Why the storage gap is so large:** The same 5,360 GiB of storage moves from $532/month on EBS ($0.093/GB-month) to $1,426/month on RDS ($0.266/GB-month for a SQL Server Multi-AZ mirror). Storage alone accounts for ~$10,700/year of the cost gap — independent of the licence model.

**Why BYOL is not a viable alternative:**
RDS does not offer License Included for Enterprise Edition — BYOL is the only RDS path for Enterprise. Kurtosys holds no SQL Server licences with Software Assurance (confirmed Hermann Lotter 2026-08-06). Switching to BYOL on RDS would require purchasing new Enterprise licences with Software Assurance from Microsoft — a significant upfront capital cost on top of the ongoing RDS premium. BYOL is not an option.

**What the original assumptions got wrong:**

| Original Assumption | Reality |
|---|---|
| 3-year RI purchased Apr 2025, expiry Apr 2028 | No 3-year RI. 1-year convertible ended 2025-12-02. Current coverage ends 2026-09-08 |
| Instances are BYOL | Not BYOL — AWS License Included. No Microsoft licence commitment to unwind |
| Passive node carries a SQL Server licence charge | Passive node (ew2p-mssql-02) bills at plain Windows rate ($0.96/hr) — worth ~$26,000/year saving. RDS does not offer this under any configuration |
| Current EC2 cost ~$800–$950/month | Actual: $3,799.08/month — the RI was short-term and has rolled off |

**Commitment timing note:** Compute Savings Plans cover EC2 but not RDS. Current plans end 2026-10-18, 2026-11-06, and 2027-06-14. ew2p-mssql-02 is covered by a Compute Savings Plan at ~$512.95/month. If migration happened before 2027-06-14, up to ~$6,000 in committed EC2 spend would become stranded with no EC2 to apply it to. Any future migration must align with Savings Plan end dates.

**AWS EC2 HA programme — closed:** Kurtosys is on the GA feature — [Amazon EC2 High Availability for SQL Server](https://docs.aws.amazon.com/sql-server-ec2/latest/userguide/sql-high-availability.html) — confirmed by Lunga. Hermann noted programme ownership sits with the team managing the servers day to day.

---

## Phased Migration Plan

> NOTE: This plan is documented for future reference only. It does not represent current intent. The recommendation is NO-GO — stay on EC2. This plan would only become relevant if the reassess-when conditions in the risk register are triggered. See [risk-register.md](./risk-register.md) for the full list of conditions under which this decision should be revisited.

| Phase | What Happens | Why This Order |
|---|---|---|
| 1 — Pre-migration prep | Move SSRS off the instance. Replace Database Mail with SES/SNS. Drop dead linked server UDM_MEM. Replace Windows DBA logins with SQL logins on RDS. | These must be done before any database moves |
| 2 — Migrate 18 clean databases | Native backup/restore from EC2 to RDS. Set collation to Latin1_General_CI_AS at provisioning. Estimated cutover window: 10–15 hours across ~803 GB. | Lowest risk — no blockers on these databases |
| 3 — Decide on SECURITYBENEFIT and RWC | Either rewrite CLR assemblies and migrate, or leave on EC2 permanently | Depends on rewrite effort and business priority |
| 4 — Decommission EC2 | Once all databases are migrated or accounted for, decommission the EC2 instances | Cannot happen until Phase 3 is resolved |

---

## What Needs Sign-Off at the Manager Meeting

| Question | Status |
|---|---|
| Confirm RI term and expiry for ew2p-mssql-01 | Closed — no 3-year RI. Hermann confirmed 2026-07-29 |
| Confirm RI status for ew2p-mssql-02 | Closed — Compute Savings Plan, not RI. Hermann confirmed 2026-07-29 |
| Confirm BYOL license commitment | Closed — not BYOL, AWS License Included. No SQL Server licences with Software Assurance. Hermann confirmed 2026-07-29 and 2026-08-06 |
| Confirm 1-year RI cost gap | Closed — RDS 1-yr RI still ~$16,000/year more than EC2. Does not change NO-GO. Confirmed from AWS Pricing Calculator 2026-08-06 |
| Manager sign-off on NO-GO recommendation | Open — pending Jacobus sign-off |
| AWS EC2 HA programme — 2022 vs GA feature | Closed — GA confirmed by Lunga |

---

## Definition of Done

- [x] Go/no-go recommendation written with evidence from TECH-3538 and TECH-3539
- [x] Cost case closed — Hermann confirmed figures 2026-07-29
- [x] Recommendation updated to NO-GO — stay on EC2
- [x] All cost assumptions corrected
- [x] 1-year RI comparison added — gap narrows to ~$16,000/year, NO-GO holds
- [x] BYOL not viable confirmed — Kurtosys holds no SQL Server licences with Software Assurance (Hermann 2026-08-06)
- [x] Phased migration plan marked as dormant — future reference only
- [x] Stranded Savings Plan commitment quantified — up to ~$6,000 depending on migration timing
- [ ] Manager sign-off obtained — pending Jacobus
- [ ] Epic TECH-3431 closure comment written

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — inventory and dependency |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — compatibility and cost |
| [risk-register.md](./risk-register.md) | Risk register — full risk breakdown and reassess-when conditions |
| [migration-approaches.md](./migration-approaches.md) | Migration execution detail — backup/restore window estimates |
| [AWS Pricing Calculator estimate](https://calculator.aws/#/estimate?id=4de608073e6897f7fc21deae0be40bd84e16537d) | Verified RDS cost estimate — db.r6i.2xlarge SQL Ent LI Multi-AZ eu-west-2 |
