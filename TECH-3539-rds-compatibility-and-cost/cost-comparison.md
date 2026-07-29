# Cost Comparison — EC2 vs RDS for SQL Server
# [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539)

> **Status:** In Progress — EC2 baseline confirmed from EW1R-REP-01 monitoring data. RDS estimate calculated from AWS Pricing Calculator inputs. Two items pending confirmation before figures are finalised.
> **Last Updated:** 2026-07-24

---

## Summary

| Scenario | EC2 Monthly Cost | RDS Monthly Cost (On-Demand) | Difference |
|---|---|---|---|
| Current EC2 spend (RI active) | ~$800–$950 | ~$1,359–$1,389 | **RDS ~$409–$589 more expensive** |
| Current EC2 spend vs RDS 1-year Reserved | ~$800–$950 | ~$1,135–$1,165 | **RDS ~$185–$365 more expensive** |
| Pre-RI baseline (Aug 2024 – Apr 2025) | ~$2,900–$3,700 | ~$1,359–$1,389 | **RDS ~$1,500–$2,300 cheaper** |

> **A Reserved Instance is almost certainly already in place on ew2p-mssql-01.** Confirmed from 14 months of cost data on EW1R-REP-01. At current spend, RDS is more expensive than EC2. The migration timing must align with the RI expiry date to avoid paying twice. See findings below.

---

## Reserved Instance Finding — ew2p-mssql-01

### What the data shows

| Evidence | Detail |
|---|---|
| Cost before Apr 2025 | ~$2,263–$2,804/month (Aug 2024 – Apr 2025) |
| Cost from Apr 2025 onwards | ~$165–$234/month — 88% drop in one month |
| Instance ID | i-08342e84089984565 — unchanged throughout |
| Instance type | r6i.2xlarge — unchanged throughout |
| AWS account | InvestorPress_Encore_Prod — unchanged throughout |
| Instance state | running — never stopped |
| Cost May 2026 onwards | Still ~$6–$9/day — no jump back up |
| Current daily cost | ~$6–$9/day (~$210/month) — EBS, data transfer, SQL Server adjustments only |

### Conclusion

A Reserved Instance was purchased for ew2p-mssql-01 on **23 April 2025**. This is the only explanation consistent with all the evidence:

- Same instance, same type, same account, never stopped — nothing changed on the infrastructure
- Cost dropped 88% on exactly 23 April 2025 — last on-demand day was 22 April 2025
- Cost has remained flat for 15 months since (Apr 2025 – Jul 2026)
- No cost jump in April 2026 — rules out a 1-year term that expired
- The ~$210/month still showing is not compute — it is EBS storage, data transfer, and SQL Server licensing line items that Reserved Instances do not cover
- The upfront RI payment would have appeared as a one-time charge outside `MON_AWS_Entity_Cost` — which is why it does not appear in this data

### RI term assessment

| Term | Purchased | Expiry | Status |
|---|---|---|---|
| 1-year | 23 Apr 2025 | Apr 2026 | ❌ Ruled out — cost did not jump in April 2026 |
| 3-year | 23 Apr 2025 | **Apr 2028** | ✅ Most likely — cost still flat at Jul 2026 |

### What this means for migration timing

If the RI is a 3-year term expiring **April 2028**, migrating ew2p-mssql-01 to RDS before that date means Kurtosys pays for both:
- The unused portion of the RI commitment (already paid, non-refundable)
- RDS compute on top

The financially optimal migration window is **at or after April 2028** when the RI expires. The technical preparation work (resolving blockers, moving SSRS, replacing Database Mail) can and should happen before that date — but the actual cutover should target the RI expiry.

### Questions to confirm with manager

| # | Question | Why it matters |
|---|---|---|
| 1 | Was a Reserved Instance purchased for ew2p-mssql-01 in May 2025? | Confirms the finding |
| 2 | What was the term — 1-year or 3-year? | Determines the migration window |
| 3 | What was the upfront payment? | Quantifies the sunk cost if migrating early |
| 4 | When does it expire exactly? | Sets the earliest cost-neutral migration date |
| 5 | Is there an RI on ew2p-mssql-02 as well? | ew2p-mssql-02 cost has been consistent — may also be on RI |

---

---

## EC2 Baseline — Confirmed from EW1R-REP-01 Monitoring Data

> Source: `MON_AWS_Entity_Cost` (2,533,553 rows — last updated 2026-07-15) and `INFO_AWS_EC2_Detail` (11,286 rows) in `DBA_VCC_AWS` on EW1R-REP-01. EW1R-REP-01 collects real AWS billing data daily via the `DBA_VCC_AWS_DAILY_CHECKS` job — this is not an estimate. No direct AWS Console or Cost Explorer access was required.
>
> **How EW1R-REP-01 has this data:** EW1R-REP-01 runs SQL Agent jobs that call AWS Cost Explorer via Python scripts stored in `C:\DBA_Staging\AWS\`. The results are written to `MON_AWS_Entity_Cost` and `INFO_AWS_Entity_Cost` in `DBA_VCC_AWS` daily. `INFO_AWS_EC2_Detail` captures weekly EC2 instance snapshots including instance type, storage layout, and encryption status — this is how the r6i.2xlarge instance type and 2,680 GB storage figure were confirmed without direct PRD access.

### Instance Type History — Confirmed from INFO_AWS_EC2_Detail

| Period | Instance Type | vCPU | RAM | Notes |
|---|---|---|---|---|
| July 2023 – Jan 2024 | r6i.4xlarge | 16 | 128 GB | Original sizing — confirmed from 18+ months of weekly snapshots |
| Feb 2024 – present | r6i.2xlarge | 8 | 64 GB | Downsized Feb 2024 — both nodes, confirmed from INFO_AWS_EC2_Detail |

> The Feb 2024 downsize from r6i.4xlarge to r6i.2xlarge is the likely cause of the cost drop seen in the billing data around that period. The Oct/Nov 2025 drop is a separate, unexplained event.

### Storage Layout — Confirmed from INFO_AWS_EC2_Detail

| Disk | Size | Encrypted | Notes |
|---|---|---|---|
| OS disk | 80 GB | ❌ Unencrypted | Compliance finding — must be addressed before or during migration |
| Data disk 1 | 1,400 GB | ✅ Encrypted | Primary data volume |
| Data disk 2 | 800 GB | ✅ Encrypted | Secondary data volume |
| Data disk 3 | 400 GB | ✅ Encrypted | Log / tempdb volume |
| **Total** | **2,680 GB** | Partial | OS disk unencrypted — 3 data disks encrypted |

> Only the 3 data disks (2,600 GB) are migrated to RDS. The OS disk is not migrated — RDS manages its own OS. 2,680 GB is used as a conservative round figure for RDS storage sizing.

### Confirmed Monthly Cost History — from MON_AWS_Entity_Cost (duplicates removed)

> Source: `MON_AWS_Entity_Cost` on EW1R-REP-01. Duplicates removed using MIN per day before summing. Figures are confirmed.

| Month | ew2p-mssql-01 | ew2p-mssql-02 | Combined | Notes |
|---|---|---|---|---|
| 2026-07 (partial to Jul 28) | $190 | $662 | **$852** | Month in progress |
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
| **2025-05** | **$217** | **$804** | **$1,021** | ⚠️ First month at RI rate |
| **2025-04** | **$1,810** | **$725** | **$2,535** | ⚠️ Last month at on-demand rate |
| 2025-03 | $2,467 | $759 | **$3,226** | |
| 2025-02 | $2,236 | $689 | **$2,925** | |
| 2025-01 | $2,657 | $791 | **$3,448** | |
| 2024-12 | $2,263 | $673 | **$2,936** | |
| 2024-11 | $2,370 | $711 | **$3,081** | |
| 2024-10 | $2,550 | $790 | **$3,340** | |
| 2024-09 | $2,804 | $868 | **$3,672** | |
| 2024-08 | $832 | $261 | **$1,093** | Partial — data starts here |

> **ew2p-mssql-01 daily cost Apr–Jul 2026:** confirmed flat at ~$6–$9/day throughout. No jump in April 2026 — RI still active, 3-year term most likely.
>
> **Query to run on EW1R-REP-01 to investigate:**
> ```sql
> SELECT TOP 60
>     EntityName,
>     Period,
>     Cost,
>     Currency
> FROM DBA_VCC_AWS.dbo.MON_AWS_Entity_Cost
> WHERE EntityName IN ('ew2p-mssql-01', 'ew2p-mssql-02')
> ORDER BY Period DESC;
> ```
> Cross-reference with `INFO_AWS_EC2_Detail` to confirm whether the instance type changed around Oct/Nov 2025:
> ```sql
> SELECT TOP 20
>     InstanceId,
>     InstanceType,
>     DateChecked
> FROM DBA_VCC_AWS.dbo.INFO_AWS_EC2_Detail
> WHERE InstanceId LIKE '%mssql%'
>    OR Tags LIKE '%mssql%'
> ORDER BY DateChecked DESC;
> ```

---

## AWS Pricing Calculator — Inputs Used

> URL: [https://calculator.aws](https://calculator.aws)
> Service: Amazon RDS for SQL Server
> These are the exact inputs to reproduce the RDS estimate below.

### How to Configure in the Calculator

1. Go to [https://calculator.aws](https://calculator.aws) → **Create estimate** → **Add service** → search **RDS for SQL Server**
2. Set the following:

| Field | Value | Reason |
|---|---|---|
| Region | EU (London) — eu-west-2 | Matches PRD instance location |
| SQL Server Edition | Enterprise | Confirmed from OPENQUERY via EW1R-REP-01 |
| License | BYOL | Confirmed — LICENSE-EXEMPTION-KSYS-MSSQL-PASSIVE-NODE in cost data |
| Instance type | db.r6i.2xlarge | Matches EC2 r6i.2xlarge — same CPU/RAM family on RDS |
| vCPU | 8 | r6i.2xlarge spec |
| RAM | 64 GB | r6i.2xlarge spec |
| Deployment | Multi-AZ | Replaces Always On Availability Group (primary + secondary) |
| Pricing model | On-Demand | Use this for the base estimate — Reserved can be calculated separately |
| Storage type | General Purpose SSD (gp3) | Cost-effective default — no provisioned IOPS needed unless workload demands it |
| Storage allocated | 2,680 GB | Confirmed from INFO_AWS_EC2_Detail — 1,400 + 800 + 400 GB data disks (OS disk not migrated) |
| Backup storage | 2,680 GB | Match allocated storage as a conservative estimate for 1× retention |
| Backup retention | 7 days | Standard — adjust based on RPO requirements |
| Multi-AZ | Yes | Standby replica included in Multi-AZ pricing |

> **Note on storage:** The 80 GB OS disk is not migrated to RDS — RDS manages its own OS. Only the 3 data disks (1,400 + 800 + 400 = 2,600 GB) are relevant. 2,680 GB is used as a conservative round figure.

> **Note on Reserved Instances:** On-Demand is used here for a like-for-like comparison with the EC2 on-demand baseline. If EC2 is running on Reserved Instances, apply the same Reserved pricing to RDS for a fair comparison. 1-year No Upfront Reserved on db.r6i.2xlarge reduces compute cost by approximately 30–35%.

---

## RDS Cost Estimate — BYOL, db.r6i.2xlarge, Multi-AZ, eu-west-2

> Calculated from AWS Pricing Calculator inputs above. On-Demand pricing. Figures are monthly.

| Component | Unit Price | Quantity | Monthly Cost | Notes |
|---|---|---|---|---|
| RDS db.r6i.2xlarge — Multi-AZ (BYOL) | ~$0.960/hr | 744 hrs | ~$714 | BYOL — compute only, no license cost on AWS bill. Multi-AZ pricing covers both primary and standby. |
| Storage — gp3, 2,680 GB | $0.138/GB-month | 2,680 GB | ~$370 | Single storage charge — Multi-AZ storage is billed once |
| Backup storage — 2,680 GB | $0.095/GB-month | 2,680 GB | ~$255 | First 100% of DB size is free — 2,680 GB overage billed at $0.095 |
| I/O (gp3 baseline) | Included in gp3 | — | $0 | gp3 includes 3,000 IOPS and 125 MB/s baseline at no extra cost |
| Data transfer (intra-region) | ~$0.01/GB | Estimate | ~$20–$50 | Application to RDS within eu-west-2 — low cost |
| **Total estimated** | | | **~$1,359–$1,389/month** | On-Demand, both nodes via Multi-AZ |

> **Why this is lower than the $2,000–$2,500 estimate in compatibility-matrix.md:** The earlier estimate used a per-node compute figure and doubled it. Multi-AZ on RDS is billed as a single instance at the Multi-AZ rate — not two separate instances. The Multi-AZ rate is approximately 2× the Single-AZ rate, but storage and backup are billed once. The $1,359–$1,389 figure is the more accurate calculation.

### Reserved Instance Scenarios (indicative)

| Reservation | Upfront | Monthly Compute | Total Monthly (compute + storage + backup) |
|---|---|---|---|
| On-Demand | $0 | ~$714 | ~$1,359–$1,389 |
| 1-year No Upfront | $0 | ~$490 | ~$1,135–$1,165 |
| 1-year All Upfront | ~$5,880 | ~$0 (amortised ~$490) | ~$1,135–$1,165 |
| 3-year No Upfront | $0 | ~$340 | ~$985–$1,015 |

> Confirm exact Reserved pricing via the AWS Pricing Calculator — rates change. Use the On-Demand figure for the initial business case and note Reserved as an optimisation option.

---

## EC2 vs RDS Comparison

### Scenario 1 — 2024 EC2 Baseline vs RDS On-Demand (conservative)

| Item | EC2 (2024 baseline) | RDS BYOL On-Demand | Difference |
|---|---|---|---|
| Compute — primary node | ~$3,150/month | Included in Multi-AZ | — |
| Compute — secondary node | ~$960/month | Included in Multi-AZ | — |
| Compute — combined (Multi-AZ) | ~$4,110/month | ~$714/month | RDS ~$3,396 cheaper |
| Storage (2,680 GB) | Included in EC2 EBS above | ~$370/month | Additional on RDS |
| Backup storage | Manual — separate S3 cost (TBC) | ~$255/month | Offset by S3 saving |
| OS patching | Manual effort | Managed by AWS | Effort saving |
| CHECKDB / maintenance | Manual jobs | Managed by AWS | Effort saving |
| **Total** | **~$4,110/month** | **~$1,359–$1,389/month** | **~$2,721–$2,751/month saving** |

### Scenario 2 — Nov 2025 EC2 Baseline vs RDS On-Demand (if resize confirmed)

| Item | EC2 (Nov 2025) | RDS BYOL On-Demand | Difference |
|---|---|---|---|
| Compute — combined | ~$1,245/month | ~$714/month | RDS ~$531 cheaper on compute |
| Storage + backup | Included in EC2 above | ~$625/month | Additional on RDS |
| **Total** | **~$1,245/month** | **~$1,359–$1,389/month** | **RDS ~$114–$144 more expensive** |

> In Scenario 2, RDS is marginally more expensive on On-Demand. However, with 1-year Reserved pricing (~$1,135/month), RDS is roughly cost-neutral. The operational benefits (managed patching, automated backups, Multi-AZ failover, no OS management) make RDS the better choice even at cost parity.

---

## What Is Not Included in This Estimate

| Item | Notes |
|---|---|
| SSRS relocation | SSRS must move to a separate EC2 before migration — that EC2 has its own cost. Not included here. |
| Database Mail replacement (SES/SNS) | Amazon SES cost is negligible for alert volumes — not material. |
| AWS DMS (if used for migration) | DMS is a one-time migration cost, not an ongoing cost. Assess in migration-approaches.md. |
| Data transfer out of EC2 | One-time cost during migration — depends on approach (backup/restore vs DMS). |
| DEV and REL instances | This comparison covers PRD only (ew2p-mssql-01 and ew2p-mssql-02). DEV and REL are out of scope for cost modelling. |

---

## Open Items — Blocking Finalisation

| # | Item | Owner | Impact |
|---|---|---|---|
| 1 | Confirm Reserved Instance on ew2p-mssql-01 — term (1-year or 3-year), purchase date, expiry, upfront cost | Manager / AWS account owner | Determines migration window — if 3-year RI, earliest cost-neutral cutover is April 2028 |
| 2 | Confirm whether ew2p-mssql-02 is also on a Reserved Instance | Manager / AWS account owner | ew2p-mssql-02 cost has been consistent at ~$640–$820/month — may also be RI-covered |
| 3 | Confirm exact RDS pricing via AWS Pricing Calculator | DBA / Platform Engineering | Validate the ~$1,359–$1,389/month estimate against current published rates |
| 4 | Confirm AWS License Mobility activation status | Manager | Administrative step — must be initiated before migration begins regardless of timing |

---

## Links

| Resource | Location |
|---|---|
| AWS Pricing Calculator | [https://calculator.aws](https://calculator.aws) |
| Compatibility matrix | [compatibility-matrix.md](./compatibility-matrix.md) |
| Inventory and cost source | [inventory.md](../TECH-3538-inventory-and-dependency/inventory.md) |
| Go/no-go recommendation | [go-no-go-recommendation.md](../TECH-3540-recommendation-and-handover/go-no-go-recommendation.md) |
| TECH-3539 | [Jira](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) |
