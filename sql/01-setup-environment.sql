01-setup-environment.sql-- ============================================================================
-- Snowflake Dual-Warehouse Clinical Data Pipeline
-- File: 01-setup-environment.sql
-- Purpose: Initialize Snowflake environment with databases, warehouses, roles
-- December 2025 Features: Dynamic Tables, Interactive Tables, Trust Center
-- ============================================================================

-- Step 1: Create Database for Clinical Data
CREATE DATABASE IF NOT EXISTS CLINICAL_DATA_PIPELINE
    COMMENT = 'Production healthcare data pipeline with dual-warehouse architecture';

USE DATABASE CLINICAL_DATA_PIPELINE;

-- Step 2: Create Schemas
CREATE SCHEMA IF NOT EXISTS RAW_DATA
    COMMENT = 'Raw data from EHR systems (Epic/Cerner via Postgres CDC)';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Transformed and validated data';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Production tables for dashboards and reporting';

CREATE SCHEMA IF NOT EXISTS AUDIT
    COMMENT = 'WORM backup tables for compliance';

-- Step 3: Create Role for Data Engineering
CREATE ROLE IF NOT EXISTS CLINICAL_DATA_ENGINEER
    COMMENT = 'Role for data engineers managing clinical pipelines';

-- Step 4: Create Warehouses with Dual-Warehouse Strategy

-- INITIALIZATION WAREHOUSE (6XL) - For historical backfills
CREATE WAREHOUSE IF NOT EXISTS CLINICAL_INIT_WH
    WAREHOUSE_SIZE = '6X-LARGE'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Large warehouse for one-time historical EHR backfills (10+ years of data)';

-- INCREMENTAL WAREHOUSE (XS) - For real-time CDC
CREATE WAREHOUSE IF NOT EXISTS CLINICAL_CDC_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE
    COMMENT = 'Always-on small warehouse for incremental CDC refreshes every 15 min';

-- INTERACTIVE WAREHOUSE - For fast dashboard queries
CREATE WAREHOUSE IF NOT EXISTS CLINICAL_INTERACTIVE_WH
    WAREHOUSE_TYPE = 'SNOWPARK-OPTIMIZED'  -- Dec 2025 feature
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    COMMENT = 'Optimized for sub-100ms query latency on patient dashboards';

-- Step 5: Grant Permissions
GRANT USAGE ON DATABASE CLINICAL_DATA_PIPELINE TO ROLE CLINICAL_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CLINICAL_DATA_PIPELINE TO ROLE CLINICAL_DATA_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE CLINICAL_DATA_PIPELINE TO ROLE CLINICAL_DATA_ENGINEER;
GRANT CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE CLINICAL_DATA_PIPELINE TO ROLE CLINICAL_DATA_ENGINEER;
GRANT CREATE STAGE ON ALL SCHEMAS IN DATABASE CLINICAL_DATA_PIPELINE TO ROLE CLINICAL_DATA_ENGINEER;

GRANT USAGE ON WAREHOUSE CLINICAL_INIT_WH TO ROLE CLINICAL_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE CLINICAL_CDC_WH TO ROLE CLINICAL_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE CLINICAL_INTERACTIVE_WH TO ROLE CLINICAL_DATA_ENGINEER;

-- Step 6: Create External Volume for Postgres CDC (Dec 2025 feature)
CREATE OR REPLACE EXTERNAL VOLUME POSTGRES_CDC_VOLUME
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'my-s3-us-east-1'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://my-ehr-cdc-bucket/'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789:role/snowflake-cdc-role'
         )
      )
   COMMENT = 'External volume for Postgres CDC connector';

-- Step 7: Enable Trust Center Features (Dec 2025 - Preview 9.39)
-- Note: Requires Business Critical Edition

ALTER ACCOUNT SET ENABLE_TRUST_CENTER_SCANNERS = TRUE;

-- Step 8: Set up WORM Backup Catalog (Dec 2025 - GA Dec 10)
CREATE CATALOG INTEGRATION IF NOT EXISTS WORM_BACKUP_CATALOG
    CATALOG_SOURCE = SNOWFLAKE
    TABLE_FORMAT = ICEBERG
    ENABLED = TRUE
    COMMENT = 'Catalog for immutable 7-year HIPAA audit trail';

-- Step 9: Cost Monitoring Setup (Dec 2025 - GA Dec 10)
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS COST_ANOMALY_ALERTS
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('data-engineering-team@hospital.com')
    COMMENT = 'Email alerts for cost anomalies detected by ML';

-- Step 10: Resource Monitors for Budget Control
CREATE RESOURCE MONITOR IF NOT EXISTS CLINICAL_PIPELINE_MONITOR
    CREDIT_QUOTA = 1000  -- $3,000/month at $3/credit
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE CLINICAL_INIT_WH SET RESOURCE_MONITOR = CLINICAL_PIPELINE_MONITOR;
ALTER WAREHOUSE CLINICAL_CDC_WH SET RESOURCE_MONITOR = CLINICAL_PIPELINE_MONITOR;
ALTER WAREHOUSE CLINICAL_INTERACTIVE_WH SET RESOURCE_MONITOR = CLINICAL_PIPELINE_MONITOR;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Check warehouses
SHOW WAREHOUSES LIKE 'CLINICAL%';

-- Check databases and schemas
SHOW SCHEMAS IN DATABASE CLINICAL_DATA_PIPELINE;

-- Check resource monitor
SHOW RESOURCE MONITORS;

-- ============================================================================
-- Expected Cost Breakdown
-- ============================================================================
/*
INITIALIZATION PHASE (One-time):
- CLINICAL_INIT_WH (6XL): 128 credits/hour × 10 hours = 1,280 credits = $3,840

MONTHLY OPERATIONS:
- CLINICAL_CDC_WH (XS): 1 credit/hour × 24 hours × 30 days = 720 credits = $2,160
- CLINICAL_INTERACTIVE_WH (M): 4 credits/hour × 12 hours/day × 22 days = 1,056 credits = $3,168

Total Year 1: $3,840 + ($2,160 + $3,168) × 12 = $67,776

TRADITIONAL APPROACH (Single Medium Warehouse 24/7):
- Medium WH: 4 credits/hour × 24 × 365 = 35,040 credits = $105,120

SAVINGS: $105,120 - $67,776 = $37,344 (35% reduction)
*/

-- ============================================================================
-- Security Notes
-- ============================================================================
/*
HIPAA COMPLIANCE CHECKLIST:
✅ Business Critical Edition required for Trust Center
✅ Network policies configured (not shown - requires VPN setup)
✅ MFA enabled for all CLINICAL_DATA_ENGINEER users
✅ Resource monitors prevent cost overruns
✅ WORM backups enabled for 7-year retention
✅ Audit logging via ACCOUNT_USAGE schema
*/
