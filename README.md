# EC2 to RDS Feasibility — SQL Server Migration Evaluation [2026]

> **Epic:** Evaluate migrating SQL Server from self-managed EC2 to Amazon RDS — feasibility assessment only.
> **Status:** In Progress — Investigation complete. Pending account manager confirmation on RI term and license commitment.
> **Last Updated:** 2026-07-28

This epic delivers a go/no-go recommendation only. No migration execution, no pilot cutover, no production instance moves.

---

## Recommendation — GO with Conditions

- 18 of 20 databases are clean and ready to migrate
- 2 databases blocked — SECURITYBENEFIT and RWC (UNSAFE CLR assemblies)
- SSRS must move off the instance before migration
- Database Mail must be replaced with Amazon SES/SNS
- **Earliest cost-neutral migration window: April 2028** — RI on ew2p-mssql-01 purchased 23 Apr 2025, 3-year term most likely
- Pending: account manager confirmation of RI term, expiry, and BYOL license commitment

---

## Key Findings

| Finding | Detail |
|---|---|
| Instances | ew2p-mssql-01 (primary) + ew2p-mssql-02 (secondary), r6i.2xlarge, eu-west-2 |
| SQL Server | 2019 Enterprise (15.0.4455.2) CU32, BYOL confirmed |
| Databases | 20 databases, ~803 GB — 18 clean, 2 blocked |
| Always On | Active — replaced by RDS Multi-AZ |
| Current EC2 cost | ~$800–$950/month combined (post-RI) |
| RDS on-demand cost | ~$1,359–$1,389/month — ~$409–$589/month more than current EC2 |
| Reserved Instance | ew2p-mssql-01 — purchased 23 Apr 2025, 3-year term, expiry Apr 2028 |
| Hard blockers | CLR UNSAFE assemblies (SECURITYBENEFIT, RWC), SSRS on same instance |
| Migration window | April 2028 — earliest cost-neutral cutover |

---

## Repository Structure

```
ec2-to-rds-feasibility/
│
│   README.md                                        ← This file
│
├── TECH-3537-planning-and-discovery/                ← Planning & Discovery
│   │   planning-summary.md                          ← Master planning doc — all open questions
│   │   discovery-queries.sql                        ← 17-section SQL query file
│
├── TECH-3538-inventory-and-dependency/              ← Theme A
│   │   inventory.md                                 ← EC2 instance inventory, cost baseline, BYOL evidence
│
├── TECH-3539-rds-compatibility-and-cost/            ← Theme B
│   │   compatibility-matrix.md                      ← Feature compatibility — 7 blockers assessed
│   │   cost-comparison.md                           ← Full cost model — EC2 vs RDS, RI finding
│
└── TECH-3540-recommendation-and-handover/           ← Theme C
        go-no-go-recommendation.md                   ← GO recommendation with conditions
        ec2-to-rds-architecture.drawio               ← Architecture diagram — current vs future state
```

---

## Child Tickets

| Ticket | Title | Status |
|---|---|---|
| [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) | Investigation and Discovery Planning | In Progress |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — Inventory and Dependency Reassessment | In Progress |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — RDS Compatibility and Cost Analysis | In Progress |
| [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540) | Theme C — Recommendation and Handover | In Progress |

---

## Pending — Blocked on Account Manager Response

| # | Question | Impact |
|---|---|---|
| 1 | Confirm RI term and expiry for ew2p-mssql-01 — believed 3-year, expiry Apr 2028 | Confirms migration window |
| 2 | Confirm RI status for ew2p-mssql-02 | May affect combined cost baseline |
| 3 | Confirm BYOL license commitment — any lock-in? | Affects migration timing |
| 4 | Any RDS Reserved Instance pricing available? | Could close the cost gap |
