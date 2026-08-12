# AWS Pricing Calculator Guide — RDS vs EC2 Cost Comparison
# TECH-3539 — RDS Compatibility and Cost Analysis

> **Purpose:** Step-by-step guide to reproduce the RDS cost estimate using the AWS Pricing Calculator.
> Anyone running this estimate independently should get the same figures as the ones documented in [cost-comparison.md](./cost-comparison.md).
> **Last Updated:** 2026-07-30

---

## What You Are Estimating

You are estimating the cost of running SQL Server Enterprise on Amazon RDS in the London region (eu-west-2), configured to match the current EC2 setup as closely as possible.

| Current EC2 Setup | RDS Equivalent |
|---|---|
| ew2p-mssql-01 + ew2p-mssql-02 (primary + secondary) | db.r6i.2xlarge Multi-AZ (single instance, standby managed by AWS) |
| r6i.2xlarge — 8 vCPU, 64 GB RAM | db.r6i.2xlarge — same spec |
| SQL Server 2019 Enterprise, AWS License Included | SQL Server Enterprise, License Included |
| 2,680 GB EBS gp3 storage | 2,680 GB RDS gp3 storage |
| eu-west-2 (London) | eu-west-2 (London) |

---

## Step-by-Step Instructions

### Step 1 — Open the Calculator

Go to [https://calculator.aws](https://calculator.aws)

Click **"Create estimate"**.

---

### Step 2 — Add RDS for SQL Server

1. In the search box type **RDS**
2. Select **"Amazon RDS for SQL Server"**
3. Click **"Configure"**

---

### Step 3 — Set the Region

At the top of the configuration page, set the region to:

> **EU (London) — eu-west-2**

---

### Step 4 — Configure the Instance

Fill in the following fields exactly:

| Field | Value |
|---|---|
| SQL Server Edition | **Enterprise** |
| License | **License Included** |
| Instance type | **db.r6i.2xlarge** |
| Deployment option | **Multi-AZ** |
| Utilisation | **100%** |
| Pricing model | **On-Demand** first, then switch to Reserved (see Step 6) |

> **Why Multi-AZ?** Multi-AZ is the RDS equivalent of the current Always On Availability Group setup (primary + secondary). It is billed as a single instance at the Multi-AZ rate — you do not pay for two separate instances.

---

### Step 5 — Configure Storage

Scroll down to the storage section and set:

| Field | Value |
|---|---|
| Storage type | **General Purpose SSD (gp3)** |
| Storage amount | **2,680 GB** |

> **Why 2,680 GB?** This matches the three data disks on the current EC2 nodes (1,400 GB + 800 GB + 400 GB = 2,600 GB, rounded up to 2,680 GB as a conservative figure). The 80 GB OS disk is not migrated — RDS manages its own OS.

Leave backup storage at default for now — automated backup storage is not included in the EC2 baseline either, so exclude it for a like-for-like comparison.

---

### Step 6 — Compare On-Demand vs Reserved Pricing

#### On-Demand
Leave the pricing model as **On-Demand** and note the monthly total.

Expected result: **~$5,508/month (~$66,094/year)**

This matches Hermann Lotter's confirmed figure from TECH-3431 (2026-07-29).

#### Reserved — 1 Year
Switch the pricing model to **Reserved** and set:

| Field | Value |
|---|---|
| Term | **1 year** |
| Payment option | **All Upfront** |

Note the monthly equivalent.

Expected result: **~$5,128/month (~$61,532/year)**

Then change payment option to **Partial Upfront** and note again.

Expected result: **~$5,232/month (~$62,788/year)**

---

### Step 7 — Save and Share the Estimate

1. Click **"Save and share"** at the top right
2. Click **"Agree and continue"**
3. Copy the shareable link

Paste this link into:
- The Jira ticket comment on TECH-3539
- The Confluence cost comparison page
- Your reply to Hermann

This allows anyone to open the exact estimate and verify the figures independently.

---

## Expected Results Summary

| Pricing Option | Monthly | Annual | vs Current EC2 ($45,600/yr) |
|---|---|---|---|
| EC2 today (measured, March 2026) | $3,799 | ~$45,600 | baseline |
| RDS On-Demand | ~$5,508 | ~$66,094 | ~$20,494/yr more |
| RDS 1yr All Upfront | ~$5,128 | ~$61,532 | ~$15,932/yr more |
| RDS 1yr Partial Upfront | ~$5,232 | ~$62,788 | ~$17,188/yr more |

> The 1-year RI reduces the gap but does not close it. RDS is still ~$16,000–$17,000/year more expensive than the current EC2 setup even with a 1-year commitment. This does not change the NO-GO recommendation.

---

## What the Calculator Does Not Include

These items are excluded from the estimate above to keep it like-for-like against the EC2 baseline:

| Item | Why Excluded |
|---|---|
| Automated backup storage | Not included in EC2 baseline either |
| SSRS relocation EC2 | One-time infrastructure change — separate cost |
| AWS DMS (if used for migration) | One-time migration cost only |
| Data transfer out of EC2 | One-time migration cost only |
| Database Mail replacement (SES/SNS) | Negligible cost at alert volumes |

---

## Troubleshooting — If Your Numbers Look Different

| Symptom | Likely Cause | Fix |
|---|---|---|
| Monthly cost is roughly double | Selected per-node pricing instead of Multi-AZ | Make sure Deployment option is set to **Multi-AZ**, not **Single-AZ** |
| Cost is much lower than expected | Selected Standard or Web edition instead of Enterprise | Check SQL Server Edition is set to **Enterprise** |
| Cannot find db.r6i.2xlarge | Searching in wrong region | Confirm region is set to **EU (London) — eu-west-2** at the top |
| Storage cost looks wrong | Using io1 instead of gp3 | Set storage type to **General Purpose SSD (gp3)** |

---

## Links

| Resource | Location |
|---|---|
| AWS Pricing Calculator | [https://calculator.aws](https://calculator.aws) |
| Verified estimate (TECH-3539) | https://calculator.aws/#/estimate?id=4de608073e6897f7fc21deae0be40bd84e16537d |
| Cost comparison doc | [cost-comparison.md](./cost-comparison.md) |
| Compatibility matrix | [compatibility-matrix.md](./compatibility-matrix.md) |
| Go/no-go recommendation | [go-no-go-recommendation.md](../TECH-3540-recommendation-and-handover/go-no-go-recommendation.md) |
| TECH-3539 | [Jira](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) |
