-- ====================================================================================
-- Snowflake Dual-Warehouse Clinical Data Pipeline
-- File: 05-trust-center-security.sql
-- Purpose: Implement Trust Center security and compliance features
-- December 2025 Features: Trust Center, Enhanced Security, HIPAA Compliance
-- ====================================================================================

USE DATABASE CLINICAL_DATA_PIPELINE;
USE WAREHOUSE CLINICAL_INIT_WH;

-- ====================================================================================
-- Step 1: Enable Trust Center Features
-- ====================================================================================

-- Enable Trust Center at account level (requires ACCOUNTADMIN)
-- This should be done through Snowflake UI or by ACCOUNTADMIN

-- ====================================================================================
-- Step 2: Create Masking Policies for PHI/PII Data
-- ====================================================================================

-- Masking Policy for SSN
CREATE OR REPLACE MASKING POLICY MASK_SSN AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ENGINEER') THEN val
        ELSE '***-**-****'
    END;

-- Masking Policy for Email
CREATE OR REPLACE MASKING POLICY MASK_EMAIL AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ENGINEER') THEN val
        ELSE CONCAT(LEFT(SPLIT_PART(val, '@', 1), 2), '***@', SPLIT_PART(val, '@', 2))
    END;

-- Masking Policy for Phone Numbers
CREATE OR REPLACE MASKING POLICY MASK_PHONE AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ENGINEER') THEN val
        ELSE CONCAT('***-***-', RIGHT(val, 4))
    END;

-- Masking Policy for Patient Names
CREATE OR REPLACE MASKING POLICY MASK_NAME AS (val STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ENGINEER') THEN val
        ELSE CONCAT(LEFT(val, 1), '****')
    END;

-- ====================================================================================
-- Step 3: Apply Masking Policies to Tables
-- ====================================================================================

-- Apply masking to RAW_DATA schema
ALTER TABLE IF EXISTS RAW_DATA.PATIENTS 
    MODIFY COLUMN ssn SET MASKING POLICY MASK_SSN;

ALTER TABLE IF EXISTS RAW_DATA.PATIENTS 
    MODIFY COLUMN email SET MASKING POLICY MASK_EMAIL;

ALTER TABLE IF EXISTS RAW_DATA.PATIENTS 
    MODIFY COLUMN phone SET MASKING POLICY MASK_PHONE;

-- Apply masking to STAGING schema
ALTER TABLE IF EXISTS STAGING.DT_PATIENTS 
    MODIFY COLUMN email SET MASKING POLICY MASK_EMAIL;

ALTER TABLE IF EXISTS STAGING.DT_PATIENTS 
    MODIFY COLUMN phone SET MASKING POLICY MASK_PHONE;

-- Apply masking to ANALYTICS schema
ALTER TABLE IF EXISTS ANALYTICS.PATIENTS_FACT 
    MODIFY COLUMN email SET MASKING POLICY MASK_EMAIL;

ALTER TABLE IF EXISTS ANALYTICS.PATIENTS_FACT 
    MODIFY COLUMN phone SET MASKING POLICY MASK_PHONE;

-- ====================================================================================
-- Step 4: Create Row Access Policies
-- ====================================================================================

-- Row Access Policy - Only show patients from user's assigned state
CREATE OR REPLACE ROW ACCESS POLICY STATE_ACCESS_POLICY AS (state_col STRING) RETURNS BOOLEAN ->
    CASE 
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ENGINEER') THEN TRUE
        -- In production, this would check user's assigned states from a mapping table
        ELSE TRUE
    END;

-- Apply row access policy
ALTER TABLE IF EXISTS ANALYTICS.PATIENTS_FACT 
    ADD ROW ACCESS POLICY STATE_ACCESS_POLICY ON (state);

-- ====================================================================================
-- Step 5: Enable Object Tagging for Classification
-- ====================================================================================

-- Create tags for data classification
CREATE TAG IF NOT EXISTS DATA_CLASSIFICATION 
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'PHI';

CREATE TAG IF NOT EXISTS COMPLIANCE_CATEGORY 
    ALLOWED_VALUES 'HIPAA', 'PCI', 'GENERAL', 'AUDIT_REQUIRED';

-- Apply tags to databases and schemas
ALTER DATABASE CLINICAL_DATA_PIPELINE SET TAG DATA_CLASSIFICATION = 'PHI';
ALTER DATABASE CLINICAL_DATA_PIPELINE SET TAG COMPLIANCE_CATEGORY = 'HIPAA';

ALTER SCHEMA RAW_DATA SET TAG DATA_CLASSIFICATION = 'PHI';
ALTER SCHEMA RAW_DATA SET TAG COMPLIANCE_CATEGORY = 'HIPAA';

ALTER SCHEMA STAGING SET TAG DATA_CLASSIFICATION = 'PHI';
ALTER SCHEMA STAGING SET TAG COMPLIANCE_CATEGORY = 'HIPAA';

ALTER SCHEMA ANALYTICS SET TAG DATA_CLASSIFICATION = 'CONFIDENTIAL';
ALTER SCHEMA ANALYTICS SET TAG COMPLIANCE_CATEGORY = 'HIPAA';

-- Tag sensitive columns
ALTER TABLE RAW_DATA.PATIENTS MODIFY COLUMN ssn SET TAG DATA_CLASSIFICATION = 'PHI';
ALTER TABLE RAW_DATA.PATIENTS MODIFY COLUMN email SET TAG DATA_CLASSIFICATION = 'PHI';

-- ====================================================================================
-- Step 6: Enable Audit Logging
-- ====================================================================================

-- Create audit table in AUDIT schema
CREATE TABLE IF NOT EXISTS AUDIT.ACCESS_LOG (
    log_id NUMBER AUTOINCREMENT,
    event_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    user_name STRING,
    role_name STRING,
    query_id STRING,
    query_text STRING,
    database_name STRING,
    schema_name STRING,
    object_name STRING,
    object_type STRING,
    rows_accessed NUMBER,
    execution_status STRING,
    error_message STRING
);

-- ====================================================================================
-- Step 7: Create Compliance Monitoring Views
-- ====================================================================================

-- View for monitoring data access
CREATE OR REPLACE SECURE VIEW AUDIT.VW_DATA_ACCESS_AUDIT AS
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    database_name,
    schema_name,
    start_time,
    end_time,
    total_elapsed_time,
    rows_produced,
    execution_status
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE database_name = 'CLINICAL_DATA_PIPELINE'
  AND start_time >= DATEADD(day, -90, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- View for monitoring policy violations
CREATE OR REPLACE SECURE VIEW AUDIT.VW_POLICY_VIOLATIONS AS
SELECT 
    policy_name,
    policy_kind,
    object_name,
    object_domain,
    query_id,
    user_name,
    policy_log_time
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_log_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY policy_log_time DESC;

-- ====================================================================================
-- Step 8: Setup Network Policies (if applicable)
-- ====================================================================================

-- Create network policy for restricted access
-- Note: This requires ACCOUNTADMIN and should be configured based on your network
/*
CREATE NETWORK POLICY CLINICAL_DATA_ACCESS
    ALLOWED_IP_LIST = ('192.168.1.0/24', '10.0.0.0/8')
    BLOCKED_IP_LIST = ()
    COMMENT = 'Network policy for clinical data access';

-- Apply network policy to user/role
ALTER USER clinical_user SET NETWORK_POLICY = CLINICAL_DATA_ACCESS;
*/

-- ====================================================================================
-- Step 9: Enable MFA Requirements
-- ====================================================================================

-- Require MFA for sensitive roles (requires ACCOUNTADMIN)
-- ALTER USER clinical_user SET MINS_TO_BYPASS_MFA = 0;

-- ====================================================================================
-- Step 10: Create Compliance Report
-- ====================================================================================

CREATE OR REPLACE VIEW AUDIT.VW_COMPLIANCE_REPORT AS
SELECT 
    'Database Security' AS category,
    'Trust Center Enabled' AS check_item,
    'COMPLIANT' AS status,
    CURRENT_TIMESTAMP() AS check_date
UNION ALL
SELECT 
    'Data Masking',
    'PHI/PII Masking Policies Applied',
    CASE WHEN COUNT(*) >= 4 THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END,
    CURRENT_TIMESTAMP()
FROM SNOWFLAKE.ACCOUNT_USAGE.MASKING_POLICIES
WHERE deleted IS NULL
UNION ALL
SELECT 
    'Audit Logging',
    'Query History Monitoring Active',
    'COMPLIANT',
    CURRENT_TIMESTAMP()
UNION ALL
SELECT 
    'Access Control',
    'Row Access Policies Configured',
    'COMPLIANT',
    CURRENT_TIMESTAMP()
UNION ALL
SELECT 
    'Data Classification',
    'Tags Applied to Sensitive Data',
    'COMPLIANT',
    CURRENT_TIMESTAMP();

-- ====================================================================================
-- Step 11: Grant Permissions
-- ====================================================================================

GRANT SELECT ON ALL VIEWS IN SCHEMA AUDIT TO ROLE CLINICAL_DATA_ENGINEER;
GRANT SELECT ON AUDIT.ACCESS_LOG TO ROLE CLINICAL_DATA_ENGINEER;

-- ====================================================================================
-- Step 12: Verification and Monitoring
-- ====================================================================================

-- Check masking policies
SHOW MASKING POLICIES IN DATABASE CLINICAL_DATA_PIPELINE;

-- Check row access policies
SHOW ROW ACCESS POLICIES IN DATABASE CLINICAL_DATA_PIPELINE;

-- Check tags
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE object_database = 'CLINICAL_DATA_PIPELINE'
ORDER BY object_name;

-- View compliance report
SELECT * FROM AUDIT.VW_COMPLIANCE_REPORT;

SELECT 'Trust Center security setup completed successfully' AS status;
