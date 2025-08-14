# Databricks notebook source
# MAGIC %md
# MAGIC # Service Desk Ticket Analysis
# MAGIC
# MAGIC This notebook provides AI-powered analysis of service desk tickets including:
# MAGIC - Intent recognition
# MAGIC - Sentiment analysis  
# MAGIC - Category classification
# MAGIC - Resolution suggestion
# MAGIC - Escalation prediction

# COMMAND ----------

import pandas as pd
import numpy as np
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.ml.feature import VectorAssembler, StringIndexer, CountVectorizer
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
import openai
import json

# COMMAND ----------

# MAGIC %md
# MAGIC ## Initialize Spark Session and Configuration

# COMMAND ----------

spark = SparkSession.builder \
    .appName("DXC Service Desk AI") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .getOrCreate()

# Unity Catalog configuration
catalog_name = dbutils.widgets.get("catalog_name") if dbutils.widgets.get("catalog_name") else "dxc_service_desk"
schema_name = dbutils.widgets.get("schema_name") if dbutils.widgets.get("schema_name") else "ai_models"

print(f"Using catalog: {catalog_name}, schema: {schema_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Loading and Preprocessing

# COMMAND ----------

def load_ticket_data():
    """Load service desk tickets from Unity Catalog"""
    try:
        tickets_df = spark.table(f"{catalog_name}.{schema_name}.service_tickets")
        return tickets_df
    except Exception as e:
        print(f"Error loading ticket data: {e}")
        # Create sample data for demo
        sample_data = [
            ("TICK-001", "Password reset request", "Cannot access my email account", "Medium", "PasswordReset", "New"),
            ("TICK-002", "Software installation", "Need Visual Studio installed", "Low", "SoftwareRequest", "New"),
            ("TICK-003", "Network access issue", "Cannot connect to VPN", "High", "NetworkAccess", "InProgress"),
            ("TICK-004", "System crash", "Blue screen error on startup", "Critical", "HardwareIssue", "Escalated")
        ]
        schema = ["ticket_id", "subject", "description", "priority", "category", "status"]
        return spark.createDataFrame(sample_data, schema)

tickets_df = load_ticket_data()
tickets_df.show(truncate=False)

# COMMAND ----------

# MAGIC %md 
# MAGIC ## AI Analysis Functions

# COMMAND ----------

def analyze_ticket_intent(subject, description):
    """Analyze ticket intent using AI"""
    combined_text = f"{subject} {description}".lower()
    
    # Simple rule-based intent classification
    if any(word in combined_text for word in ["password", "reset", "login", "access", "account"]):
        return "account_access"
    elif any(word in combined_text for word in ["install", "software", "application", "program"]):
        return "software_request"
    elif any(word in combined_text for word in ["network", "vpn", "connection", "internet"]):
        return "network_issue"
    elif any(word in combined_text for word in ["hardware", "crash", "blue screen", "freeze"]):
        return "hardware_issue"
    else:
        return "general_inquiry"

def calculate_sentiment_score(text):
    """Calculate sentiment score (simplified)"""
    negative_words = ["urgent", "critical", "broken", "failed", "error", "problem", "issue"]
    positive_words = ["please", "thank", "help", "support"]
    
    text_lower = text.lower()
    negative_count = sum(1 for word in negative_words if word in text_lower)
    positive_count = sum(1 for word in positive_words if word in text_lower)
    
    # Normalize to 0-1 scale (0.5 is neutral)
    if negative_count > positive_count:
        return max(0.1, 0.5 - (negative_count * 0.1))
    elif positive_count > negative_count:
        return min(0.9, 0.5 + (positive_count * 0.1))
    else:
        return 0.5

def suggest_resolution(category, description):
    """Suggest resolution based on category and description"""
    resolutions = {
        "PasswordReset": "1. Reset password via self-service portal\n2. Contact IT helpdesk if portal unavailable\n3. Verify identity before reset",
        "SoftwareRequest": "1. Check software catalog for approved applications\n2. Submit software request form\n3. Verify business justification\n4. Await approval",
        "NetworkAccess": "1. Check network cable connections\n2. Restart network adapter\n3. Verify VPN settings\n4. Contact network team if issue persists",
        "HardwareIssue": "1. Check hardware connections\n2. Run diagnostic tests\n3. Update drivers\n4. Contact hardware support if needed",
        "General": "1. Gather additional information\n2. Check knowledge base\n3. Escalate to appropriate team"
    }
    return resolutions.get(category, resolutions["General"])

def predict_escalation_required(priority, sentiment_score, category):
    """Predict if ticket requires escalation"""
    escalation_score = 0
    
    # Priority contribution
    priority_scores = {"Critical": 0.8, "High": 0.6, "Medium": 0.3, "Low": 0.1}
    escalation_score += priority_scores.get(priority, 0.3)
    
    # Sentiment contribution (lower sentiment = higher escalation risk)
    escalation_score += (1 - sentiment_score) * 0.3
    
    # Category contribution
    critical_categories = ["HardwareIssue", "Security"]
    if category in critical_categories:
        escalation_score += 0.2
    
    return escalation_score > 0.6

# Register UDFs for Spark
analyze_intent_udf = udf(analyze_ticket_intent)
sentiment_score_udf = udf(calculate_sentiment_score)
suggest_resolution_udf = udf(suggest_resolution)
predict_escalation_udf = udf(predict_escalation_required)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Apply AI Analysis to Tickets

# COMMAND ----------

# Apply AI analysis
analyzed_tickets = tickets_df \
    .withColumn("intent", analyze_intent_udf(col("subject"), col("description"))) \
    .withColumn("sentiment_score", sentiment_score_udf(col("description"))) \
    .withColumn("suggested_resolution", suggest_resolution_udf(col("category"), col("description"))) \
    .withColumn("requires_escalation", predict_escalation_udf(col("priority"), col("sentiment_score"), col("category"))) \
    .withColumn("analysis_timestamp", current_timestamp())

analyzed_tickets.show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Save Results to Unity Catalog

# COMMAND ----------

# Save analyzed tickets back to Unity Catalog
try:
    analyzed_tickets.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(f"{catalog_name}.{schema_name}.analyzed_tickets")
    
    print(f"Results saved to {catalog_name}.{schema_name}.analyzed_tickets")
except Exception as e:
    print(f"Error saving results: {e}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Analysis Summary

# COMMAND ----------

# Generate summary statistics
summary_stats = analyzed_tickets.groupBy("category", "intent", "requires_escalation") \
    .agg(
        count("*").alias("ticket_count"),
        avg("sentiment_score").alias("avg_sentiment"),
        collect_list("ticket_id").alias("ticket_ids")
    ) \
    .orderBy("category", "intent")

summary_stats.show(truncate=False)

# Save summary
summary_stats.write \
    .mode("overwrite") \
    .saveAsTable(f"{catalog_name}.{schema_name}.analysis_summary")

print("Analysis complete!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## API Endpoint Functions (for C# integration)

# COMMAND ----------

def analyze_single_ticket(ticket_data):
    """
    Analyze a single ticket (called via REST API from C# application)
    Expected input: JSON with ticket_id, subject, description, priority, category
    """
    try:
        ticket_id = ticket_data.get('ticket_id')
        subject = ticket_data.get('subject', '')
        description = ticket_data.get('description', '')
        priority = ticket_data.get('priority', 'Medium')
        category = ticket_data.get('category', 'General')
        
        # Perform analysis
        intent = analyze_ticket_intent(subject, description)
        sentiment = calculate_sentiment_score(description)
        resolution = suggest_resolution(category, description)
        escalation = predict_escalation_required(priority, sentiment, category)
        
        # Return analysis result
        return {
            "ticket_id": ticket_id,
            "intent": intent,
            "confidence": 0.85,  # Mock confidence score
            "sentiment_score": sentiment,
            "suggested_resolution": resolution,
            "requires_escalation": escalation,
            "analysis_timestamp": str(pd.Timestamp.now()),
            "model_version": "v1.0"
        }
    except Exception as e:
        return {"error": str(e)}

# Example usage
sample_ticket = {
    "ticket_id": "TICK-999",
    "subject": "Urgent password reset needed",
    "description": "I cannot access my account and have an important meeting in 30 minutes. Please help immediately!",
    "priority": "High",
    "category": "PasswordReset"
}

result = analyze_single_ticket(sample_ticket)
print(json.dumps(result, indent=2))