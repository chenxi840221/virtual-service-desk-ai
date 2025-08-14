-- Unity Catalog Table Creation Script for DXC Virtual Service Desk AI
-- Run this script after setting up Unity Catalog to create required tables

-- Use the appropriate catalog and schema
USE CATALOG dxc_servicedesk_${environment};
USE SCHEMA raw_data;

-- Create service tickets table
CREATE TABLE IF NOT EXISTS service_tickets (
    ticket_id STRING NOT NULL,
    subject STRING NOT NULL,
    description STRING NOT NULL,
    priority STRING NOT NULL,
    category STRING NOT NULL,
    status STRING NOT NULL,
    employee_id STRING,
    department STRING,
    location STRING,
    created_date TIMESTAMP NOT NULL,
    resolved_date TIMESTAMP,
    assigned_agent STRING,
    sentiment_score DOUBLE,
    tags ARRAY<STRING>,
    metadata MAP<STRING, STRING>,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) 
USING DELTA
PARTITIONED BY (DATE(created_date), category)
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.feature.allowColumnDefaults' = 'supported'
)
COMMENT 'Service desk tickets with metadata and classification';

-- Create ticket comments table
CREATE TABLE IF NOT EXISTS ticket_comments (
    comment_id STRING NOT NULL,
    ticket_id STRING NOT NULL,
    content STRING NOT NULL,
    author STRING NOT NULL,
    comment_type STRING NOT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    metadata MAP<STRING, STRING>
)
USING DELTA
PARTITIONED BY (DATE(created_at))
COMMENT 'Comments and interactions on service tickets';

-- Create AI analysis results table
CREATE TABLE IF NOT EXISTS ai_analysis_results (
    analysis_id STRING NOT NULL,
    ticket_id STRING NOT NULL,
    intent STRING,
    confidence DOUBLE,
    suggested_category STRING,
    suggested_priority STRING,
    suggested_resolution STRING,
    requires_escalation BOOLEAN,
    extracted_entities ARRAY<STRING>,
    sentiment_score DOUBLE,
    language_detected STRING,
    model_version STRING,
    analysis_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    metadata MAP<STRING, STRING>
)
USING DELTA
PARTITIONED BY (DATE(analysis_timestamp))
COMMENT 'AI analysis results for service desk tickets';

-- Switch to processed_data schema
USE SCHEMA processed_data;

-- Create feature store table for ML training
CREATE TABLE IF NOT EXISTS ticket_features (
    ticket_id STRING NOT NULL,
    subject_length INT,
    description_length INT,
    subject_embedding ARRAY<DOUBLE>,
    description_embedding ARRAY<DOUBLE>,
    priority_encoded INT,
    category_encoded INT,
    department_encoded INT,
    location_encoded INT,
    hour_of_day INT,
    day_of_week INT,
    month INT,
    is_weekend BOOLEAN,
    sentiment_score DOUBLE,
    urgency_keywords_count INT,
    technical_keywords_count INT,
    business_keywords_count INT,
    created_date DATE,
    feature_version STRING DEFAULT 'v1.0',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
PARTITIONED BY (created_date)
COMMENT 'Engineered features for ML model training';

-- Create training labels table
CREATE TABLE IF NOT EXISTS training_labels (
    ticket_id STRING NOT NULL,
    actual_category STRING NOT NULL,
    actual_priority STRING NOT NULL,
    actual_resolution_time_hours DOUBLE,
    was_escalated BOOLEAN,
    customer_satisfaction_score DOUBLE,
    resolution_quality_score DOUBLE,
    labeled_by STRING,
    labeled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    quality_assured BOOLEAN DEFAULT FALSE
)
USING DELTA
COMMENT 'Ground truth labels for supervised learning';

-- Switch to models schema
USE SCHEMA models;

-- Create model registry table
CREATE TABLE IF NOT EXISTS model_registry (
    model_id STRING NOT NULL,
    model_name STRING NOT NULL,
    model_version STRING NOT NULL,
    model_type STRING NOT NULL,
    framework STRING NOT NULL,
    model_path STRING NOT NULL,
    accuracy_score DOUBLE,
    precision_score DOUBLE,
    recall_score DOUBLE,
    f1_score DOUBLE,
    training_data_version STRING,
    hyperparameters MAP<STRING, STRING>,
    training_duration_minutes DOUBLE,
    trained_by STRING,
    training_date TIMESTAMP,
    status STRING DEFAULT 'TRAINING',
    deployed_at TIMESTAMP,
    deployment_environment STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
COMMENT 'ML model registry with metadata and performance metrics';

-- Create model predictions table
CREATE TABLE IF NOT EXISTS model_predictions (
    prediction_id STRING NOT NULL,
    model_id STRING NOT NULL,
    ticket_id STRING NOT NULL,
    predicted_category STRING,
    predicted_priority STRING,
    confidence_score DOUBLE,
    prediction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    actual_category STRING,
    actual_priority STRING,
    prediction_correct BOOLEAN,
    feedback_score DOUBLE,
    model_version STRING
)
USING DELTA
PARTITIONED BY (DATE(prediction_timestamp))
COMMENT 'Model predictions with actual outcomes for monitoring';

-- Switch to policies schema  
USE SCHEMA policies;

-- Create policies knowledge base table
CREATE TABLE IF NOT EXISTS policy_documents (
    document_id STRING NOT NULL,
    title STRING NOT NULL,
    category STRING NOT NULL,
    classification STRING NOT NULL,
    content_sections ARRAY<STRUCT<
        section_id: STRING,
        title: STRING, 
        content: STRING,
        keywords: ARRAY<STRING>,
        embedding_vector: ARRAY<DOUBLE>
    >>,
    approval_workflow STRUCT<
        approver: STRING,
        effective_date: DATE,
        review_date: DATE
    >,
    applicable_regions ARRAY<STRING>,
    compliance_frameworks ARRAY<STRING>,
    version STRING,
    status STRING DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
COMMENT 'Company policies and procedures for knowledge base';

-- Create knowledge base embeddings table
CREATE TABLE IF NOT EXISTS knowledge_embeddings (
    embedding_id STRING NOT NULL,
    document_id STRING NOT NULL,
    section_id STRING,
    content_chunk STRING NOT NULL,
    embedding_vector ARRAY<DOUBLE> NOT NULL,
    chunk_metadata MAP<STRING, STRING>,
    embedding_model STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
COMMENT 'Vector embeddings for semantic search and RAG';

-- Switch to analytics schema
USE SCHEMA analytics;

-- Create analytics summary table
CREATE TABLE IF NOT EXISTS ticket_analytics (
    analysis_date DATE NOT NULL,
    category STRING,
    priority STRING,
    department STRING,
    location STRING,
    total_tickets INT,
    resolved_tickets INT,
    avg_resolution_time_hours DOUBLE,
    avg_sentiment_score DOUBLE,
    escalation_rate DOUBLE,
    ai_accuracy_rate DOUBLE,
    customer_satisfaction_avg DOUBLE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
PARTITIONED BY (analysis_date)
COMMENT 'Daily analytics aggregations for reporting and monitoring';

-- Create performance monitoring table
CREATE TABLE IF NOT EXISTS model_performance_metrics (
    metric_date DATE NOT NULL,
    model_name STRING NOT NULL,
    model_version STRING NOT NULL,
    metric_name STRING NOT NULL,
    metric_value DOUBLE NOT NULL,
    environment STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
PARTITIONED BY (metric_date)
COMMENT 'Model performance metrics over time for monitoring';

-- Create data quality monitoring table
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    check_date DATE NOT NULL,
    table_name STRING NOT NULL,
    column_name STRING,
    metric_type STRING NOT NULL,
    metric_value DOUBLE,
    threshold_value DOUBLE,
    status STRING,
    details STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
PARTITIONED BY (check_date)
COMMENT 'Data quality monitoring and validation results';

-- Grant appropriate permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA raw_data TO `data-engineers`;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA processed_data TO `data-scientists`;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA models TO `ml-engineers`;
GRANT SELECT ON SCHEMA policies TO `service-desk-agents`;
GRANT SELECT ON SCHEMA analytics TO `business-analysts`;

-- Create views for common queries
CREATE OR REPLACE VIEW ticket_summary AS
SELECT 
    DATE(created_date) as ticket_date,
    category,
    priority,
    COUNT(*) as total_tickets,
    COUNT(CASE WHEN status = 'Resolved' THEN 1 END) as resolved_tickets,
    AVG(sentiment_score) as avg_sentiment,
    AVG(CASE WHEN resolved_date IS NOT NULL 
        THEN TIMESTAMPDIFF(HOUR, created_date, resolved_date) 
        END) as avg_resolution_hours
FROM raw_data.service_tickets
WHERE created_date >= CURRENT_DATE() - INTERVAL 30 DAYS
GROUP BY DATE(created_date), category, priority
ORDER BY ticket_date DESC;

CREATE OR REPLACE VIEW ai_performance_summary AS
SELECT 
    DATE(analysis_timestamp) as analysis_date,
    COUNT(*) as total_analyses,
    AVG(confidence) as avg_confidence,
    COUNT(CASE WHEN requires_escalation THEN 1 END) as escalations_predicted,
    model_version
FROM raw_data.ai_analysis_results
WHERE analysis_timestamp >= CURRENT_DATE() - INTERVAL 7 DAYS
GROUP BY DATE(analysis_timestamp), model_version
ORDER BY analysis_date DESC;

COMMENT 'Schema and table creation complete for DXC Virtual Service Desk AI';