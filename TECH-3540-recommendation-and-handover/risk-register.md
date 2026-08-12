# Risk Register
# [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540)

> **Status:** Complete — updated 2026-07-29 to reflect NO-GO recommendation and Hermann Lotter's confirmed figures.
> **Last Updated:** 2026-07-29

---

## Outcome Context

The recommendation is NO-GO — stay on EC2. The risks below are documented in two groups:

- **Risks that influenced the NO-GO decision** — findings that made migration unviable or high-cost
- **Risks that remain on EC2** — staying on EC2 is not risk-free, these need to be owned and monitored

---

## Risks That Influenced the NO-GO Decision

| Risk | Likelihood | Impact | Finding | Status |
|---|---|---|---|---|
| RDS costs significantly more than EC2 | Confirmed | High | RDS ~$37,600/year more expensive than current EC2 setup. Passive node exemption (~$26,000/year) does not exist on RDS. Storage moves from $532/month on EBS to $1,426/month on RDS. | **Closed — drove NO-GO** |
| License model incompatible with RDS Enterprise | Confirmed | High | AWS License Included — not BYOL. RDS does not offer License Included for Enterprise Edition. BYOL would require purchasing new Enterprise licences with Software Assurance — not cost-effective. | **Closed — drove NO-GO** |
| Passive node licence exemption lost on migration | Confirmed | High | ew2p-mssql-02 bills at plain Windows rate ($0.96/hr) on EC2 — no SQL Server licence charge. Worth ~$26,000/year. This exemption does not exist on RDS under any configuration. | **Closed — drove NO-GO** |
| Compute Savings Plans cover EC2 but not RDS | Confirmed | Medium | Current Savings Plans end 2026-10-18, 2026-11-06, 2027-06-14. EC2 spend removed by migration becomes unused commitment. Database Savings Plans would be needed as offset — adds transition cost. | **Closed — noted in recommendation** |
| UNSAFE CLR assemblies block migration of SECURITYBENEFIT and RWC | Confirmed | High | 25 UNSAFE assemblies in each database — EmailReportNotifications, SHA1StringFunction, .NET framework dependencies. RDS does not allow UNSAFE assemblies. Hard blocker for 2 of 20 databases. | **Closed — moot given NO-GO** |
| SSRS installed on same instance as SQL Server | Confirmed | High | ReportServer and ReportServerTempDB confirmed on instance. RDS does not support SSRS. Would require relocation before any migration. | **Closed — moot given NO-GO** |

---

## Risks That Remain on EC2 — Must Be Owned

| Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|
| AWS EC2 HA programme — 2022 vs GA feature | **Closed** | Low | **GA confirmed by Lunga.** Kurtosys is on the public GA feature — [Amazon EC2 High Availability for SQL Server](https://docs.aws.amazon.com/sql-server-ec2/latest/userguide/sql-high-availability.html). Hermann noted programme ownership sits with the team managing the servers day to day. No dependency on a private programme. | Lunga |
| Second RI — waived | **Closed** | N/A | Hermann noted two RIs for Windows SQL Ent but only mssql-01 bills under that code. Second RI is waived — confirmed by Lunga. Not wasted spend. | Lunga |
| Compute Savings Plans roll off mid-2027 — EC2 cost may jump | Medium | Medium | Plans end 2026-10-18, 2026-11-06, 2027-06-14. If not renewed, EC2 on-demand cost could return to ~$3,700/month. Monitor via ProsperOps. Reassess RDS at this point if cost gap narrows. | Hermann / Platform Engineering |
| OS disk on both PRD nodes is unencrypted | Confirmed | Medium | 80 GB OS disk on ew2p-mssql-01 and ew2p-mssql-02 confirmed unencrypted. Three data disks are encrypted. Compliance finding — should be remediated independently of migration decision. | Platform Engineering |
| SSISDB present but usage not confirmed | Low | Medium | SSISDB exists on the instance but no SSIS steps found in SQL Agent jobs. Confirm with application team whether SSIS packages are actively running outside of Agent jobs. | Application team |
| Database Mail in use with no redundancy | Low | Medium | Profile `dba`, account `dba@kurtosys.com` confirmed active. If SMTP relay fails, SQL Agent alerts go silent. Consider replacing with SES/SNS regardless of migration decision. | Platform Engineering |
| Key-person risk on EC2 configuration | Medium | High | Bespoke EC2 HA and ProsperOps configuration knowledge concentrated in Hermann. Document the HA setup and ProsperOps configuration before it becomes a blocker. | Hermann / Platform Engineering |
| Cost Explorer access not available to DBA team | Confirmed | Low | Access denied to InvestorPress_Encore_Prod billing account. DBA team cannot independently verify cost figures. Request read-only Cost Explorer access from Hermann or Jacobus for future cost work. | Lunga / Jacobus |

---

## Reassess When

The NO-GO recommendation should be revisited if any of the following conditions change:

| Condition | Why It Matters |
|---|---|
| Passive node exemption removed by AWS | Removes ~$26,000/year EC2 advantage — cost gap narrows significantly |
| Compute Savings Plans roll off and are not renewed | EC2 on-demand cost returns to ~$3,700/month — RDS may become cost-competitive |
| AWS launches RDS passive node exemption equivalent | Would close the licence cost gap directly |
| Operational overhead becomes critical | If EC2 management cost (people time) exceeds $37,600/year, managed service becomes viable |

---

## Links

| Ticket | Description |
|---|---|
| [TECH-3431](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3431) | Parent epic |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — inventory source |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — compatibility and cost source |
| [go-no-go-recommendation.md](./go-no-go-recommendation.md) | Full recommendation |
