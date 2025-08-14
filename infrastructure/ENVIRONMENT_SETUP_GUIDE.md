# Environment Setup Guide
## DXC Virtual Service Desk AI Technical Infrastructure

This guide provides step-by-step instructions for setting up the complete technical environment for the DXC Virtual Service Desk AI solution.

## Prerequisites

### Required Tools
- **Azure CLI**: Version 2.50.0 or later
- **PowerShell**: Version 7.0 or later  
- **Databricks CLI**: Latest version
- **Git**: Version 2.30 or later
- **.NET SDK**: Version 8.0
- **Python**: Version 3.11 or later

### Required Permissions
- **Azure Subscription**: Contributor or Owner role
- **Azure AD**: Application Administrator role (for service principal creation)
- **Databricks**: Account Administrator role

### Azure Resource Quotas
Ensure your subscription has sufficient quotas:
- **Virtual Machines**: 20 cores (Standard DSv2 family)
- **Storage Accounts**: 10 accounts
- **Cognitive Services**: 5 accounts
- **App Service Plans**: 3 plans

## Environment Overview

| Environment | Purpose | Azure Region | Naming Convention |
|-------------|---------|--------------|-------------------|
| **Development** | Individual developer testing | Australia East | `dxc-servicedesk-ai-dev-*` |
| **Staging** | Pre-production validation | Australia East | `dxc-servicedesk-ai-staging-*` |
| **Production** | Live service delivery | Australia East | `dxc-servicedesk-ai-prod-*` |

## Step 1: Azure Infrastructure Setup

### 1.1 Development Environment

```powershell
# Clone the repository
git clone https://github.com/chenxi840221/virtual-service-desk-ai.git
cd virtual-service-desk-ai

# Set environment variables
$env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"
$env:AZURE_TENANT_ID = "your-tenant-id"

# Run infrastructure setup
./infrastructure/azure/setup-azure-environment.ps1 `
  -SubscriptionId $env:AZURE_SUBSCRIPTION_ID `
  -ResourceGroupName "dxc-servicedesk-ai-dev-rg" `
  -Environment "dev" `
  -Location "Australia East"
```

### 1.2 Staging Environment

```powershell
# Run staging infrastructure setup
./infrastructure/azure/setup-azure-environment.ps1 `
  -SubscriptionId $env:AZURE_SUBSCRIPTION_ID `
  -ResourceGroupName "dxc-servicedesk-ai-staging-rg" `
  -Environment "staging" `
  -Location "Australia East"
```

### 1.3 Production Environment

```powershell
# Run production infrastructure setup (requires approval)
./infrastructure/azure/setup-azure-environment.ps1 `
  -SubscriptionId $env:AZURE_SUBSCRIPTION_ID `
  -ResourceGroupName "dxc-servicedesk-ai-prod-rg" `
  -Environment "prod" `
  -Location "Australia East"
```

## Step 2: Azure AI Foundry Configuration

### 2.1 Configure AI Models

```powershell
# Configure AI Foundry for each environment
./infrastructure/azure/configure-ai-foundry.ps1 `
  -ResourceGroupName "dxc-servicedesk-ai-dev-rg" `
  -AIFoundryName "dxc-servicedesk-ai-dev-ai" `
  -Environment "dev"
```

### 2.2 Deploy AI Models

```bash
# Deploy models (run for each environment)
chmod +x deploy-models.sh
./deploy-models.sh
```

## Step 3: Databricks Environment Setup

### 3.1 Configure Databricks Workspace

```powershell
# Setup Databricks for development
./infrastructure/azure/setup-databricks.ps1 `
  -ResourceGroupName "dxc-servicedesk-ai-dev-rg" `
  -DatabricksWorkspaceName "dxc-servicedesk-ai-dev-databricks" `
  -StorageAccountName "dxcservicedeskaidevsa" `
  -Environment "dev"
```

### 3.2 Setup Unity Catalog

```bash
# Authenticate with Databricks
databricks auth login --host https://adb-{workspace-id}.{region}.azuredatabricks.net

# Run Unity Catalog setup
chmod +x setup-unity-catalog.sh
./setup-unity-catalog.sh

# Create tables
databricks sql-file --file-path databricks/sql/create_tables.sql
```

## Step 4: Azure DevOps Configuration

### 4.1 Create Azure DevOps Project

1. Navigate to [Azure DevOps](https://dev.azure.com)
2. Create new project: **DXC-ServiceDesk-AI**
3. Import repository from GitHub

### 4.2 Configure Service Connections

```yaml
# Create Azure service connections for each environment:
# - DXC-ServiceDesk-Dev
# - DXC-ServiceDesk-Staging  
# - DXC-ServiceDesk-Production
```

### 4.3 Setup Variable Groups

**Development Variables:**
```yaml
Variables:
  - AZURE_SUBSCRIPTION_ID: "dev-subscription-id"
  - RESOURCE_GROUP_NAME: "dxc-servicedesk-ai-dev-rg"
  - DATABRICKS_HOST: "https://adb-dev.azuredatabricks.net"
  - DATABRICKS_TOKEN: "$(databricks-dev-token)"
```

**Staging Variables:**
```yaml
Variables:
  - AZURE_SUBSCRIPTION_ID: "staging-subscription-id"
  - RESOURCE_GROUP_NAME: "dxc-servicedesk-ai-staging-rg"
  - DATABRICKS_HOST: "https://adb-staging.azuredatabricks.net"
  - DATABRICKS_TOKEN: "$(databricks-staging-token)"
```

**Production Variables:**
```yaml
Variables:
  - AZURE_SUBSCRIPTION_ID: "prod-subscription-id"
  - RESOURCE_GROUP_NAME: "dxc-servicedesk-ai-prod-rg"
  - DATABRICKS_HOST: "https://adb-prod.azuredatabricks.net"
  - DATABRICKS_TOKEN: "$(databricks-prod-token)"
```

## Step 5: Environment Validation

### 5.1 Infrastructure Health Check

```bash
# Run health checks for each environment
python scripts/health-check.py --environment dev
python scripts/health-check.py --environment staging
python scripts/health-check.py --environment prod
```

### 5.2 Connectivity Tests

```powershell
# Test Azure services connectivity
az account show
az cognitiveservices account show --name "dxc-servicedesk-ai-dev-ai" --resource-group "dxc-servicedesk-ai-dev-rg"

# Test Databricks connectivity
databricks clusters list
databricks workspace list

# Test Key Vault access
az keyvault secret list --vault-name "dxc-servicedesk-ai-dev-kv"
```

## Step 6: Application Deployment

### 6.1 Local Development Setup

```bash
# Restore NuGet packages
dotnet restore VirtualServiceDesk.sln

# Build solution
dotnet build VirtualServiceDesk.sln --configuration Debug

# Run tests
dotnet test src/**/*Tests.csproj

# Start local development server
dotnet run --project src/DXC.ServiceDesk.API
```

### 6.2 Environment Configuration

Copy the appropriate environment file:
```bash
# For development
cp infrastructure/environments/dev.env .env

# For staging  
cp infrastructure/environments/staging.env .env

# For production
cp infrastructure/environments/prod.env .env
```

## Step 7: Monitoring and Alerting Setup

### 7.1 Application Insights Configuration

```bash
# Configure Application Insights for each environment
az monitor app-insights component create \
  --app "dxc-servicedesk-ai-dev-insights" \
  --location "Australia East" \
  --resource-group "dxc-servicedesk-ai-dev-rg"
```

### 7.2 Log Analytics Workspace

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --workspace-name "dxc-servicedesk-ai-dev-logs" \
  --resource-group "dxc-servicedesk-ai-dev-rg" \
  --location "Australia East"
```

## Step 8: Security Configuration

### 8.1 Key Vault Setup

```bash
# Create secrets in Key Vault
az keyvault secret set --vault-name "dxc-servicedesk-ai-dev-kv" --name "ConnectionStrings--DefaultConnection" --value "your-connection-string"
az keyvault secret set --vault-name "dxc-servicedesk-ai-dev-kv" --name "AzureAI--ApiKey" --value "your-ai-api-key"
az keyvault secret set --vault-name "dxc-servicedesk-ai-dev-kv" --name "Databricks--Token" --value "your-databricks-token"
```

### 8.2 Managed Identity Configuration

```bash
# Assign Key Vault access to Web App managed identity
az keyvault set-policy \
  --name "dxc-servicedesk-ai-dev-kv" \
  --object-id $(az webapp identity show --name "dxc-servicedesk-ai-dev-webapp" --resource-group "dxc-servicedesk-ai-dev-rg" --query principalId -o tsv) \
  --secret-permissions get list
```

## Troubleshooting

### Common Issues

**Issue: PowerShell Execution Policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Issue: Azure CLI Authentication**
```bash
az login --use-device-code
az account set --subscription "your-subscription-id"
```

**Issue: Databricks CLI Authentication**
```bash
databricks auth login --host https://your-workspace.azuredatabricks.net
```

**Issue: Insufficient Azure Permissions**
- Ensure you have Contributor or Owner role on the subscription
- Verify Application Administrator role in Azure AD

### Validation Commands

```bash
# Verify all resources are created
az resource list --resource-group "dxc-servicedesk-ai-dev-rg" --output table

# Check application health
curl https://dxc-servicedesk-ai-dev-webapp.azurewebsites.net/health

# Verify Databricks cluster
databricks clusters get --cluster-id "your-cluster-id"
```

## Environment-Specific Notes

### Development Environment
- **Purpose**: Individual developer testing and debugging
- **Data**: Synthetic data only
- **Security**: Relaxed for development productivity
- **Monitoring**: Basic Application Insights
- **Cost**: Optimized for low cost

### Staging Environment  
- **Purpose**: Pre-production validation and integration testing
- **Data**: Production-like synthetic data
- **Security**: Production-equivalent security controls
- **Monitoring**: Full monitoring and alerting
- **Cost**: Balanced between functionality and cost

### Production Environment
- **Purpose**: Live service delivery to end users
- **Data**: Real DXC service desk data
- **Security**: Maximum security controls
- **Monitoring**: Comprehensive monitoring with 24/7 alerting
- **Cost**: Optimized for performance and availability

## Next Steps

After completing the environment setup:

1. **Deploy Application Code**: Use Azure DevOps pipelines to deploy the application
2. **Configure Monitoring**: Set up alerts and dashboards in Azure Monitor
3. **Load Test**: Perform load testing in staging environment
4. **Security Scan**: Run security assessments on all environments
5. **Documentation**: Update operational runbooks and procedures
6. **Training**: Conduct team training on deployment and operations

## Support Contacts

- **Technical Lead**: [technical-lead@dxc.com]
- **DevOps Engineer**: [devops-engineer@dxc.com]
- **Project Manager**: [project-manager@dxc.com]
- **Azure Support**: [azure-support@dxc.com]

---

**Document Version**: 1.0  
**Last Updated**: [Current Date]  
**Next Review**: [Date + 1 month]