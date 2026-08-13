# Risk Register
# [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540)

> **Status:** Complete — updated 2026-07-29 to reflect NO-GO recommendation and Hermann Lotter's confirmed figures. Risk register expanded 2026-08-06 to add cost justification detail, stranded commitment quantification, dormant migration blockers, and three new open EC2 risks.
> **Last Updated:** 2026-08-06

---

## Outcome Context

The recommendation is NO-GO — stay on EC2. The risks below are documented in two groups:

- **Risks that influenced the NO-GO decision** — findings that made migration unviable or high-cost
- **Risks that remain on EC2** — staying on EC2 is not risk-free, these need to be owned and monitored

---

## Risks That Influenced the NO-GO Decision

| Risk | Likelihood | Impact | Finding | Why It Is a Risk to Move | Status |
|---|---|---|---|---|---|
| RDS costs significantly more than EC2 | Confirmed | High | RDS ~$37,600/year more expensive at list pricing. With a 1-year RI the gap narrows to ~$16,000–$17,000/year — but does not close. EC2 measured at $3,799.08/month (March 2026, after commitment discounts). RDS db.r6i.2xlarge SQL Ent LI Multi-AZ eu-west-2 at ~$6,933/month list. Source: Hermann Lotter, TECH-3431, 2026-07-29. | Moving to RDS pays $37,600/year more for managed patching, backups, and HA — services the current EC2 Always On setup already provides. There is no net operational gain that justifies the cost increase. The managed service premium is real but the workload does not need it. | **Closed — drove NO-GO** |
| License model incompatible with RDS Enterprise | Confirmed | High | Both PRD nodes are AWS License Included — not BYOL. RDS does not offer License Included for Enterprise Edition. The only RDS path for Enterprise is BYOL. Kurtosys holds no SQL Server licences with Software Assurance (confirmed Hermann Lotter 2026-08-06). | Moving to RDS Enterprise would require purchasing new SQL Server Enterprise licences with Software Assurance from Microsoft — a significant upfront capital cost on top of the $37,600/year RDS premium. Standard Edition on RDS is not viable — the workload requires Enterprise features (data compression, online index operations, Always On). | **Closed — drove NO-GO** |
| Passive node licence exemption lost on migration | Confirmed | High | ew2p-mssql-02 bills at the plain Windows rate ($0.96/hr) on EC2 — no SQL Server licence charge. Worth ~$26,000/year. This exemption applies because the secondary node is passive under the AWS License Included model. It does not exist on RDS under any configuration. Source: Hermann Lotter, TECH-3431, 2026-07-29. | On RDS Multi-AZ, both the primary and standby nodes are billed at the full SQL Server Enterprise licence rate. There is no passive node concept on RDS. Moving to RDS immediately adds ~$26,000/year in licence cost that does not exist today — this single item accounts for the majority of the cost gap. | **Closed — drove NO-GO** |
| Compute Savings Plans cover EC2 but not RDS — stranded commitment risk | Confirmed | Medium | Current Compute Savings Plans end 2026-10-18, 2026-11-06, 2027-06-14. ew2p-mssql-02 is covered by a Compute Savings Plan at ~$512.95/month. EC2 spend removed by migration becomes unused committed spend. Database Savings Plans would be needed as an RDS-side offset — adding further transition cost. Source: Hermann Lotter, TECH-3431, 2026-07-29. | If migration happened before 2027-06-14, Kurtosys would continue paying for Compute Savings Plans with no EC2 to apply them to — up to ~$6,000 in stranded commitment depending on timing. Any future migration must align with Savings Plan end dates to avoid wasting committed spend. | **Closed — noted in recommendation** |
| UNSAFE CLR assemblies block migration of SECURITYBENEFIT and RWC | Confirmed | High | 25 UNSAFE assemblies confirmed in each of SECURITYBENEFIT and RWC — EmailReportNotifications, SHA1StringFunction, System.Drawing, System.Windows.Forms, and .NET framework dependencies. RDS does not allow UNSAFE assemblies under any configuration. Hard blocker for 2 of 20 databases. Confirmed 2026-07-24 via OPENQUERY through EW1R-REP-01. | UNSAFE assemblies can access the server OS, memory, and network directly. AWS does not permit this on RDS because it is a shared managed service. There are no exceptions. Moving these two databases to RDS without remediating the assemblies is not possible. Remediation options: rewrite SHA1StringFunction as T-SQL HASHBYTES (low effort), rewrite EmailReportNotifications using SES/SNS (medium effort), or leave both databases on EC2 permanently. | **Dormant — would become active blocker if migration is reconsidered** |
| SSRS installed on same instance as SQL Server | Confirmed | High | ReportServer and ReportServerTempDB confirmed on the PRD instance. RDS is a database-only service — it does not host SSRS or any application alongside the database engine. Confirmed 2026-07-24 via OPENQUERY through EW1R-REP-01. | SSRS must be moved to a separate EC2 instance, or reports migrated to Power BI / Amazon QuickSight, before any SQL Server migration to RDS can begin. This is a Phase 1 prerequisite — no databases can move until SSRS is off the instance. It is a sequencing blocker, not just a technical one. | **Dormant — would become active blocker if migration is reconsidered** |
| Migration execution risk — cutover window and rollback | Confirmed | High | PRD holds ~803 GB across 20 databases. Native backup/restore is the recommended migration approach. Estimated total backup/restore time is 10–15 hours. Largest databases: KSDK_157_DocProd (296 GB, 2–4 hrs), TROWEPRICE (122 GB, 1–2 hrs), JUPITER (106 GB, 1–2 hrs). Source: migration-approaches.md. | Once cutover begins and application connection strings are switched to RDS, rollback requires restoring the full backup set back to EC2 — adding another 10–15 hours of downtime. There is no instant rollback. A failed or overrunning migration window directly impacts production client-facing workloads. This risk must be planned for in any future migration attempt. | **Dormant — would become active risk if migration is reconsidered** |

---

## Risks That Remain on EC2 — Must Be Owned

| Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|
| AWS EC2 HA programme — 2022 vs GA feature | **Closed** | Low | GA confirmed by Lunga. Kurtosys is on the public GA feature — [Amazon EC2 High Availability for SQL Server](https://docs.aws.amazon.com/sql-server-ec2/latest/userguide/sql-high-availability.html). Hermann noted programme ownership sits with the team managing the servers day to day. No dependency on a private programme. | Lunga |
| Second RI — waived | **Closed** | N/A | Hermann noted two RIs for Windows SQL Ent but only mssql-01 bills under that code. Second RI is waived — confirmed by Lunga. Not wasted spend. | Lunga |
| Compute Savings Plans roll off mid-2027 — EC2 cost may jump | Medium | Medium | Plans end 2026-10-18, 2026-11-06, 2027-06-14. If not renewed, EC2 on-demand cost could return to ~$3,700/month. Monitor via ProsperOps — coverage is continuous by design as RIs roll off. Reassess RDS cost case at this point if the gap narrows. | Hermann / Platform Engineering |
| OS disk on both PRD nodes is unencrypted | Confirmed | Medium | 80 GB OS disk on ew2p-mssql-01 and ew2p-mssql-02 confirmed unencrypted. Three data disks (1,400 GB, 800 GB, 400 GB) are encrypted. Compliance finding — OS disk encryption should be remediated independently of migration decision. Remediation requires a stop/snapshot/re-encrypt cycle per node — plan for a maintenance window. | Platform Engineering |
| SSISDB present but usage not confirmed | Low | Medium | SSISDB exists on the instance but no SSIS steps found in SQL Agent jobs. Risk is that SSIS packages are running outside of Agent jobs — triggered by an external scheduler or application — and are not visible in the job inventory. Confirm with the application team whether SSIS packages are actively in use. If yes, document the packages and their schedules. | Application team |
| Database Mail in use with no redundancy | Low | Medium | Profile `dba`, account `dba@kurtosys.com` confirmed active via SMTP relay on EW2P-MSSQL-01. If the SMTP relay fails, SQL Agent alerts go silent — failed backups, job errors, and disk alerts will not be delivered. No secondary profile or fallback configured. Consider replacing with Amazon SES or SNS wired to SQL Agent alerts regardless of migration decision. | Platform Engineering |
| Key-person risk on EC2 configuration | Medium | High | Bespoke EC2 HA and ProsperOps configuration knowledge is concentrated in Hermann Lotter. If Hermann is unavailable during an incident, the team may not be able to diagnose or recover the HA setup or commitment position. Document the EC2 HA topology, ProsperOps configuration, and RI/Savings Plan schedule before this becomes a blocker. | Hermann / Platform Engineering |
| Cost Explorer access not available to DBA team | Confirmed | Low | Access denied to InvestorPress_Encore_Prod billing account. DBA team cannot independently verify cost figures or monitor spend trends. All cost data in this investigation was sourced from Hermann. Request read-only Cost Explorer access from Hermann or Jacobus for future cost work and ongoing monitoring. | Lunga / Jacobus |
| Resource Governor usage not confirmed | Low | Low | Resource Governor is not supported on RDS. Its usage on PRD was not confirmed during this investigation — cost case closed before the check was run. If Resource Governor is enabled and actively managing workload groups, that configuration would be lost on any future migration. Check sys.resource_governor_configuration on PRD — if not enabled, close this risk. | Platform Engineering |
| PRD backup destination not confirmed | Low | High | The backup history query (Section 10 of prd-compatibility-queries.sql) was not run against PRD — the cost case closed the investigation before full PRD assessment was completed. It is not confirmed whether PRD backups are landing in S3 or on local disk. If backups are going to local disk only, recovery from a node failure may be slower than expected and backups may not be accessible from outside the instance. Confirm backup destinations and ensure S3 copies exist. | Platform Engineering |
| TDE status on PRD not confirmed | Low | Medium | Transparent Data Encryption (TDE) status was not confirmed on PRD during this investigation. If TDE is enabled on any PRD databases, the TDE certificates and database master keys must be backed up and documented. Loss of a TDE certificate makes the database unrecoverable. Confirm TDE status and ensure certificates are backed up to a secure location outside the instance. | Platform Engineering |

---

## Reassess When

The NO-GO recommendation should be revisited if any of the following conditions change:

| Condition | Why It Matters |
|---|---|
| Passive node exemption removed by AWS | Removes ~$26,000/year EC2 advantage — cost gap narrows significantly. At that point RDS list pricing gap drops from ~$37,600/year to ~$11,600/year. |
| Compute Savings Plans roll off and are not renewed | EC2 on-demand cost returns to ~$3,700/month (~$44,400/year). RDS with a 1-year RI at ~$61,400/year is still more expensive, but the gap narrows to ~$17,000/year. Reassess at this point. |
| AWS launches RDS passive node exemption equivalent | Would close the licence cost gap directly — the single largest driver of the NO-GO decision. |
| Operational overhead becomes critical | If EC2 management cost (people time, incidents, patching) exceeds $37,600/year, the managed service premium becomes justifiable. |
| UNSAFE CLR assemblies in SECURITYBENEFIT and RWC are remediated | Removes the hard technical blocker for 2 of 20 databases. Does not change the cost case but removes a migration prerequisite. |
| SSRS is relocated off the PRD instance for other reasons | If SSRS moves to a separate EC2 or Power BI for unrelated reasons, the Phase 1 migration prerequisite is already met — reduces future migration effort. |

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — inventory source |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — compatibility and cost source |
| [go-no-go-recommendation.md](./go-no-go-recommendation.md) | Full recommendation |
| [migration-approaches.md](./migration-approaches.md) | Migration execution detail — backup/restore window estimates |
