# EC2 to RDS Feasibility — SQL Server Migration Evaluation [2026]

> **Epic:** Evaluate migrating SQL Server from self-managed EC2 to Amazon RDS — feasibility assessment only.
> **Status:** Investigation Complete — Recommendation: NO-GO. Stay on EC2. Pending manager sign-off.
> **Last Updated:** 2026-07-29

This epic delivers a go/no-go recommendation only. No migration execution, no pilot cutover, no production instance moves.

---

## Recommendation — NO-GO. Stay on EC2.

Cost case closed by Hermann Lotter 2026-07-29. RDS costs ~$37,600/year more than the current EC2 setup. The passive node licence exemption (~$26,000/year) does not exist on RDS. This is a deliberate trade, not a saving.

- EC2 measured cost: $3,799.08/month (~$45,600/year) — March 2026, after commitment discounts
- RDS list cost: ~$6,933/month (~$83,200/year) — db.r6i.2xlarge SQL Ent LI Multi-AZ, eu-west-2
- Gap: ~$37,600/year more on RDS
- Pending: manager sign-off (Jacobus)

---

## Key Findings

| Finding | Detail |
|---|---|
| Instances | ew2p-mssql-01 (primary) + ew2p-mssql-02 (secondary), r6i.2xlarge, eu-west-2 |
| SQL Server | 2019 Enterprise (15.0.4455.2) CU32, AWS License Included |
| Databases | 20 databases, ~803 GB — 18 clean, 2 blocked (moot — NO-GO) |
| Always On | Active — passive node bills at Windows rate only (~$26,000/year saving vs RDS) |
| Current EC2 cost | $3,799.08/month (~$45,600/year) — measured March 2026, after commitment discounts |
| RDS list cost | ~$6,933/month (~$83,200/year) — db.r6i.2xlarge SQL Ent LI Multi-AZ, eu-west-2 |
| License model | AWS License Included — not BYOL. No Microsoft licence commitment to unwind |
| RI / commitment | No 3-year RI. 1-year convertible ended 2025-12-02. Current coverage ends 2026-09-08. ew2p-mssql-02 on Compute Savings Plan |
| Hard blockers | CLR UNSAFE assemblies (SECURITYBENEFIT, RWC), SSRS on same instance — moot given NO-GO |

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
        go-no-go-recommendation.md                   ← NO-GO recommendation — stay on EC2
        ec2-to-rds-architecture.drawio               ← Architecture diagram — current vs future state
```

---

## Child Tickets

| Ticket | Title | Status |
|---|---|---|
| [TECH-3537](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3537) | Investigation and Discovery Planning | Done |
| [TECH-3538](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3538) | Theme A — Inventory and Dependency Reassessment | Done |
| [TECH-3539](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3539) | Theme B — RDS Compatibility and Cost Analysis | Done |
| [TECH-3540](https://kurtosys-prod-eng.atlassian.net/jira/software/c/projects/TECH/boards/795?selectedIssue=TECH-3540) | Theme C — Recommendation and Handover | In Progress — pending sign-off |

---

## Pending — Blocking Epic Closure

| # | Question | Owner | Impact |
|---|---|---|---|
| 1 | Manager sign-off on NO-GO recommendation | Jacobus | Epic closure |
| 2 | AWS EC2 HA programme — 2022 programme vs GA feature (launched 2025-11-17) | Hermann | **Closed — GA confirmed by Lunga** |
