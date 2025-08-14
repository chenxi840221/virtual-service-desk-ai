# Azure AI Foundry Configuration Script for DXC Virtual Service Desk AI
# This script configures AI Foundry workspace with models and endpoints

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AIFoundryName,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

Write-Host "🤖 Configuring Azure AI Foundry for Virtual Service Desk AI" -ForegroundColor Green

# Install required Azure CLI extensions
Write-Host "📦 Installing Azure CLI extensions..." -ForegroundColor Blue
az extension add --name ml --upgrade --yes
az extension add --name cognitiveservices --upgrade --yes

# Get AI Foundry details
$aiFoundryEndpoint = az cognitiveservices account show --name $AIFoundryName --resource-group $ResourceGroupName --query "properties.endpoint" --output tsv
$aiFoundryKey = az cognitiveservices account keys list --name $AIFoundryName --resource-group $ResourceGroupName --query "key1" --output tsv

Write-Host "✅ AI Foundry Endpoint: $aiFoundryEndpoint" -ForegroundColor Green

# Create AI Foundry project configuration
$projectConfig = @"
{
  "name": "dxc-servicedesk-ai-$Environment",
  "description": "DXC Virtual Service Desk AI Project - $Environment Environment",
  "ai_foundry_endpoint": "$aiFoundryEndpoint",
  "models": {
    "text_analysis": {
      "name": "gpt-4o-mini",
      "deployment_name": "gpt-4o-mini-$Environment",
      "version": "2024-07-18",
      "capacity": 10,
      "usage": "Intent recognition, sentiment analysis, and text classification"
    },
    "text_generation": {
      "name": "gpt-4o",
      "deployment_name": "gpt-4o-$Environment", 
      "version": "2024-08-06",
      "capacity": 5,
      "usage": "Response generation and knowledge base queries"
    },
    "embeddings": {
      "name": "text-embedding-3-large",
      "deployment_name": "embeddings-$Environment",
      "version": "1",
      "capacity": 20,
      "usage": "Vector embeddings for RAG and semantic search"
    }
  },
  "endpoints": {
    "ticket_analysis": "/api/analyze-ticket",
    "response_generation": "/api/generate-response", 
    "sentiment_analysis": "/api/analyze-sentiment",
    "classification": "/api/classify-ticket",
    "embeddings": "/api/embeddings"
  }
}
"@

$projectConfig | Out-File -FilePath "ai-foundry-config-$Environment.json" -Encoding UTF8

# Create model deployment script
$modelDeploymentScript = @"
# Model Deployment Commands for Azure AI Foundry
# Run these commands after AI Foundry workspace is created

# 1. Deploy GPT-4o-mini for text analysis
az cognitiveservices account deployment create \
  --name $AIFoundryName \
  --resource-group $ResourceGroupName \
  --deployment-name "gpt-4o-mini-$Environment" \
  --model-name "gpt-4o-mini" \
  --model-version "2024-07-18" \
  --model-format OpenAI \
  --sku-capacity 10 \
  --sku-name "Standard"

# 2. Deploy GPT-4o for response generation  
az cognitiveservices account deployment create \
  --name $AIFoundryName \
  --resource-group $ResourceGroupName \
  --deployment-name "gpt-4o-$Environment" \
  --model-name "gpt-4o" \
  --model-version "2024-08-06" \
  --model-format OpenAI \
  --sku-capacity 5 \
  --sku-name "Standard"

# 3. Deploy Text Embeddings for vector search
az cognitiveservices account deployment create \
  --name $AIFoundryName \
  --resource-group $ResourceGroupName \
  --deployment-name "embeddings-$Environment" \
  --model-name "text-embedding-3-large" \
  --model-version "1" \
  --model-format OpenAI \
  --sku-capacity 20 \
  --sku-name "Standard"
"@

$modelDeploymentScript | Out-File -FilePath "deploy-models.sh" -Encoding UTF8

# Create AI service configuration for application
$appConfigTemplate = @"
{
  "AzureAI": {
    "Endpoint": "$aiFoundryEndpoint",
    "ApiVersion": "2024-08-01-preview",
    "Models": {
      "TextAnalysis": "gpt-4o-mini-$Environment",
      "TextGeneration": "gpt-4o-$Environment", 
      "Embeddings": "embeddings-$Environment"
    },
    "MaxTokens": {
      "Analysis": 1000,
      "Generation": 2000,
      "Embeddings": 8000
    },
    "Temperature": {
      "Analysis": 0.1,
      "Generation": 0.7
    },
    "RateLimits": {
      "RequestsPerMinute": 100,
      "TokensPerMinute": 50000
    }
  },
  "Features": {
    "IntentRecognition": true,
    "SentimentAnalysis": true,
    "CategoryClassification": true,
    "ResponseGeneration": true,
    "MultiLanguageSupport": ["en", "zh", "hi", "es"],
    "RAGEnabled": true,
    "EscalationPrediction": true
  }
}
"@

$appConfigTemplate | Out-File -FilePath "appsettings.$Environment.json" -Encoding UTF8

# Create prompt templates for AI models
$promptTemplates = @"
{
  "PromptTemplates": {
    "IntentRecognition": {
      "system": "You are an expert IT service desk analyst. Analyze the following service request and identify the primary intent. Respond with one of: password_reset, software_request, hardware_issue, network_access, account_management, security_incident, general_inquiry.",
      "user": "Subject: {subject}\nDescription: {description}\n\nIntent:"
    },
    "SentimentAnalysis": {
      "system": "Analyze the sentiment of this service desk ticket. Return a score between 0.0 (very negative/urgent) and 1.0 (very positive/satisfied). Consider urgency, frustration level, and tone.",
      "user": "Ticket content: {content}\n\nSentiment score:"
    },
    "CategoryClassification": {
      "system": "Classify this IT service request into one of these categories: PasswordReset, SoftwareRequest, HardwareIssue, NetworkAccess, AccountManagement, Security, General. Consider the subject, description, and any mentioned systems.",
      "user": "Subject: {subject}\nDescription: {description}\nDepartment: {department}\n\nCategory:"
    },
    "ResponseGeneration": {
      "system": "You are a helpful IT service desk assistant for DXC Technology. Generate a professional, helpful response to this service request. Include specific steps when possible and reference company policies if relevant.",
      "user": "Ticket: {ticket_content}\nCategory: {category}\nPriority: {priority}\n\nResponse:"
    },
    "EscalationPrediction": {
      "system": "Determine if this service desk ticket requires escalation to a human agent. Consider complexity, urgency, security implications, and whether it can be resolved with standard procedures. Respond with 'true' or 'false'.",
      "user": "Priority: {priority}\nCategory: {category}\nSentiment: {sentiment}\nDescription: {description}\n\nRequires escalation:"
    },
    "PolicyQuery": {
      "system": "You are a DXC Technology policy expert. Answer questions about company policies based on the provided context. Be specific and cite relevant policy sections when possible.",
      "user": "Policy context: {policy_context}\n\nQuestion: {question}\n\nAnswer:"
    }
  }
}
"@

$promptTemplates | Out-File -FilePath "prompt-templates.json" -Encoding UTF8

Write-Host "✅ AI Foundry configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Created Configuration Files:" -ForegroundColor Yellow
Write-Host "- ai-foundry-config-$Environment.json"
Write-Host "- appsettings.$Environment.json" 
Write-Host "- prompt-templates.json"
Write-Host "- deploy-models.sh"
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Run: chmod +x deploy-models.sh && ./deploy-models.sh"
Write-Host "2. Configure AI Foundry project in Azure portal"
Write-Host "3. Test model deployments"
Write-Host "4. Update application configuration with AI endpoints"
Write-Host ""
Write-Host "🔗 AI Foundry Portal: https://ai.azure.com" -ForegroundColor Blue
Write-Host "📊 Monitor deployments: https://portal.azure.com/#@/resource/subscriptions/{subscription}/resourceGroups/$ResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$AIFoundryName"