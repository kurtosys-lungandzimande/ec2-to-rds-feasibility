# Cost Comparison — EC2 vs RDS for SQL Server
# [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539)

> **Status:** Complete — Cost case closed by Hermann Lotter 2026-07-29. All figures corrected.
> **Last Updated:** 2026-07-29

---

## Summary

| Scenario | EC2 Monthly Cost | RDS Monthly Cost | Difference |
|---|---|---|---|
| EC2 today (after commitments) | $3,799.08 | ~$6,933 | **RDS ~$3,134/month (~$37,600/year) more expensive** |

> **Source:** Hermann Lotter, TECH-3431 comment, 2026-07-29. EC2 figures measured from Cost Explorer and deduplicated CUR line items. RDS figures at list pricing — db.r6i.2xlarge SQL Server Enterprise License Included Multi-AZ, eu-west-2.
>
> **Key driver:** The passive node (ew2p-mssql-02) bills at the plain Windows rate ($0.96/hr) on EC2 — no SQL Server licence charge. This is worth ~$26,000/year. RDS does not offer this exemption. Storage is the second major swing — same 5,360 GiB moves from $532/month on EBS to $1,426/month on RDS.

---

## Reserved Instance and Commitment Position — Confirmed 2026-07-29

> Source: Hermann Lotter, TECH-3431 comment, 2026-07-29. Figures measured, not estimated.

| Item | Confirmed Fact |
|---|---|
| RI on ew2p-mssql-01 | No 3-year RI. 1-year convertible RI ended 2025-12-02 |
| Current coverage | Two Region-scoped convertible No Upfront RIs, end date 2026-09-08 |
| ew2p-mssql-02 | Covered by Compute Savings Plan (not RI) |
| License model | AWS License Included — not BYOL. Moved off SoftCat. |
| Passive node billing | ew2p-mssql-02 bills at plain Windows rate ($0.96/hr) vs $3.96/hr for active node — ~$26,000/year saving |
| Compute Savings Plans | Portfolio runs above 99% utilisation. Plans end 2026-10-18, 2026-11-06, 2027-06-14. Compute SPs cover EC2 but not RDS. |

> **What the original cost data showed:** The ~88% cost drop on ew2p-mssql-01 from April 2025 was real but misread. It was a short-term RI (1-year convertible), not a 3-year term. ProsperOps exchanges convertible RIs as they roll off — coverage is continuous by design, which is why cost stayed flat through April 2026. The flat cost was not evidence of a 3-year term.

> **Migration timing implication:** There is no April 2028 RI expiry window. Any future migration would need to align with Compute Savings Plan end dates (2026-10-18, 2026-11-06, 2027-06-14) to avoid wasting committed EC2 spend.

---

---

## Measured EC2 Cost — Confirmed 2026-07-29

> Source: Hermann Lotter, TECH-3431 comment, 2026-07-29. March 2026, full 744-hour month, both instances plus storage, at the effective rate after commitment discounts. Cross-checked against Cost Explorer to within one percent.

| Item | Monthly |
|---|---|
| ew2p-mssql-01 — compute and SQL licence | $2,753.92 |
| ew2p-mssql-02 — compute only (passive node, no SQL licence) | $512.95 |
| EBS — 5,360 GiB gp3 + provisioned throughput | $532.21 |
| **Total** | **$3,799.08 (~$45,600/year)** |

> **Do not use the datalake CUR table for cost baselines on this epic.** Use Cost Explorer and deduplicated CUR line items only (per Hermann's note).
>
> **Access note:** Cost Explorer access to the InvestorPress_Encore_Prod billing account is not available under the current login — access denied when attempting to verify. Hermann Lotter's figures are the authoritative source for this epic. To independently verify in future, request read-only Cost Explorer access to the central billing account from Hermann or Jacobus.

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

## RDS Cost — List Pricing (db.r6i.2xlarge SQL Ent LI Multi-AZ, eu-west-2)

> Source: Hermann Lotter, TECH-3431 comment, 2026-07-29.

| Option | Compute & Licence | Storage | Annual |
|---|---|---|---|
| EC2 today (after commitments) | $38,413 | $6,387 | ~$45,600 |
| RDS SQL Ent LI Multi-AZ (list) | $66,094 | $17,109 | ~$83,200 |

> Storage is the larger swing — same 5,360 GiB moves from $532/month on EBS ($0.093/GB-month) to $1,426/month on RDS ($0.266/GB-month for a SQL Server mirror).
>
> Standard RDS Multi-AZ pricing may carry partial standby licence relief — unconfirmed. Full passive node exemption on RDS Custom is reported but unconfirmed, and RDS Custom reintroduces much of the operational overhead this epic aims to remove.

---

## EC2 vs RDS Comparison — Confirmed 2026-07-29

| Option | Compute & Licence | Storage | Annual |
|---|---|---|---|
| EC2 today (after commitments) | $38,413 | $6,387 | ~$45,600 |
| RDS SQL Ent LI Multi-AZ (list) | $66,094 | $17,109 | ~$83,200 |
| **Difference** | | | **~$37,600/year more on RDS** |

> The low end of the gap (~$30,000/year) assumes RDS picks up commitment discounts comparable to today. Backups and snapshots excluded on both sides.

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

## Open Items

| # | Item | Owner | Status |
|---|---|---|---|
| 1 | Manager sign-off on NO-GO recommendation | Jacobus | Open |
| 2 | AWS EC2 HA programme — 2022 programme vs GA feature (launched 2025-11-17) | Hermann | Open — Hermann picking up with AWS account team |

---

## Links

| Resource | Location |
|---|---|
| AWS Pricing Calculator | [https://calculator.aws](https://calculator.aws) |
| Compatibility matrix | [compatibility-matrix.md](./compatibility-matrix.md) |
| Inventory and cost source | [inventory.md](../TECH-3538-inventory-and-dependency/inventory.md) |
| Go/no-go recommendation | [go-no-go-recommendation.md](../TECH-3540-recommendation-and-handover/go-no-go-recommendation.md) |
| TECH-3539 | [Jira](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) |
