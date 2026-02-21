# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
A comprehensive educational resource documenting AWS API Gateway concepts, features, best practices, and comparisons with alternatives. This repository serves as a learning guide for developers and architects working with API management on AWS.

## Repository Structure

```
lesson-XX-topic-name/
├── README.md                    # Lesson overview, objectives, sub-lesson links
├── XX.0-lesson-overview.drawio  # Main lesson overview diagram (optional)
├── 01-sub-topic/
│   ├── README.md               # Sub-lesson content
│   ├── XX.1-diagram-name.drawio # DrawIO diagram source (numbered)
│   └── XX.1-diagram-name.png   # PNG export of diagram
├── 02-sub-topic/
│   ├── README.md
│   ├── XX.2-diagram-name.drawio
│   └── XX.2-diagram-name.png
└── ...
research-XX-topic-name/
├── README.md                    # Lesson overview, objectives, sub-lesson links
├── XX.0-research-overview.drawio  # Main lesson overview diagram (optional)
├── 01-sub-topic/
│   ├── README.md               # Sub-lesson content
│   ├── XX.1-diagram-name.drawio # DrawIO diagram source (numbered)
│   └── XX.1-diagram-name.png   # PNG export of diagram
├── 02-sub-topic/
│   ├── README.md
│   ├── XX.2-diagram-name.drawio
│   └── XX.2-diagram-name.png
└── ...
```

## Lesson Topics
- Lesson 01: AWS API Gateway - Complete Guide
  - Introduction and Architecture
  - API Gateway Types (REST, HTTP, WebSocket)
  - Core Features (Validation, Caching, Throttling)
  - Integration Patterns (Lambda, HTTP, AWS Services, VPC Link)
  - Security and Authentication
  - Deployment and Management
  - Comparison with Alternatives
  - Best Practices
  - Limitations and Considerations

## Target Audience
- Backend developers building APIs on AWS
- Solution architects designing API strategies
- DevOps engineers managing API infrastructure
- Technical leads evaluating API management solutions
- Developers transitioning to serverless architectures

## Working with Diagrams

### Naming Convention
- Diagrams follow the pattern: `[lesson].[sub-lesson]-descriptive-name.drawio`
- Examples: `04.1-account-structure.drawio`, `07.2-payment-flow.drawio`
- Lesson overview diagrams use `.0` suffix: `03.0-customer-management-overview.drawio`

### File Requirements
- All diagrams use DrawIO format (`.drawio` XML files)
- Each diagram must have a corresponding PNG export for viewing
- When modifying diagrams, update both the `.drawio` source and regenerate the `.png` export

### Styling Standards
- Enable shadows on shapes (`shadow=1`)
- Use curved arrows where appropriate (`curved=1`)
- Add flow animation to unidirectional arrows only (`flowAnimation=1`)
- **Do NOT use rounded corners on swimlane/frame groups** - remove `rounded=1` from swimlane styles
- Use consistent color schemes:
  - Blue: Services/APIs
  - Green: Data/Storage
  - Orange: External integrations
  - Purple: Security/Auth
  - Gray: Infrastructure
- Include title and descriptive labels in diagrams

## Content Conventions

### Documentation Structure
- Each lesson README follows consistent structure:
  - Overview and learning objectives
  - Detailed content with diagrams
  - Code examples (where applicable)
  - Key takeaways
  - Further reading

### Banking Domain Terminology
- Use standard ISO 20022 terminology where applicable
- Include glossary references for technical banking terms
- Explain acronyms on first use (CIF, SWIFT, IBAN, RTGS, etc.)

### Code Examples
- Use realistic banking domain examples
- Include schema definitions in SQL format
- API examples in OpenAPI/JSON format
- Event schemas in JSON with clear documentation

## Key Banking Concepts Covered

### Business Processes
- Customer Onboarding: Lead → KYC → Account Opening → Product Enrollment
- Loan Lifecycle: Application → Underwriting → Approval → Disbursement → Servicing → Closure
- Payment Processing: Initiation → Validation → Routing → Clearing → Settlement

### Technical Components
- Core Systems: Customer, Account, Deposit, Loan, Payment, GL
- Integration Points: Payment networks (SWIFT, RTGS, ACH), credit bureaus, regulators
- Data Patterns: Event sourcing, CQRS, double-entry accounting, audit trails

### Regulatory Compliance
- Data Protection: GDPR, PCI-DSS, data encryption, masking
- Financial Reporting: Basel III, IFRS 9, regulatory reporting
- Industry Standards: ISO 20022, SWIFT messaging, Open Banking (PSD2)

## Git Workflow

Commits in this repository include Claude as co-author:
```
Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

## Commands

### Documentation
- No build process required - all content is markdown
- Preview markdown files directly in IDE or GitHub

### Diagram Export
- Open `.drawio` files in Draw.io (desktop or web)
- Export as PNG with transparent background
- Match filename with `.drawio` source file

## Contributing Guidelines

1. Follow existing folder structure and naming conventions
2. Include diagrams for complex concepts
3. Use consistent terminology from glossary
4. Add practical examples relevant to banking domain
5. Update table of contents when adding new sections
6. Ensure all links between documents are valid
