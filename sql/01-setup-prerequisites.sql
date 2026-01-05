/*******************************************************************************
 * Snowflake WORM Backups - Healthcare Compliance Project
 * File: 01-setup-prerequisites.sql
 * Phase: 1 - Setup & Prerequisites
 * 
 * Description:
 *   Creates the foundational architecture for HIPAA-compliant data protection
 *   - 4 specialized compliance roles
 *   - Healthcare production database
 *   - 3 organized schemas
 *   - Proper privilege separation
 *
 * Author: i3xpl0it
 * Created: January 4, 2026
 * Snowflake Version: 9.39+ (WORM Backups GA)
 * 
 * Prerequisites:
 *   - ACCOUNTADMIN role access
 *   - Business Critical edition or higher
 *   - WORM Backups feature enabled
 *
 * Estimated Runtime: 2-3 minutes
 ******************************************************************************/

-- Use ACCOUNTADMIN for initial setup
USE ROLE ACCOUNTADMIN;

-------------------------------------------------------------------------------
-- STEP 1: Create Custom Compliance Roles
-------------------------------------------------------------------------------

-- Role 1: Compliance Administrator (manages backup policies)
CREATE ROLE IF NOT EXISTS compliance_admin
    COMMENT = 'Role for managing backup policies and compliance configurations';

-- Role 2: Retention Lock Administrator (applies immutable locks - CRITICAL)
CREATE ROLE IF NOT EXISTS retention_lock_admin
    COMMENT = 'CRITICAL: Role with authority to apply irreversible retention locks';

-- Role 3: Compliance Viewer (read-only audit access)
CREATE ROLE IF NOT EXISTS compliance_viewer
    COMMENT = 'Read-only role for viewing backups and audit logs';

-- Role 4: Event Viewer (audit log access)
CREATE ROLE IF NOT EXISTS event_viewer
    COMMENT = 'Role for accessing event tables and audit trails';

-- Grant roles to ACCOUNTADMIN
GRANT ROLE compliance_admin TO ROLE ACCOUNTADMIN;
GRANT ROLE retention_lock_admin TO ROLE ACCOUNTADMIN;
GRANT ROLE compliance_viewer TO ROLE ACCOUNTADMIN;
GRANT ROLE event_viewer TO ROLE ACCOUNTADMIN;

-- Create role hierarchy
GRANT ROLE compliance_viewer TO ROLE compliance_admin;
GRANT ROLE event_viewer TO ROLE compliance_viewer;

SELECT 'Step 1 Complete: 4 compliance roles created' AS status;

-------------------------------------------------------------------------------
-- STEP 2: Create Healthcare Production Database
-------------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS healthcare_prod
    COMMENT = 'Production database for healthcare data with WORM backup protection';

USE DATABASE healthcare_prod;

SELECT 'Step 2 Complete: Database healthcare_prod created' AS status;

-------------------------------------------------------------------------------
-- STEP 3: Create Healthcare Schemas
-------------------------------------------------------------------------------

-- Schema 1: Patient Data (PHI/PII)
CREATE SCHEMA IF NOT EXISTS patient_data
    COMMENT = 'Contains patient demographics, PHI, and identifiers - HIPAA protected';

-- Schema 2: Clinical Data (Medical Records)
CREATE SCHEMA IF NOT EXISTS clinical_data
    COMMENT = 'Contains clinical encounters, lab results, and medical history';

-- Schema 3: Compliance & Audit (Event Tables)
CREATE SCHEMA IF NOT EXISTS compliance
    COMMENT = 'Contains event tables, audit logs, and compliance tracking';

SELECT 'Step 3 Complete: 3 schemas created' AS status;

-------------------------------------------------------------------------------
-- STEP 4: Grant Privileges to Compliance Roles
-------------------------------------------------------------------------------

-- compliance_admin privileges
GRANT USAGE ON DATABASE healthcare_prod TO ROLE compliance_admin;
GRANT USAGE ON ALL SCHEMAS IN DATABASE healthcare_prod TO ROLE compliance_admin;
GRANT CREATE SCHEMA ON DATABASE healthcare_prod TO ROLE compliance_admin;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE healthcare_prod TO ROLE compliance_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN DATABASE healthcare_prod TO ROLE compliance_admin;
GRANT CREATE BACKUP POLICY ON ACCOUNT TO ROLE compliance_admin;
GRANT APPLY BACKUP POLICY ON ACCOUNT TO ROLE compliance_admin;

-- retention_lock_admin privileges
GRANT USAGE ON DATABASE healthcare_prod TO ROLE retention_lock_admin;
GRANT APPLY BACKUP RETENTION LOCK ON ACCOUNT TO ROLE retention_lock_admin;

-- compliance_viewer privileges  
GRANT USAGE ON DATABASE healthcare_prod TO ROLE compliance_viewer;
GRANT USAGE ON ALL SCHEMAS IN DATABASE healthcare_prod TO ROLE compliance_viewer;
GRANT SELECT ON ALL TABLES IN DATABASE healthcare_prod TO ROLE compliance_viewer;

-- event_viewer privileges
GRANT USAGE ON DATABASE healthcare_prod TO ROLE event_viewer;
GRANT USAGE ON SCHEMA healthcare_prod.compliance TO ROLE event_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA healthcare_prod.compliance TO ROLE event_viewer;

SELECT 'Step 4 Complete: Privileges granted' AS status;

-------------------------------------------------------------------------------
-- STEP 5: Create Warehouse for Backup Operations
-------------------------------------------------------------------------------

CREATE WAREHOUSE IF NOT EXISTS compliance_wh
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for backup operations and compliance queries';

GRANT USAGE ON WAREHOUSE compliance_wh TO ROLE compliance_admin;
GRANT USAGE ON WAREHOUSE compliance_wh TO ROLE compliance_viewer;

SELECT 'Step 5 Complete: Compliance warehouse created' AS status;

-------------------------------------------------------------------------------
-- VERIFICATION QUERIES
-------------------------------------------------------------------------------

SHOW ROLES LIKE '%compliance%';
SHOW DATABASES LIKE 'healthcare_prod';
SHOW SCHEMAS IN DATABASE healthcare_prod;
SHOW WAREHOUSES LIKE 'compliance_wh';

-------------------------------------------------------------------------------
-- PHASE 1 SUMMARY
-------------------------------------------------------------------------------

SELECT '
╔════════════════════════════════════════════════════════════════╗
║                   PHASE 1 SETUP COMPLETE                       ║
╠════════════════════════════════════════════════════════════════╣
║  ✓ 4 Compliance Roles Created                                 ║
║  ✓ healthcare_prod Database Created                           ║  
║  ✓ 3 Schemas Created                                          ║
║  ✓ Privileges Configured                                       ║
║  ✓ Compliance Warehouse Created                               ║
╠════════════════════════════════════════════════════════════════╣
║  NEXT STEP: Run 02-healthcare-data.sql                        ║
╚════════════════════════════════════════════════════════════════╝
' AS phase_summary;
