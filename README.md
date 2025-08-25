# Educational Grant Tracking System

A comprehensive blockchain-based system for managing educational grants at research institutions, built with Clarity smart contracts on the Stacks blockchain.

## Overview

This system provides a complete workflow for educational grant management, from application submission to impact reporting. It ensures transparency, accountability, and compliance throughout the grant lifecycle.

## System Architecture

The system consists of five interconnected smart contracts:

### 1. Grant Management Contract (`grant-management.clar`)
- Grant application submission and review
- Approval/rejection workflow with multi-level authorization
- Grant status tracking and updates
- Principal investigator and institution management

### 2. Fund Disbursement Contract (`fund-disbursement.clar`)
- Automated fund release based on milestones
- Budget allocation and spending limits
- Payment scheduling and execution
- Financial audit trail

### 3. Milestone Verification Contract (`milestone-verification.clar`)
- Research milestone definition and tracking
- Evidence submission and verification
- Progress reporting and validation
- Deliverable management

### 4. Compliance Monitoring Contract (`compliance-monitoring.clar`)
- Regulatory compliance checking
- Reporting requirement enforcement
- Audit trail maintenance
- Violation detection and alerts

### 5. Impact Tracking Contract (`impact-tracking.clar`)
- Research outcome measurement
- Publication and citation tracking
- Societal impact assessment
- Long-term benefit analysis

## Key Features

- **Transparent Workflow**: All grant activities are recorded on-chain
- **Automated Compliance**: Built-in checks for regulatory requirements
- **Milestone-Based Funding**: Funds released only upon milestone completion
- **Impact Measurement**: Comprehensive tracking of research outcomes
- **Multi-Institution Support**: Designed for university consortiums
- **Audit Trail**: Complete history of all grant-related activities

## Grant Lifecycle

1. **Application**: Researchers submit grant proposals with detailed budgets
2. **Review**: Multi-stage review process with expert evaluation
3. **Approval**: Authorized personnel approve grants and allocate funds
4. **Disbursement**: Funds released based on milestone completion
5. **Monitoring**: Continuous compliance and progress tracking
6. **Reporting**: Regular progress reports and outcome documentation
7. **Impact Assessment**: Long-term evaluation of research impact

## Data Structures

### Grant Application
- Grant ID, title, and description
- Principal investigator and co-investigators
- Institution and department information
- Budget breakdown and timeline
- Research objectives and methodology

### Milestone
- Milestone ID and description
- Expected completion date
- Required deliverables
- Verification criteria
- Associated funding amount

### Compliance Record
- Requirement type and description
- Compliance status and evidence
- Review date and reviewer
- Corrective actions if needed

## Security Features

- **Access Control**: Role-based permissions for different user types
- **Data Integrity**: Immutable record keeping on blockchain
- **Audit Trail**: Complete transaction history
- **Validation**: Input validation and error handling
- **Authorization**: Multi-signature requirements for critical operations

## Installation and Setup

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Run `npm test` to execute test suite
5. Deploy contracts using `clarinet deploy`

## Testing

The system includes comprehensive tests covering:
- Contract deployment and initialization
- Grant application and approval workflows
- Fund disbursement mechanisms
- Milestone verification processes
- Compliance monitoring functions
- Impact tracking capabilities

## Usage Examples

### Submitting a Grant Application
```clarity
(contract-call? .grant-management submit-application
  "AI Research for Education"
  "Developing AI tools for personalized learning"
  u1000000  ;; 1M microSTX budget
  u365      ;; 365 days duration
)
