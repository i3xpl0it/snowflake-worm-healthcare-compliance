# 🔒 Snowflake WORM Backups for Healthcare Compliance

> **Production-grade HIPAA compliance architecture using Snowflake's immutable backup system with retention locks. Demonstrates ransomware-resistant data protection for healthcare organizations with SEC 17a-4(f) certification.**

[![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)](https://www.snowflake.com/)
[![HIPAA Compliant](https://img.shields.io/badge/HIPAA-Compliant-green?style=for-the-badge)](https://www.hhs.gov/hipaa)
[![SEC 17a-4(f)](https://img.shields.io/badge/SEC_17a--4(f)-Certified-blue?style=for-the-badge)](https://www.sec.gov/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

## 📋 Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Implementation Phases](#implementation-phases)
- [Compliance Mapping](#compliance-mapping)
- [Cost Analysis](#cost-analysis)
- [Testing & Validation](#testing--validation)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Resources](#resources)
- [License](#license)

---

## 🎯 Overview

This project demonstrates a production-ready implementation of **Snowflake's WORM (Write-Once-Read-Many) Backup system** (formerly WORM Snapshots, renamed Dec 10, 2025) for healthcare data protection.

### What This Project Provides:

✅ **Complete SQL Implementation** - Production-ready code for all 6 phases
✅ **HIPAA-Ready Architecture** - Demonstrates healthcare compliance patterns
✅ **SEC 17a-4(f) Certified** - Immutable backups that meet regulatory requirements  
✅ **Ransomware Resilient** - Backups that cannot be deleted, even by ACCOUNTADMIN
✅ **Point-in-Time Recovery** - Restore data to any moment within retention window
✅ **Audit Trail** - Complete logging for compliance and forensics

### New in Snowflake (Dec 2025):

🆕 **Terminology Update**: SNAPSHOT → BACKUP (all SQL commands updated)  
🆕 **General Availability**: WORM Backups now GA for all accounts (Dec 10, 2025)

---

## 🚨 The Problem

### Healthcare organizations face critical data risks:

**1. Ransomware Attacks**
- Average ransom: **$4.4M** (healthcare sector, 2024)
- Attackers delete backups first
- Traditional backups are vulnerable

**2. Compliance Requirements**
- **HIPAA**: Patient data must be protected against unauthorized deletion
- **SEC 17a-4(f)**: Financial/healthcare records must be immutable
- **21 CFR Part 11**: FDA requires tamper-proof electronic records

**3. Insider Threats**
- Malicious or accidental data deletion
- Privileged users (admins) can delete everything
- No recovery path after deletion

---

## ✅ The Solution

### Snowflake WORM Backups with Retention Lock

Snowflake's **immutable backup system** creates point-in-time copies that:

🔒 **Cannot be deleted** - Even by ACCOUNTADMIN or ORGADMIN
🔒 **Cannot be modified** - Immutable by design  
🔒 **Cannot be tampered with** - Cryptographically signed
🔒 **Are ransomware-proof** - Attackers cannot destroy recovery points

### How It Works:

```
┌─────────────────────────────────────────────────────────────┐
│  Production Database (healthcare_prod)                      │
│  ├─ patient_data schema                                     │
│  ├─ clinical_data schema                                    │
│  └─ compliance schema                                       │
└─────────────────────────────────────────────────────────────┘
                     ↓
         CREATE BACKUP POLICY
         (Every 6 hours, 90-day retention)
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  Automated Backups (healthcare_backup_set)                  │
│  ├─ Backup 1: 2026-01-04 06:00 [LOCKED]                   │
│  ├─ Backup 2: 2026-01-04 12:00 [LOCKED]                   │
│  ├─ Backup 3: 2026-01-04 18:00 [LOCKED]                   │
│  └─ ... (90 days of backups)                               │
└─────────────────────────────────────────────────────────────┘
                     ↓
      APPLY BACKUP RETENTION LOCK
      (IRREVERSIBLE - Cannot be undone)
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  Immutable Backups (protected for 90 days)                  │
│  ✅ Ransomware attack? Backups survive                      │
│  ✅ Admin deletes prod? Backups survive                     │
│  ✅ Insider threat? Backups survive                         │
│  ✅ Compliance audit? Full audit trail                      │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Features

### 1. Immutable Backups
- **Retention Lock** prevents deletion for specified period (90 days in this demo)
- **ACCOUNTADMIN cannot delete** - Highest privilege level cannot bypass
- **Certified Compliance** - SEC 17a-4(f) and SOC 2 Type II certified

### 2. Automated Policy-Based Backups
- **Scheduled Backups**: Every 6 hours (configurable)
- **Granular Control**: Database, schema, or table level
- **Efficient Storage**: Snowflake's incremental approach minimizes costs

### 3. Point-in-Time Recovery
- **Rapid Restore**: Recover to any backup within retention window
- **30-Second Recovery**: Create new table from backup instantly
- **Zero Data Loss**: Restore exact state at backup time

### 4. Complete Audit Trail
- **Event Table**: Immutable log of all backup operations
- **Forensic Analysis**: Track who, what, when, where
- **Compliance Reports**: Automated evidence for auditors

### 5. Legal Hold Support
- **Litigation Readiness**: Extend retention for legal cases
- **Granular Holds**: Specific tables or time periods
- **Audit Documentation**: Prove data preservation

---

## 🏛️ Architecture

### System Components

```
┌───────────────────────────────────────────────────────────────────┐
│                    GOVERNANCE LAYER                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ compliance_admin │  │ retention_lock   │  │ compliance     │ │
│  │    (Role)        │  │     _admin       │  │   _viewer      │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────┐
│                    DATA LAYER                                     │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │ healthcare_prod (Database)                                    ││
│  │  ├─ patient_data (Schema)                                     ││
│  │  │   ├─ patients (Table) ─────────────┐                      ││
│  │  │   └─ encounters (Table)            │                      ││
│  │  ├─ clinical_data (Schema)            │                      ││
│  │  │   └─ lab_results (Table)           │                      ││
│  │  └─ compliance (Schema)                │                      ││
│  │      └─ account_audit_events (Event   │                      ││
│  │          Table - Immutable Log)       │                      ││
│  └──────────────────────────────────────┼───────────────────────┘│
└─────────────────────────────────────────┼────────────────────────┘
                                           │
                                           ↓
┌──────────────────────────────────────────────────────────────────┐
│                    BACKUP LAYER                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Backup Policy (healthcare_backup_policy)                   │  │
│  │  • Schedule: Every 6 hours                                 │  │
│  │  • Retention: 90 days                                      │  │
│  │  • Objects: healthcare_prod.patient_data.*                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Backup Set (healthcare_backup_set)                         │  │
│  │  ├─ Backup_2026-01-04_06:00 [LOCKED - 89 days left]       │  │
│  │  ├─ Backup_2026-01-04_12:00 [LOCKED - 89 days left]       │  │
│  │  └─ ... (360 backups over 90 days)                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Retention Lock (IRREVERSIBLE)                              │  │
│  │  ✅ Applied: 2026-01-04                                    │  │
│  │  ✅ Duration: 90 days                                      │  │
│  │  ❌ Cannot be removed                                      │  │
│  │  ❌ Cannot be shortened                                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Prerequisites

### Snowflake Requirements
---------|  
| **Edition** | Business Critical or higher |
| **Feature** | WORM Backups (GA Dec 2025) |
| **Privileges** | ACCOUNTADMIN (for setup) |
| **Region** | All Snowflake regions supported |

### User Requirements

- **Snowflake Account** with Business Critical edition
- **Basic SQL knowledge** 
- **Understanding of backup/recovery concepts**

---

## 🚀 Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/i3xpl0it/snowflake-worm-healthcare-compliance.git
cd snowflake-worm-healthcare-compliance
```

### 2. Execute SQL Files in Order

```sql
-- Phase 1: Setup (5 minutes)
source sql/01-setup-prerequisites.sql

-- Phase 2: Sample Data (3 minutes)  
source sql/02-healthcare-data.sql

-- Phase 3: WORM Backups (10 minutes) ⚠️
source sql/03-worm-backups.sql

-- Phase 4: Audit Logging (5 minutes)
source sql/04-audit-logging.sql

-- Phase 5: Testing (15 minutes)
source sql/05-testing-recovery.sql

-- Phase 6: Compliance Queries (5 minutes)
source sql/06-compliance-queries.sql
```

### 3. Verify Implementation

```sql
-- Check backup policy
SHOW BACKUP POLICIES;

-- Check backups
SHOW BACKUPS IN BACKUP SET healthcare_backup_set;

-- Verify retention lock
SELECT 
    backup_set_name,
    retention_lock_status,
    retention_lock_end_time
FROM INFORMATION_SCHEMA.BACKUP_SETS;
```

---

## 📋 Implementation Phases

### Phase 1: Setup & Prerequisites (Day 1)

**Objective**: Create roles, database, and schemas

**Steps:**
1. Create 4 specialized compliance roles
2. Create `healthcare_prod` database
3. Create 3 schemas: `patient_data`, `clinical_data`, `compliance`
4. Grant appropriate privileges

**Output**: Foundation for HIPAA-compliant architecture

**SQL File**: `sql/01-setup-prerequisites.sql`

---

### Phase 2: Sample Healthcare Data (Day 1-2)

**Objective**: Populate with realistic healthcare data

**Steps:**
1. Create patient demographics table
2. Create clinical encounters table
3. Create lab results table
4. Insert sample HIPAA-like data

**Output**: 1000+ patient records for testing

**SQL File**: `sql/02-healthcare-data.sql`

---

### Phase 3: WORM Backup Configuration (Day 2-3) ⚠️ **CRITICAL**

**Objective**: Configure immutable backups with retention lock

**Steps:**
1. Create backup policy (6-hour schedule, 90-day retention)
2. Create backup set
3. **APPLY RETENTION LOCK** (⚠️ IRREVERSIBLE)
4. Verify lock is active

**⚠️ WARNING**: Retention lock CANNOT be removed once applied. Test thoroughly before production.

**Output**: Automated immutable backups every 6 hours

**SQL File**: `sql/03-worm-backups.sql`

---

### Phase 4: Audit Logging (Day 3)

**Objective**: Enable complete audit trail

**Steps:**
1. Create account-level event table
2. Configure audit logging
3. Create compliance queries
4. Set up monitoring views

**Output**: Immutable audit log for compliance

**SQL File**: `sql/04-audit-logging.sql`

---

### Phase 5: Testing & Recovery (Day 3-4)

**Objective**: Validate backup/recovery process

**Steps:**
1. Simulate data deletion
2. Perform point-in-time recovery
3. Verify data integrity
4. Test ransomware scenario
5. Validate retention lock

**Output**: Proven disaster recovery capability

**SQL File**: `sql/05-testing-recovery.sql`

---

### Phase 6: Compliance Queries (Day 4)

**Objective**: Generate compliance reports

**Steps:**
1. HIPAA compliance queries
2. SEC 17a-4(f) evidence
3. Audit trail reports
4. Backup status dashboard

**Output**: Audit-ready compliance reports

**SQL File**: `sql/06-compliance-queries.sql`

---

## 🏗️ Compliance Mapping

### HIPAA Security Rule

| HIPAA Requirement | Implementation |
|-------------------|----------------|
| **§164.308(a)(7)(ii)(A)** - Data Backup Plan | Automated backup policy |
| **§164.308(a)(7)(ii)(B)** - Disaster Recovery | Point-in-time recovery |
| **§164.312(b)** - Audit Controls | Event table logging |
| **§164.312(c)(1)** - Integrity Controls | Immutable backups |

### SEC 17a-4(f) Requirements

| SEC Requirement | Implementation |
|-----------------|----------------|
| **Non-Rewritable, Non-Erasable** | Retention lock prevents deletion |
| **Retain for Required Period** | 90-day (configurable) retention |
| **Verify Authenticity** | Cryptographic signing |
| **Duplicate Copy** | Snowflake's multi-region replication |

### 21 CFR Part 11 (FDA)

| FDA Requirement | Implementation |
|-----------------|----------------|
| **§11.10(a)** - Validated Systems | Snowflake's SOC 2 certification |
| **§11.10(c)** - Protection of Records | Immutable backups |
| **§11.10(e)** - Audit Trail | Event table logging |

---

## 💰 Cost Analysis

### Storage Costs

```
Production Data:     $40/TB/month
Backup Storage:      $23/TB/month (Snowflake's pricing)

Example (100 GB production data):
- Production: $4/month
- 90-day backups (incremental): ~$10-15/month
- Total: ~$14-19/month

ROI: Single ransomware prevention = $4.4M saved
```

### Compute Costs

```
Backup creation: Minimal (automated)
Recovery: ~$2/warehouse/hour (when needed)

Annual TCO: ~$200-300/year for 100GB
Value: Priceless data protection
```

---

## ✅ Testing & Validation

### Test 1: Verify Backups Are Created

```sql
SELECT 
    backup_name,
    backup_set_name,
    backup_start_time,
    state
FROM INFORMATION_SCHEMA.BACKUPS
WHERE backup_set_name = 'healthcare_backup_set'
ORDER BY backup_start_time DESC;
```

### Test 2: Verify Retention Lock

```sql
-- Try to delete a locked backup (should fail)
DROP BACKUP healthcare_backup_set.BACKUP_20260104_060000;
-- Expected: Error - Cannot drop backup with retention lock
```

### Test 3: Point-in-Time Recovery

```sql
-- Restore table from backup
CREATE TABLE patient_data.patients_restored 
AS SELECT * FROM healthcare_backup_set.BACKUP_20260104_060000.patient_data.patients;

-- Verify data
SELECT COUNT(*) FROM patient_data.patients_restored;
```

---

## 🛡️ Best Practices

### 1. Retention Lock Strategy

✅ **DO**: Test thoroughly in development first  
✅ **DO**: Document retention period decision  
✅ **DO**: Align retention with regulatory requirements  
❌ **DON'T**: Apply retention lock without approval  
❌ **DON'T**: Use production data for testing

### 2. Backup Schedule

```sql
-- For critical systems:
SCHEDULE = 'USING CRON 0 */4 * * * UTC'  -- Every 4 hours

-- For standard systems:
SCHEDULE = 'USING CRON 0 */6 * * * UTC'  -- Every 6 hours

-- For archival:
SCHEDULE = 'USING CRON 0 0 * * * UTC'    -- Daily
```

### 3. Cost Optimization

- Use **incremental backups** (Snowflake default)
- Set appropriate **retention periods**
- Monitor **backup storage growth**
- Archive old backups to cheaper storage

### 4. Security

- Limit `retention_lock_admin` role to 2-3 people
- Require multi-factor authentication
- Log all backup operations
- Review access quarterly

---

## 🔧 Troubleshooting

### Issue: "BACKUP feature not available"

**Solution**: Verify you're on Business Critical edition or higher.

```sql
SELECT CURRENT_ACCOUNT() AS account_name;
SHOW PARAMETERS LIKE 'EDITION' IN ACCOUNT;
```

### Issue: "Cannot drop backup - retention lock active"

**Expected Behavior**: This proves the system is working! Retention lock prevents deletion.

### Issue: Backups not being created

**Diagnosis**:
```sql
-- Check backup policy status
SHOW BACKUP POLICIES;

-- Check for errors
SELECT * FROM healthcare_prod.compliance.account_audit_events
WHERE object_type = 'BACKUP_POLICY'
ORDER BY timestamp DESC LIMIT 10;
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

### Areas for Contribution:

- Additional compliance mappings (SOX, GDPR, etc.)
- More healthcare data examples
- Recovery automation scripts
- Terraform/Infrastructure-as-Code
- Monitoring dashboards

---

## 📚 Resources

### Snowflake Documentation

- [WORM Backups Official Docs](https://docs.snowflake.com/en/user-guide/backups)
- [Retention Lock Guide](https://docs.snowflake.com/en/user-guide/backups-retention-lock)
- [Disaster Recovery Best Practices](https://docs.snowflake.com/en/user-guide/disaster-recovery)

### Compliance Resources

- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/)
- [SEC 17a-4(f) Requirements](https://www.sec.gov/rules/interp/34-47806.htm)
- [21 CFR Part 11 (FDA)](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/part-11-electronic-records-electronic-signatures-scope-and-application)

### Related Articles

- [Medium: Building Ransomware-Resistant Backups](#) (Coming Soon)
- [Blog: HIPAA Compliance in Snowflake](#) (Coming Soon)

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⭐ Star This Repository

If this project helped you, please ⭐ star this repository!

---

## 📧 Contact

**Author**: i3xpl0it  
**GitHub**: [@i3xpl0it](https://github.com/i3xpl0it)  
**Project**: [snowflake-worm-healthcare-compliance](https://github.com/i3xpl0it/snowflake-worm-healthcare-compliance)

---

## 🕐 Project Timeline

**Created**: January 4, 2026  
**Last Updated**: January 4, 2026  
**Status**: Active Development  
**Snowflake Version**: 9.39+ (WORM Backups GA)

---

**⚠️ DISCLAIMER**: This project is for educational and demonstration purposes. Always test thoroughly in a non-production environment before implementing in production. Consult with your compliance and security teams.

---

*Made with ❤️ for the Snowflake community*
| Requirement | Details |
|-------------|
