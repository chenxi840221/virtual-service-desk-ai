# DXC Virtual Service Desk AI - Azure Environment Setup Script
# This script provisions all required Azure resources for the AI Service Desk solution

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "Australia East",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "dxc-servicedesk-ai"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure Environment Setup for DXC Virtual Service Desk AI" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow

# Login to Azure and set subscription
Write-Host "📝 Logging into Azure..." -ForegroundColor Blue
az login --use-device-code
az account set --subscription $SubscriptionId

# Create Resource Group
Write-Host "📦 Creating Resource Group..." -ForegroundColor Blue
az group create --name $ResourceGroupName --location $Location --tags Environment=$Environment Project=$ProjectName

# Define resource names with environment suffix
$storageAccountName = "${ProjectName}${Environment}sa".Replace("-", "").ToLower()
$keyVaultName = "${ProjectName}-${Environment}-kv"
$aiFoundryName = "${ProjectName}-${Environment}-ai"
$databricksName = "${ProjectName}-${Environment}-databricks"
$appServicePlanName = "${ProjectName}-${Environment}-asp"
$webAppName = "${ProjectName}-${Environment}-webapp"
$apiManagementName = "${ProjectName}-${Environment}-apim"
$logAnalyticsName = "${ProjectName}-${Environment}-logs"
$appInsightsName = "${ProjectName}-${Environment}-insights"

# 1. Create Storage Account for Data Lake Gen2
Write-Host "💾 Creating Storage Account with Data Lake Gen2..." -ForegroundColor Blue
az storage account create `
    --name $storageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --enable-hierarchical-namespace true `
    --tags Environment=$Environment Project=$ProjectName

# Create containers for different data types
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $storageAccountName --query "[0].value" --output tsv

az storage container create --name "raw-data" --account-name $storageAccountName --account-key $storageKey
az storage container create --name "processed-data" --account-name $storageAccountName --account-key $storageKey
az storage container create --name "models" --account-name $storageAccountName --account-key $storageKey
az storage container create --name "policies" --account-name $storageAccountName --account-key $storageKey

# 2. Create Key Vault for secrets management
Write-Host "🔐 Creating Key Vault..." -ForegroundColor Blue
az keyvault create `
    --name $keyVaultName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --enable-rbac-authorization true `
    --tags Environment=$Environment Project=$ProjectName

# 3. Create Log Analytics Workspace
Write-Host "📊 Creating Log Analytics Workspace..." -ForegroundColor Blue
az monitor log-analytics workspace create `
    --workspace-name $logAnalyticsName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --tags Environment=$Environment Project=$ProjectName

# 4. Create Application Insights
Write-Host "📈 Creating Application Insights..." -ForegroundColor Blue
az monitor app-insights component create `
    --app $appInsightsName `
    --location $Location `
    --resource-group $ResourceGroupName `
    --workspace $logAnalyticsName `
    --tags Environment=$Environment Project=$ProjectName

# 5. Create Azure Databricks Workspace
Write-Host "🧠 Creating Azure Databricks Workspace..." -ForegroundColor Blue
az databricks workspace create `
    --resource-group $ResourceGroupName `
    --name $databricksName `
    --location $Location `
    --sku premium `
    --tags Environment=$Environment Project=$ProjectName

# 6. Create Azure AI Foundry (Cognitive Services Multi-Service Account)
Write-Host "🤖 Creating Azure AI Foundry Workspace..." -ForegroundColor Blue
az cognitiveservices account create `
    --name $aiFoundryName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --kind CognitiveServices `
    --sku S0 `
    --tags Environment=$Environment Project=$ProjectName

# Get AI Foundry endpoint and key
$aiFoundryEndpoint = az cognitiveservices account show --name $aiFoundryName --resource-group $ResourceGroupName --query "properties.endpoint" --output tsv
$aiFoundryKey = az cognitiveservices account keys list --name $aiFoundryName --resource-group $ResourceGroupName --query "key1" --output tsv

# Store secrets in Key Vault
az keyvault secret set --vault-name $keyVaultName --name "AzureAI-Endpoint" --value $aiFoundryEndpoint
az keyvault secret set --vault-name $keyVaultName --name "AzureAI-ApiKey" --value $aiFoundryKey
az keyvault secret set --vault-name $keyVaultName --name "Storage-ConnectionString" --value "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageKey;EndpointSuffix=core.windows.net"

# 7. Create App Service Plan
Write-Host "🌐 Creating App Service Plan..." -ForegroundColor Blue
az appservice plan create `
    --name $appServicePlanName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku B2 `
    --is-linux `
    --tags Environment=$Environment Project=$ProjectName

# 8. Create Web App for API
Write-Host "🚀 Creating Web App..." -ForegroundColor Blue
az webapp create `
    --name $webAppName `
    --resource-group $ResourceGroupName `
    --plan $appServicePlanName `
    --runtime "DOTNETCORE:8.0" `
    --tags Environment=$Environment Project=$ProjectName

# Configure Web App settings
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $ResourceGroupName `
    --settings `
        ASPNETCORE_ENVIRONMENT=$Environment `
        KeyVault__VaultName=$keyVaultName `
        ApplicationInsights__ConnectionString=$(az monitor app-insights component show --app $appInsightsName --resource-group $ResourceGroupName --query "connectionString" --output tsv)

# Enable system-assigned managed identity
az webapp identity assign --name $webAppName --resource-group $ResourceGroupName

# 9. Create API Management (for production only)
if ($Environment -eq "prod") {
    Write-Host "🛡️ Creating API Management..." -ForegroundColor Blue
    az apim create `
        --name $apiManagementName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --publisher-name "DXC Technology" `
        --publisher-email "servicedesk@dxc.com" `
        --sku-name Developer `
        --tags Environment=$Environment Project=$ProjectName
}

# 10. Set up Virtual Network (for enhanced security)
$vnetName = "${ProjectName}-${Environment}-vnet"
$subnetName = "${ProjectName}-${Environment}-subnet"

Write-Host "🌐 Creating Virtual Network..." -ForegroundColor Blue
az network vnet create `
    --name $vnetName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --address-prefix 10.0.0.0/16 `
    --subnet-name $subnetName `
    --subnet-prefix 10.0.1.0/24 `
    --tags Environment=$Environment Project=$ProjectName

# 11. Configure RBAC permissions
Write-Host "🔒 Configuring RBAC permissions..." -ForegroundColor Blue

# Get current user object ID
$currentUserId = az ad signed-in-user show --query "id" --output tsv

# Assign Key Vault Administrator role to current user
az role assignment create `
    --assignee $currentUserId `
    --role "Key Vault Administrator" `
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"

# Get Web App managed identity
$webAppIdentity = az webapp identity show --name $webAppName --resource-group $ResourceGroupName --query "principalId" --output tsv

# Assign Key Vault Secrets User role to Web App
az role assignment create `
    --assignee $webAppIdentity `
    --role "Key Vault Secrets User" `
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$keyVaultName"

# Assign Storage Blob Data Contributor role to Web App
az role assignment create `
    --assignee $webAppIdentity `
    --role "Storage Blob Data Contributor" `
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

# 12. Output important information
Write-Host "✅ Azure Environment Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Environment Details:" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Storage Account: $storageAccountName"
Write-Host "Key Vault: $keyVaultName"
Write-Host "AI Foundry: $aiFoundryName"
Write-Host "Databricks: $databricksName"
Write-Host "Web App: $webAppName"
Write-Host "App Insights: $appInsightsName"
Write-Host ""
Write-Host "🔗 Important URLs:" -ForegroundColor Yellow
Write-Host "Web App: https://$webAppName.azurewebsites.net"
Write-Host "Key Vault: https://$keyVaultName.vault.azure.net"
Write-Host "AI Foundry: $aiFoundryEndpoint"
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Configure Databricks workspace and Unity Catalog"
Write-Host "2. Set up Azure DevOps CI/CD pipelines"
Write-Host "3. Deploy application code"
Write-Host "4. Configure monitoring and alerting"

# Create environment configuration file
$configContent = @"
{
  "Environment": "$Environment",
  "ResourceGroup": "$ResourceGroupName",
  "Location": "$Location",
  "Resources": {
    "StorageAccount": "$storageAccountName",
    "KeyVault": "$keyVaultName",
    "AIFoundry": "$aiFoundryName",
    "Databricks": "$databricksName",
    "WebApp": "$webAppName",
    "AppInsights": "$appInsightsName",
    "LogAnalytics": "$logAnalyticsName"
  },
  "Endpoints": {
    "WebApp": "https://$webAppName.azurewebsites.net",
    "KeyVault": "https://$keyVaultName.vault.azure.net",
    "AIFoundry": "$aiFoundryEndpoint"
  }
}
"@

$configContent | Out-File -FilePath "environment-$Environment.json" -Encoding UTF8
Write-Host "💾 Environment configuration saved to: environment-$Environment.json" -ForegroundColor Green