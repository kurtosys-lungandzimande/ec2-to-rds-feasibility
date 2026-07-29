# Go / No-Go Recommendation
# [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540)

> **Status:** In Progress — all findings confirmed 2026-07-24 from live PRD queries via EW1R-REP-01
> **Last Updated:** 2026-07-24

---

## Recommendation — GO with Conditions

**Migration from EC2 to RDS is viable. The recommendation is GO.**

Not everything can move at once — 18 out of 20 databases are clean and ready. 2 databases have a hard blocker that needs a decision before they can move. Everything else is solvable with preparation work.

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

### The cost case

The current EC2 spend is approximately **$800–$950/month** combined for both nodes — confirmed from real AWS billing data on EW1R-REP-01. This is the post-RI figure. Before the Reserved Instance was purchased on 23 April 2025, the combined spend was ~$2,900–$3,700/month.

On RDS with BYOL (we own the licenses — confirmed), the equivalent Multi-AZ configuration would cost approximately **$1,359–$1,389/month** on-demand — around **$409–$589/month more expensive** than current EC2 spend. With a 1-year RDS Reserved Instance, the RDS cost drops to ~$1,135–$1,165/month, which is still ~$185–$365/month more than current EC2 spend.

**The migration timing is constrained by the RI.** A Reserved Instance is almost certainly in place on ew2p-mssql-01 — purchased 23 April 2025, most likely a 3-year term expiring April 2028. Migrating before that date means paying for both the unused RI and RDS compute simultaneously. The financially optimal migration window is **at or after April 2028**. Technical preparation work (resolving CLR blockers, moving SSRS, replacing Database Mail) should happen before that date so the cutover can happen cleanly when the RI expires.

**If the business wants to migrate before April 2028 — the trade-off:**

The RI is a pre-paid commitment. That money is gone regardless of whether the EC2 instance keeps running or not — Reserved Instances are non-refundable and non-cancellable. Migrating early means Kurtosys pays for both simultaneously until April 2028.

The only ways to recover value from the RI early are:

| Option | Trade-off |
|---|---|
| Wait until April 2028 | Cleanest — no double-paying, no extra complexity. Technical prep happens now, cutover happens at expiry |
| Repurpose the EC2 for another workload | RI gets used — but now managing EC2 AND RDS simultaneously. OS patching burden stays. Operational complexity increases. Need a genuine workload that justifies r6i.2xlarge (8 vCPU, 64 GB RAM, SQL Server Enterprise). If no real workload exists, this is just running a large idle box to avoid a sunk cost |
| Sell the RI on AWS Marketplace | Partial recovery possible — but SQL Server RIs are harder to sell than Linux, and recovery will be less than the remaining term value |

> **Recommendation:** Do not repurpose the EC2 unless there is a genuine workload already waiting for it. Creating operational overhead to justify a sunk cost is a false saving. The right answer is to start technical preparation now and target April 2028 for cutover.

**Why we own the licenses (BYOL):** BYOL stands for Bring Your Own License. It means Kurtosys purchased SQL Server Enterprise licenses directly from Microsoft. When you run on EC2 or RDS with BYOL, you only pay AWS for the compute and storage — the license cost does not appear on the AWS bill because you already paid Microsoft for it. We confirmed this from the AWS cost data — a line item called `LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE` appears on the secondary node. AWS only applies this exemption when a customer is running BYOL with active Software Assurance. This is the proof.

---

## Phased Migration Plan

| Phase | What Happens | Why This Order |
|---|---|---|
| 1 — Pre-migration prep | Move SSRS off the instance. Replace Database Mail with SES/SNS. Drop dead linked server UDM_MEM. Replace Windows DBA logins with SQL logins on RDS. | These must be done before any database moves |
| 2 — Migrate 18 clean databases | Native backup/restore from EC2 to RDS. Set collation to Latin1_General_CI_AS at provisioning. | Lowest risk — no blockers on these databases |
| 3 — Decide on SECURITYBENEFIT and RWC | Either rewrite CLR assemblies and migrate, or leave on EC2 permanently | Depends on rewrite effort and business priority |
| 4 — Decommission EC2 | Once all databases are migrated or accounted for, decommission the EC2 instances | Cannot happen until Phase 3 is resolved |

---

## What Needs Sign-Off at the Manager Meeting

| Question | Why It Matters |
|---|---|
| Has AWS License Mobility been formally activated for RDS? | Administrative step — not a blocker, but must be initiated before migration begins |
| Confirm RI term and expiry for ew2p-mssql-01 — believed to be 3-year purchased 23 Apr 2025, expiring Apr 2028 | Determines the earliest cost-neutral migration window |
| Confirm whether ew2p-mssql-02 is also on a Reserved Instance | Could affect combined cost baseline and migration timing |
| Who owns SECURITYBENEFIT and RWC — rewrite CLR or leave on EC2? | Determines whether Phase 3 is a rewrite project or a permanent split |
| Who owns SSRS — move to EC2 or migrate to Power BI? | Determines Phase 1 effort and timeline |

---

## Definition of Done

- [x] Go/no-go recommendation written with evidence from TECH-3538 and TECH-3539
- [x] Phased migration plan documented
- [x] Plain English summary written for briefing
- [ ] Migration approaches documented with downtime estimates — see migration-approaches.md
- [ ] Risk register completed — see risk-register.md
- [ ] Manager sign-off obtained
- [ ] Epic TECH-3431 closure comment written

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — inventory and dependency |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — compatibility and cost |
