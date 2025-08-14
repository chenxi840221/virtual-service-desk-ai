# Databricks Environment Setup Script for DXC Virtual Service Desk AI
# This script configures Databricks workspace with Unity Catalog and required resources

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabricksWorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

Write-Host "🧠 Setting up Databricks Environment for Virtual Service Desk AI" -ForegroundColor Green

# Install Databricks CLI
Write-Host "📦 Installing Databricks CLI..." -ForegroundColor Blue
if (-not (Get-Command databricks -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Databricks CLI..."
    if ($IsWindows) {
        # Windows installation
        Invoke-WebRequest -Uri "https://github.com/databricks/cli/releases/latest/download/databricks_cli_windows_amd64.zip" -OutFile "databricks.zip"
        Expand-Archive -Path "databricks.zip" -DestinationPath "C:\Program Files\Databricks"
        $env:PATH += ";C:\Program Files\Databricks"
    } else {
        # Linux/macOS installation
        curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
    }
}

# Get Databricks workspace details
$databricksWorkspace = az databricks workspace show --name $DatabricksWorkspaceName --resource-group $ResourceGroupName | ConvertFrom-Json
$workspaceUrl = $databricksWorkspace.workspaceUrl
$workspaceId = $databricksWorkspace.workspaceId

Write-Host "✅ Databricks Workspace URL: https://$workspaceUrl" -ForegroundColor Green

# Create Databricks configuration file
$databricksConfig = @"
# Databricks CLI configuration for $Environment environment
# Save this as ~/.databrickscfg or set environment variables

[DEFAULT]
host = https://$workspaceUrl
# Run 'databricks auth login' to set up authentication

[DEV]
host = https://$workspaceUrl
# Development environment configuration

[STAGING]  
host = https://$workspaceUrl
# Staging environment configuration

[PROD]
host = https://$workspaceUrl
# Production environment configuration
"@

$databricksConfig | Out-File -FilePath "databricks-config-$Environment.txt" -Encoding UTF8

# Create Unity Catalog setup script
$unityCatalogSetup = @"
# Unity Catalog Setup Commands
# Run these commands after authenticating with Databricks CLI

# 1. Create catalog for the project
databricks unity-catalog catalogs create --name dxc_servicedesk_$Environment --comment "DXC Virtual Service Desk AI - $Environment environment"

# 2. Create schemas for different data types
databricks unity-catalog schemas create --catalog-name dxc_servicedesk_$Environment --name raw_data --comment "Raw service desk data and synthetic datasets"
databricks unity-catalog schemas create --catalog-name dxc_servicedesk_$Environment --name processed_data --comment "Processed and cleaned data for ML training"
databricks unity-catalog schemas create --catalog-name dxc_servicedesk_$Environment --name models --comment "ML models and model artifacts"
databricks unity-catalog schemas create --catalog-name dxc_servicedesk_$Environment --name policies --comment "Company policies and knowledge base"
databricks unity-catalog schemas create --catalog-name dxc_servicedesk_$Environment --name analytics --comment "Analytics tables and dashboards"

# 3. Create external location for Azure Storage
databricks unity-catalog external-locations create \
  --name "dxc-servicedesk-storage-$Environment" \
  --url "abfss://raw-data@$StorageAccountName.dfs.core.windows.net/" \
  --credential-name "azure-storage-credential" \
  --comment "Azure Data Lake Storage for service desk data"

# 4. Create tables for different data entities
databricks sql-file --file-path ../databricks/sql/create_tables.sql
"@

$unityCatalogSetup | Out-File -FilePath "setup-unity-catalog.sh" -Encoding UTF8

# Create cluster configuration
$clusterConfig = @"
{
  "cluster_name": "dxc-servicedesk-ai-$Environment",
  "spark_version": "14.3.x-scala2.12",
  "node_type_id": "Standard_DS3_v2",
  "driver_node_type_id": "Standard_DS3_v2", 
  "num_workers": 2,
  "autotermination_minutes": 30,
  "spark_conf": {
    "spark.databricks.delta.preview.enabled": "true",
    "spark.sql.adaptive.enabled": "true",
    "spark.sql.adaptive.coalescePartitions.enabled": "true"
  },
  "azure_attributes": {
    "first_on_demand": 1,
    "availability": "ON_DEMAND_AZURE",
    "spot_bid_max_price": -1
  },
  "enable_elastic_disk": true,
  "disk_spec": {
    "disk_type": {
      "azure_disk_volume_type": "PREMIUM_LRS"
    },
    "disk_size": 64
  },
  "runtime_engine": "STANDARD",
  "enable_local_disk_encryption": false,
  "libraries": [
    {
      "pypi": {
        "package": "openai==1.12.0"
      }
    },
    {
      "pypi": {
        "package": "azure-ai-ml==1.12.1"
      }
    },
    {
      "pypi": {
        "package": "azure-storage-blob==12.19.0"
      }
    },
    {
      "pypi": {
        "package": "scikit-learn==1.4.0"
      }
    },
    {
      "pypi": {
        "package": "pandas==2.2.0"
      }
    },
    {
      "pypi": {
        "package": "numpy==1.26.4"
      }
    }
  ],
  "init_scripts": [
    {
      "workspace": {
        "destination": "/Shared/init-scripts/install-dependencies.sh"
      }
    }
  ]
}
"@

$clusterConfig | Out-File -FilePath "cluster-config-$Environment.json" -Encoding UTF8

# Create job configuration for ML pipeline
$jobConfig = @"
{
  "name": "dxc-servicedesk-ml-pipeline-$Environment",
  "email_notifications": {
    "on_failure": ["servicedesk-dev@dxc.com"],
    "on_success": ["servicedesk-dev@dxc.com"]
  },
  "timeout_seconds": 3600,
  "max_concurrent_runs": 1,
  "tasks": [
    {
      "task_key": "data-ingestion",
      "notebook_task": {
        "notebook_path": "/Workspace/Shared/notebooks/data_ingestion",
        "base_parameters": {
          "environment": "$Environment",
          "catalog": "dxc_servicedesk_$Environment"
        }
      },
      "existing_cluster_id": "{{ cluster_id }}",
      "timeout_seconds": 1800
    },
    {
      "task_key": "feature-engineering", 
      "depends_on": [{"task_key": "data-ingestion"}],
      "notebook_task": {
        "notebook_path": "/Workspace/Shared/notebooks/feature_engineering",
        "base_parameters": {
          "environment": "$Environment",
          "catalog": "dxc_servicedesk_$Environment"
        }
      },
      "existing_cluster_id": "{{ cluster_id }}",
      "timeout_seconds": 1800
    },
    {
      "task_key": "model-training",
      "depends_on": [{"task_key": "feature-engineering"}],
      "notebook_task": {
        "notebook_path": "/Workspace/Shared/notebooks/model_training",
        "base_parameters": {
          "environment": "$Environment",
          "catalog": "dxc_servicedesk_$Environment"
        }
      },
      "existing_cluster_id": "{{ cluster_id }}",
      "timeout_seconds": 2400
    },
    {
      "task_key": "model-evaluation",
      "depends_on": [{"task_key": "model-training"}],
      "notebook_task": {
        "notebook_path": "/Workspace/Shared/notebooks/model_evaluation",
        "base_parameters": {
          "environment": "$Environment",
          "catalog": "dxc_servicedesk_$Environment"
        }
      },
      "existing_cluster_id": "{{ cluster_id }}",
      "timeout_seconds": 1200
    }
  ],
  "schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "Australia/Sydney"
  }
}
"@

$jobConfig | Out-File -FilePath "ml-pipeline-job-$Environment.json" -Encoding UTF8

# Create Databricks Asset Bundle configuration
$assetBundleConfig = @"
bundle:
  name: dxc-servicedesk-ai-$Environment

include:
  - resources/*.yml

variables:
  catalog:
    description: Unity Catalog name
    default: dxc_servicedesk_$Environment
  
  schema:
    description: Schema name  
    default: models

  cluster_node_type:
    description: Cluster node type
    default: Standard_DS3_v2

  cluster_num_workers:
    description: Number of cluster workers
    default: 2

targets:
  $Environment:
    mode: development
    workspace:
      host: https://$workspaceUrl
    variables:
      catalog: dxc_servicedesk_$Environment
      
resources:
  clusters:
    dxc_ml_cluster:
      cluster_name: "dxc-servicedesk-ml-\${var.catalog}"
      spark_version: "14.3.x-scala2.12"
      node_type_id: "\${var.cluster_node_type}"
      num_workers: \${var.cluster_num_workers}
      autotermination_minutes: 30
      
  jobs:
    ml_pipeline:
      name: "DXC ServiceDesk ML Pipeline - \${var.catalog}"
      job_clusters:
        - job_cluster_key: "ml_cluster"
          new_cluster:
            spark_version: "14.3.x-scala2.12"
            node_type_id: "\${var.cluster_node_type}"
            num_workers: \${var.cluster_num_workers}
            
      tasks:
        - task_key: "ticket_analysis"
          notebook_task:
            notebook_path: "../../databricks/notebooks/ticket_analysis"
            base_parameters:
              catalog_name: "\${var.catalog}"
              schema_name: "\${var.schema}"
          job_cluster_key: "ml_cluster"
"@

$assetBundleConfig | Out-File -FilePath "../databricks/databricks-$Environment.yml" -Encoding UTF8

# Create workspace init script
$initScript = @"
#!/bin/bash
# Databricks cluster initialization script

# Install additional Python packages
pip install --upgrade pip
pip install azure-ai-ml==1.12.1
pip install azure-storage-blob==12.19.0  
pip install openai==1.12.0
pip install scikit-learn==1.4.0
pip install mlflow==2.10.0

# Configure MLflow tracking
export MLFLOW_TRACKING_URI="databricks"
export MLFLOW_EXPERIMENT_NAME="/Shared/Experiments/dxc-servicedesk-ai-$Environment"

# Create MLflow experiment
python -c "
import mlflow
try:
    mlflow.create_experiment('/Shared/Experiments/dxc-servicedesk-ai-$Environment')
    print('✅ MLflow experiment created')
except:
    print('ℹ️ MLflow experiment already exists')
"

echo "✅ Cluster initialization complete"
"@

$initScript | Out-File -FilePath "cluster-init-script.sh" -Encoding UTF8

Write-Host "✅ Databricks environment configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Created Configuration Files:" -ForegroundColor Yellow
Write-Host "- databricks-config-$Environment.txt"
Write-Host "- cluster-config-$Environment.json"
Write-Host "- ml-pipeline-job-$Environment.json"
Write-Host "- databricks-$Environment.yml"
Write-Host "- setup-unity-catalog.sh"
Write-Host "- cluster-init-script.sh"
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Authenticate with Databricks: databricks auth login --host https://$workspaceUrl"
Write-Host "2. Run Unity Catalog setup: chmod +x setup-unity-catalog.sh && ./setup-unity-catalog.sh"
Write-Host "3. Create cluster: databricks clusters create --json-file cluster-config-$Environment.json"
Write-Host "4. Deploy notebooks: databricks bundle deploy -t $Environment"
Write-Host "5. Create ML pipeline job: databricks jobs create --json-file ml-pipeline-job-$Environment.json"
Write-Host ""
Write-Host "🔗 Databricks Workspace: https://$workspaceUrl" -ForegroundColor Blue
Write-Host "📊 Unity Catalog: https://$workspaceUrl/#unity-catalog" -ForegroundColor Blue