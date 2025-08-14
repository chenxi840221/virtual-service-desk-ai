# DXC Virtual Service Desk AI Solution

## Overview

An AI-powered Virtual Service Desk solution built with MVVM architecture, leveraging Azure AI Foundry and Databricks to automate 65% of routine service desk operations for DXC Australia.

## Key Features

- **AI-Powered Ticket Analysis**: Automated intent recognition, sentiment analysis, and classification
- **Intelligent Response Generation**: Context-aware responses using RAG (Retrieval-Augmented Generation)
- **Multi-Language Support**: Processing for English, Mandarin, Hindi, and Spanish
- **Real-Time Processing**: Sub-2-second response times for AI analysis
- **MVVM Architecture**: Clean separation of concerns with maintainable codebase
- **Azure Integration**: Native integration with Azure AI Foundry and Databricks

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Blazor UI     │    │   Web API        │    │   Databricks    │
│   (MVVM)        │◄──►│   Controllers    │◄──►│   ML Pipeline   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ViewModels    │    │   Services       │    │   Azure AI      │
│   Commands      │    │   Repositories   │    │   Foundry       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Project Structure

```
VirtualServiceDesk/
├── src/
│   ├── DXC.ServiceDesk.API/           # Web API controllers and services
│   ├── DXC.ServiceDesk.Core/          # Business logic and domain models
│   ├── DXC.ServiceDesk.Infrastructure/ # Data access and external services
│   ├── DXC.ServiceDesk.UI/            # Blazor frontend (MVVM)
│   └── DXC.ServiceDesk.Tests/         # Unit and integration tests
├── databricks/
│   ├── notebooks/                     # AI analysis notebooks
│   ├── workflows/                     # Job definitions
│   └── databricks.yml                 # Asset bundle configuration
├── docs/
│   ├── management/                    # Project management documents
│   └── technical/                     # Technical documentation
└── README.md
```

## Quick Start

### Prerequisites

- .NET 8.0 SDK
- Visual Studio 2022 or VS Code
- Azure subscription with:
  - Azure AI Foundry access
  - Databricks workspace
  - Azure DevOps organization

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd VirtualServiceDesk
   ```

2. **Configure Azure services**
   ```bash
   # Set up Databricks workspace
   databricks bundle validate -t dev
   databricks bundle deploy -t dev
   ```

3. **Configure application settings**
   ```json
   {
     "Databricks": {
       "Endpoint": "https://adb-{workspace-id}.{region}.azuredatabricks.net",
       "Token": "{your-token}"
     },
     "AzureAI": {
       "Endpoint": "{your-ai-foundry-endpoint}",
       "ApiKey": "{your-api-key}"
     }
   }
   ```

4. **Build and run**
   ```bash
   dotnet restore
   dotnet build
   dotnet run --project src/DXC.ServiceDesk.API
   ```

## MVVM Implementation

### Core Components

**Models (src/DXC.ServiceDesk.Core/Models/)**
- `ServiceTicket.cs` - Main ticket entity
- `AIAnalysisResult.cs` - AI analysis results
- `TicketComment.cs` - Ticket comments and interactions

**ViewModels (src/DXC.ServiceDesk.Core/ViewModels/)**
- `BaseViewModel.cs` - Base class with INotifyPropertyChanged
- `ServiceTicketViewModel.cs` - Main ticket management VM
- Command patterns with RelayCommand implementation

**Views (src/DXC.ServiceDesk.UI/)**
- Blazor components with data binding
- Real-time updates using SignalR
- Responsive design with Bootstrap

### Key MVVM Patterns

```csharp
// ViewModel with command pattern
public class ServiceTicketViewModel : BaseViewModel
{
    public ICommand CreateTicketCommand { get; }
    public ICommand AnalyzeTicketCommand { get; }
    
    // Observable properties
    public ObservableCollection<ServiceTicket> Tickets { get; set; }
    public ServiceTicket SelectedTicket { get; set; }
}

// Two-way data binding in Blazor
<InputText @bind-Value="NewTicket.Subject" />
<button @onclick="CreateTicketCommand.Execute">Create</button>
```

## AI Integration

### Databricks ML Pipeline

The solution uses Databricks notebooks for AI processing:

- **Intent Recognition**: Classifies ticket purpose and urgency
- **Sentiment Analysis**: Determines user emotional state
- **Category Classification**: Automatically categorizes tickets
- **Resolution Suggestion**: Provides recommended solutions
- **Escalation Prediction**: Identifies tickets requiring human intervention

### Azure AI Foundry Integration

Native integration provides:
- Multi-LLM support with secure data access
- Real-time conversational AI capabilities
- Enterprise-grade governance through Unity Catalog
- Contextual answers grounded in DXC policies

## Development Guidelines

### Coding Standards

- Follow C# coding conventions
- Use SOLID principles
- Implement proper error handling
- Maintain 90%+ test coverage
- Document public APIs

### Git Workflow

1. Create feature branch from `develop`
2. Implement changes with unit tests
3. Submit pull request with description
4. Code review and approval required
5. Merge to `develop`, deploy to staging

### Testing Strategy

```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"

# Performance testing
dotnet run --project tests/PerformanceTests
```

## Deployment

### CI/CD Pipeline

The project uses Azure DevOps with automated:
- Build validation
- Unit test execution
- Databricks asset validation
- Multi-environment deployment

### Environment Strategy

- **Development**: Individual workspaces
- **Staging**: Shared environment with synthetic data
- **Production**: Full-scale with enterprise security

## Monitoring and Observability

### Key Metrics

- AI Model Response Time: <2 seconds
- Classification Accuracy: >90%
- System Availability: 99.9%
- User Satisfaction: >4.5/5

### Alerting

- Performance degradation alerts
- AI accuracy threshold monitoring
- Security incident notifications
- Business KPI tracking

## Security

### Implementation

- Zero-trust architecture
- Data encryption at rest and in transit
- Role-based access control (RBAC)
- Azure AD integration
- Regular security assessments

### Compliance

- Australian Privacy Act compliance
- GDPR compliance for EU data
- SOC 2 Type II certification
- Regular audit trails

## Contributing

1. Read the [Project Charter](docs/management/PROJECT_CHARTER.md)
2. Review [Work Breakdown Structure](docs/management/WORK_BREAKDOWN_STRUCTURE.md)
3. Check [Risk Register](docs/management/RISK_REGISTER.md) for current issues
4. Follow MVVM patterns and coding standards
5. Include comprehensive tests
6. Update documentation

## Support

### Documentation

- [Technical Architecture](docs/technical/ARCHITECTURE.md)
- [API Documentation](docs/technical/API_REFERENCE.md)
- [User Guide](docs/technical/USER_GUIDE.md)
- [Troubleshooting](docs/technical/TROUBLESHOOTING.md)

### Contact

- **Project Manager**: [TBA]
- **Technical Lead**: [TBA]
- **Business Analyst**: [TBA]

## License

© 2024 DXC Technology. All rights reserved.

---

**Version**: 1.0  
**Last Updated**: [Current Date]