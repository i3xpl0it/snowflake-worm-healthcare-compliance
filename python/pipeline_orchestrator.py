#!/usr/bin/env python3
"""
Snowflake Dual-Warehouse Clinical Data Pipeline Orchestrator

Purpose: Orchestrate the end-to-end clinical data pipeline
         from PostgreSQL CDC to Snowflake Analytics

Features:
- Dual-warehouse architecture management
- CDC stream monitoring
- Dynamic Table refresh coordination
- Cost optimization tracking
- HIPAA compliance logging
"""

import snowflake.connector
import os
import logging
from datetime import datetime
from typing import Dict, List, Optional
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SnowflakePipelineOrchestrator:
    """
    Main orchestrator for the Snowflake Clinical Data Pipeline
    """
    
    def __init__(self, config: Dict):
        """Initialize pipeline with configuration"""
        self.config = config
        self.conn = None
        self.cursor = None
        
    def connect(self):
        """Establish connection to Snowflake"""
        try:
            self.conn = snowflake.connector.connect(
                user=self.config['user'],
                password=self.config['password'],
                account=self.config['account'],
                warehouse=self.config['init_warehouse'],
                database=self.config['database'],
                schema=self.config['schema']
            )
            self.cursor = self.conn.cursor()
            logger.info("Successfully connected to Snowflake")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            return False
    
    def check_stream_status(self) -> List[Dict]:
        """Check status of all CDC streams"""
        query = """
        SELECT 
            stream_name,
            table_name,
            stale,
            stale_after
        FROM INFORMATION_SCHEMA.STREAMS
        WHERE schema_name = 'RAW_DATA'
        ORDER BY stream_name;
        """
        
        try:
            self.cursor.execute(query)
            streams = []
            for row in self.cursor:
                streams.append({
                    'stream_name': row[0],
                    'table_name': row[1],
                    'is_stale': row[2],
                    'stale_after': row[3]
                })
            logger.info(f"Found {len(streams)} active streams")
            return streams
        except Exception as e:
            logger.error(f"Error checking stream status: {e}")
            return []
    
    def get_stream_change_count(self, stream_name: str) -> int:
        """Get number of changes pending in a stream"""
        query = f"""
        SELECT COUNT(*) FROM RAW_DATA.{stream_name};
        """
        
        try:
            self.cursor.execute(query)
            count = self.cursor.fetchone()[0]
            logger.info(f"{stream_name} has {count} pending changes")
            return count
        except Exception as e:
            logger.error(f"Error getting change count for {stream_name}: {e}")
            return 0
    
    def refresh_dynamic_tables(self):
        """Trigger refresh of dynamic tables"""
        dynamic_tables = [
            'STAGING.DT_PATIENTS',
            'STAGING.DT_ENCOUNTERS',
            'STAGING.DT_PRESCRIPTIONS',
            'STAGING.DT_LAB_RESULTS',
            'STAGING.DT_VITAL_SIGNS',
            'STAGING.DT_PATIENT_SUMMARY'
        ]
        
        # Switch to CDC warehouse for processing
        self.cursor.execute(f"USE WAREHOUSE {self.config['cdc_warehouse']}")
        
        for table in dynamic_tables:
            try:
                # Dynamic tables refresh automatically based on TARGET_LAG
                # This query just checks their status
                query = f"""
                SELECT 
                    name,
                    target_lag,
                    refresh_mode,
                    last_refresh_time
                FROM INFORMATION_SCHEMA.DYNAMIC_TABLES
                WHERE name = '{table.split('.')[1]}'
                AND schema_name = '{table.split('.')[0]}';
                """
                self.cursor.execute(query)
                result = self.cursor.fetchone()
                if result:
                    logger.info(f"{table} - Last refresh: {result[3]}")
            except Exception as e:
                logger.error(f"Error checking {table}: {e}")
    
    def populate_analytics_tables(self):
        """Populate analytics tables from staging"""
        # Switch to Interactive warehouse for analytics
        self.cursor.execute(f"USE WAREHOUSE {self.config['interactive_warehouse']}")
        
        analytics_queries = [
            "TRUNCATE TABLE ANALYTICS.PATIENTS_FACT",
            """INSERT INTO ANALYTICS.PATIENTS_FACT
               SELECT * FROM STAGING.DT_PATIENTS
               WHERE _cdc_operation != 'DELETE'""",
            
            "TRUNCATE TABLE ANALYTICS.ENCOUNTERS_FACT",
            """INSERT INTO ANALYTICS.ENCOUNTERS_FACT
               SELECT * FROM STAGING.DT_ENCOUNTERS 
               WHERE _cdc_operation != 'DELETE'""",
            
            "TRUNCATE TABLE ANALYTICS.PRESCRIPTIONS_FACT",
            """INSERT INTO ANALYTICS.PRESCRIPTIONS_FACT
               SELECT * FROM STAGING.DT_PRESCRIPTIONS
               WHERE _cdc_operation != 'DELETE'""",
            
            "TRUNCATE TABLE ANALYTICS.LAB_RESULTS_FACT",
            """INSERT INTO ANALYTICS.LAB_RESULTS_FACT
               SELECT * FROM STAGING.DT_LAB_RESULTS
               WHERE _cdc_operation != 'DELETE'""",
            
            "TRUNCATE TABLE ANALYTICS.VITAL_SIGNS_FACT",
            """INSERT INTO ANALYTICS.VITAL_SIGNS_FACT
               SELECT * FROM STAGING.DT_VITAL_SIGNS
               WHERE _cdc_operation != 'DELETE'"""
        ]
        
        for query in analytics_queries:
            try:
                self.cursor.execute(query)
                logger.info(f"Executed: {query[:50]}...")
            except Exception as e:
                logger.error(f"Error executing analytics query: {e}")
    
    def get_warehouse_costs(self) -> Dict:
        """Get cost information for warehouses"""
        query = """
        SELECT 
            warehouse_name,
            SUM(credits_used) as total_credits,
            COUNT(*) as query_count
        FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
        WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
        AND warehouse_name IN ('CLINICAL_INIT_WH', 'CLINICAL_CDC_WH', 'CLINICAL_INTERACTIVE_WH')
        GROUP BY warehouse_name;
        """
        
        try:
            self.cursor.execute(query)
            costs = {}
            for row in self.cursor:
                costs[row[0]] = {
                    'credits': float(row[1]),
                    'queries': int(row[2])
                }
            logger.info(f"Warehouse costs: {costs}")
            return costs
        except Exception as e:
            logger.error(f"Error getting warehouse costs: {e}")
            return {}
    
    def log_audit_entry(self, event_type: str, details: str):
        """Log pipeline execution to audit table"""
        query = """
        INSERT INTO AUDIT.ACCESS_LOG (
            user_name, role_name, query_text, 
            database_name, schema_name, execution_status
        )
        VALUES (
            CURRENT_USER(), CURRENT_ROLE(), %s,
            'CLINICAL_DATA_PIPELINE', 'PIPELINE', 'SUCCESS'
        );
        """
        
        try:
            self.cursor.execute(query, (f"{event_type}: {details}",))
            logger.info(f"Logged audit entry: {event_type}")
        except Exception as e:
            logger.error(f"Error logging audit entry: {e}")
    
    def run_pipeline(self):
        """Execute the full pipeline orchestration"""
        logger.info("Starting pipeline orchestration...")
        start_time = datetime.now()
        
        try:
            # 1. Check stream status
            streams = self.check_stream_status()
            self.log_audit_entry('STREAM_CHECK', f"Checked {len(streams)} streams")
            
            # 2. Get change counts
            total_changes = 0
            for stream in streams:
                changes = self.get_stream_change_count(stream['stream_name'])
                total_changes += changes
            
            logger.info(f"Total pending changes: {total_changes}")
            
            # 3. Refresh dynamic tables (they auto-refresh, we just monitor)
            self.refresh_dynamic_tables()
            self.log_audit_entry('DYNAMIC_TABLES', 'Checked dynamic table status')
            
            # 4. Populate analytics tables
            if total_changes > 0:
                self.populate_analytics_tables()
                self.log_audit_entry('ANALYTICS_REFRESH', f'Processed {total_changes} changes')
            
            # 5. Get cost metrics
            costs = self.get_warehouse_costs()
            self.log_audit_entry('COST_TRACKING', f'Weekly costs: {json.dumps(costs)}')
            
            # 6. Log completion
            duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"Pipeline completed successfully in {duration:.2f} seconds")
            self.log_audit_entry('PIPELINE_COMPLETE', f'Duration: {duration:.2f}s')
            
            return True
            
        except Exception as e:
            logger.error(f"Pipeline execution failed: {e}")
            self.log_audit_entry('PIPELINE_ERROR', str(e))
            return False
    
    def close(self):
        """Close Snowflake connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        logger.info("Closed Snowflake connection")


def main():
    """Main entry point"""
    
    # Configuration (in production, use environment variables or secrets manager)
    config = {
        'user': os.getenv('SNOWFLAKE_USER'),
        'password': os.getenv('SNOWFLAKE_PASSWORD'),
        'account': os.getenv('SNOWFLAKE_ACCOUNT'),
        'database': 'CLINICAL_DATA_PIPELINE',
        'schema': 'RAW_DATA',
        'init_warehouse': 'CLINICAL_INIT_WH',
        'cdc_warehouse': 'CLINICAL_CDC_WH',
        'interactive_warehouse': 'CLINICAL_INTERACTIVE_WH'
    }
    
    # Initialize and run pipeline
    orchestrator = SnowflakePipelineOrchestrator(config)
    
    if orchestrator.connect():
        success = orchestrator.run_pipeline()
        orchestrator.close()
        
        exit(0 if success else 1)
    else:
        logger.error("Failed to establish Snowflake connection")
        exit(1)


if __name__ == '__main__':
    main()
