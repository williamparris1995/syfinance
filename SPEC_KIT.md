# Finance Management System - Specification Kit

**Version**: 2.0  
**Date**: 2026-05-12  
**Status**: Living Document  
**Project**: Personal Finance Management Application

---

## Document Purpose

This Specification Kit serves as the authoritative reference for the Finance Management System's architecture, requirements, and implementation standards. It consolidates:

1. **Functional Requirements** - Based on industry standards (IFRS, GAAP, ISO 4217)
2. **Non-Functional Requirements** - Performance, security, scalability
3. **Architecture Specifications** - DDD patterns, layer responsibilities
4. **Known Issues & Technical Debt** - Current limitations and remediation plans
5. **AI Development Harness** - Tools and guidelines for AI-assisted development

This document is intended for:
- Development teams (human and AI agents)
- System architects
- QA engineers
- Future maintainers

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Industry Standards & Compliance](#industry-standards--compliance)
3. [Functional Requirements](#functional-requirements)
4. [Non-Functional Requirements](#non-functional-requirements)
5. [Architecture Specification](#architecture-specification)
6. [Current Implementation Analysis](#current-implementation-analysis)
7. [Known Issues & Technical Debt](#known-issues--technical-debt)
8. [Improvement Roadmap](#improvement-roadmap)
9. [AI Development Harness](#ai-development-harness)
10. [References](#references)

---

## Executive Summary

### Project Overview

The Finance Management System is a **cross-platform desktop application** for personal financial management, built with:
- **Frontend**: React 19 + TypeScript 5.8 + Tauri 2.x
- **Backend**: Rust 1.94 + Axum + sqlx
- **Database**: SQLite (local) + PostgreSQL (sync)
- **Architecture**: Domain-Driven Design (DDD) with 4-layer separation

### Core Capabilities

✅ **Implemented**:
- Double-entry bookkeeping with automatic balance validation
- Three-level chart of accounts (Chinese accounting standards)
- Multi-currency support with manual exchange rates
- Account management (Cash, Bank, Credit Card, Investment, Loan)
- Transaction recording with category tagging
- Debt management with amortization schedules
- Financial reports (Balance Sheet, Income Statement)
- Offline-first with background sync

⚠️ **Partially Implemented**:
- User experience (complex transaction creation)
- Sync functionality (in-memory only)
- Notification system (not integrated)

❌ **Not Implemented**:
- Simplified transaction workflows
- Investment tracking
- Budget management
- Tax reporting
- Data import/export

### Critical Findings

**Strengths**:
1. Solid DDD architecture with clear bounded contexts
2. Rigorous double-entry bookkeeping enforcement
3. Comprehensive test coverage (152 tests)
4. Type-safe full-stack (Rust + TypeScript)

**Critical Issues**:
1. **UX Problem**: Users must understand double-entry accounting to create transactions
2. **Sync Broken**: PostgreSQL repositories not integrated
3. **Missing Facade Layer**: No simplified API for common operations
4. **Technical Debt**: 61 Clippy warnings, dead code, missing logging

---

## Industry Standards & Compliance

### Accounting Standards

#### ISO 4217 - Currency Codes
**Status**: 鉁?Compliant  
**Implementation**: currencies table with 3-letter codes (CNY, USD, EUR)

#### Double-Entry Bookkeeping
**Status**: 鉁?Compliant  
**Standard**: Universal accounting principle
**Implementation**: Database triggers + domain validation enforce debit = credit

#### Chart of Accounts
**Status**: 鉁?Compliant with Chinese Accounting Standards  
**Structure**: Three-level hierarchy (1000-5000 range)

| Code Range | Type | Balance Direction |
|------------|------|-------------------|
| 1000-1999 | Assets | Debit |
| 2000-2999 | Liabilities | Credit |
| 3000-3999 | Equity | Credit |
| 4000-4999 | Income | Credit |
| 5000-5999 | Expenses | Debit |

### Data Standards

#### Decimal Precision
**Status**: 鉁?Compliant  
**Standard**: Fixed-point arithmetic (never floating-point)  
**Implementation**: rust_decimal::Decimal with 2 decimal places

#### Date Handling
**Status**: 鉁?Compliant  
**Standard**: ISO 8601 (YYYY-MM-DD)

### Security Standards

#### Data Encryption
**Status**: 鈿狅笍 Not Implemented  
**Required**: At-rest encryption, TLS 1.3 for sync  
**Priority**: HIGH

#### Authentication
**Status**: 鉂?Not Implemented  
**Required**: Device token auth for sync API  
**Risk**: CRITICAL

### API Standards

#### RESTful API
**Status**: 鉁?Partial
- 鉁?Resource-based URLs
- 鉁?HTTP methods
- 鉁?JSON content
- 鉂?Versioning
- 鉂?Pagination
- 鉂?Rate limiting

#### Idempotency
**Status**: 鉂?Not Implemented  
**Risk**: Duplicate transactions on retry

---

## Functional Requirements

### FR-1: Account Management

#### FR-1.1: Create Account
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Create accounts with name, type, currency, initial balance
2. Validate account type
3. Enforce non-negative balance for Cash/Bank/Investment
4. Allow negative balance for CreditCard/Loan
5. Assign unique UUID

**Test Coverage**: 鉁?8 unit tests

#### FR-1.2: Update Account Balance
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Update balance only through transactions
2. Emit BalanceUpdated domain event
3. Validate currency consistency
4. Prevent direct manipulation

#### FR-1.3: Soft Delete Account
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Mark as deleted (tombstone pattern)
2. Preserve historical transactions
3. Exclude from reports
4. Prevent new transactions

### FR-2: Transaction Management

#### FR-2.1: Create Transaction (Current)
**Priority**: MUST HAVE | **Status**: 鈿狅笍 Implemented but UX problematic

**Requirements**:
1. Create with date, description, entries
2. Each entry: account, chart code, debit/credit, memo
3. Validate debit sum = credit sum
4. Reject transactions with < 2 entries
5. Reject mixed-currency
6. Update balances atomically

**Problem**: Requires double-entry accounting knowledge

**Test Coverage**: 鉁?12 unit tests

#### FR-2.2: Simplified Transaction Creation (NEW)
**Priority**: MUST HAVE | **Status**: 鉂?Not Implemented

**Requirements**:
1. Create income: amount, account, category, description
2. Create expense: amount, account, category, description
3. Create transfer: amount, from_account, to_account, description
4. Auto-generate two entries
5. Map category to chart code
6. Hide double-entry complexity

**Rationale**: 95% of users don't need journal entries

**Proposed Implementation**:
- SimpleIncomeDto, SimpleExpenseDto, SimpleTransferDto
- TransactionService convenience methods
- Tauri commands: create_income, create_expense, create_transfer
### FR-3: Category Management

#### FR-3.1: System Categories
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. System SHALL provide default income categories
2. System SHALL provide default expense categories
3. Each category SHALL map to chart of accounts code
4. Categories SHALL have icon, color, type (income/expense)

**Default Categories**:
- Income: Salary, Bonus, Investment, Other
- Expense: Food, Transport, Shopping, Entertainment, Housing, Healthcare, Education, Utilities, Other

#### FR-3.2: Custom Categories
**Priority**: SHOULD HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. User SHALL create custom categories
2. User SHALL organize categories hierarchically
3. System SHALL prevent circular parent references
4. System SHALL soft-delete categories

### FR-4: Debt Management

#### FR-4.1: Create Debt
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Support debt types: Lent, Borrowed, CreditCard, Loan
2. Record principal, interest rate, start date, due date
3. Generate amortization schedule (绛夐鏈伅/绛夐鏈噾)
4. Link to account for balance tracking

#### FR-4.2: Record Payment
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Record payment with principal/interest breakdown
2. Update remaining balance
3. Create corresponding transaction
4. Track payment history

#### FR-4.3: Payment Reminders
**Priority**: MUST HAVE | **Status**: 鈿狅笍 Partially Implemented

**Requirements**:
1. Create reminder for due date
2. Send notification before due date
3. Mark as overdue if unpaid
4. Support recurring reminders

**Current Issue**: Reminders created but notifications not sent

### FR-5: Reporting

#### FR-5.1: Balance Sheet
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Show assets, liabilities, equity
2. Calculate net worth (Assets - Liabilities)
3. Filter by date
4. Support multi-currency (with conversion)

#### FR-5.2: Income Statement
**Priority**: MUST HAVE | **Status**: 鉁?Implemented

**Requirements**:
1. Show income and expenses by category
2. Calculate net income (Income - Expenses)
3. Filter by date range
4. Group by category

#### FR-5.3: Cash Flow Report
**Priority**: SHOULD HAVE | **Status**: 鉂?Not Implemented

**Requirements**:
1. Show cash inflows and outflows
2. Categorize by operating/investing/financing
3. Calculate net cash flow
4. Trend analysis

### FR-6: Data Synchronization

#### FR-6.1: Device Registration
**Priority**: MUST HAVE | **Status**: 鈿狅笍 Partially Implemented

**Requirements**:
1. Register device with unique ID
2. Obtain authentication token
3. Store credentials securely

**Current Issue**: No authentication implemented

#### FR-6.2: Background Sync
**Priority**: MUST HAVE | **Status**: 鉂?Not Implemented

**Requirements**:
1. Sync data automatically at intervals
2. Use Last Write Wins conflict resolution
3. Handle network failures gracefully
4. Show sync status to user

**Current Issue**: Sync endpoints exist but don't persist to PostgreSQL

#### FR-6.3: Manual Sync
**Priority**: MUST HAVE | **Status**: 鈿狅笍 Partially Implemented

**Requirements**:
1. User SHALL trigger sync manually
2. System SHALL show sync progress
3. System SHALL report sync errors
4. System SHALL retry on failure

---

## Non-Functional Requirements

### NFR-1: Performance

#### NFR-1.1: Transaction Creation
**Requirement**: < 200ms response time  
**Current**: Not measured  
**Priority**: HIGH

**Acceptance Criteria**:
- 95th percentile < 200ms
- 99th percentile < 500ms
- No blocking UI operations

#### NFR-1.2: Report Generation
**Requirement**: < 1s for 10,000 transactions  
**Current**: Not measured  
**Priority**: MEDIUM

**Optimization Strategies**:
- Database indexes on transaction_date, account_id
- Materialized views for common aggregations
- Pagination for large result sets

#### NFR-1.3: Application Startup
**Requirement**: < 2s cold start  
**Current**: Not measured  
**Priority**: MEDIUM

### NFR-2: Security

#### NFR-2.1: Data Encryption at Rest
**Requirement**: AES-256 encryption for local database  
**Current**: 鉂?Not Implemented  
**Priority**: CRITICAL

**Implementation Plan**:
- Use SQLCipher for encrypted SQLite
- Derive key from user password (PBKDF2)
- Store salt securely

#### NFR-2.2: Data Encryption in Transit
**Requirement**: TLS 1.3 for all network communication  
**Current**: 鉂?Not Implemented  
**Priority**: CRITICAL

#### NFR-2.3: Authentication
**Requirement**: Device token authentication  
**Current**: 鉂?Not Implemented  
**Priority**: CRITICAL

**Implementation Plan**:
- JWT tokens with 30-day expiry
- Refresh token rotation
- Revocation support

#### NFR-2.4: Authorization
**Requirement**: User can only access own data  
**Current**: 鉂?Not Implemented  
**Priority**: CRITICAL

### NFR-3: Reliability

#### NFR-3.1: Data Integrity
**Requirement**: Zero data loss on crash  
**Current**: 鉁?SQLite ACID guarantees  
**Priority**: CRITICAL

**Validation**:
- Database triggers enforce constraints
- Domain model validation before persistence
- Transaction atomicity

#### NFR-3.2: Backup & Recovery
**Requirement**: Automatic daily backups  
**Current**: 鉂?Not Implemented  
**Priority**: HIGH

**Implementation Plan**:
- Export SQLite to timestamped file
- Compress and encrypt backup
- Retain last 30 days
- Cloud backup option (optional)

#### NFR-3.3: Error Handling
**Requirement**: Graceful degradation  
**Current**: 鉁?Partial  
**Priority**: HIGH

**Current Implementation**:
- ErrorBoundary catches React errors
- Toast notifications for user errors
- Rust Result types for error propagation

**Missing**:
- Structured logging
- Error reporting/telemetry
- Retry mechanisms

### NFR-4: Usability

#### NFR-4.1: Learnability
**Requirement**: New user completes first transaction in < 5 minutes  
**Current**: 鉂?Fails (requires accounting knowledge)  
**Priority**: CRITICAL

**Improvement Plan**:
- Simplified transaction forms
- Onboarding wizard
- Contextual help
- Sample data

#### NFR-4.2: Accessibility
**Requirement**: WCAG 2.1 Level AA compliance  
**Current**: Not validated  
**Priority**: MEDIUM

**Checklist**:
- Keyboard navigation
- Screen reader support
- Color contrast ratios
- Focus indicators

#### NFR-4.3: Internationalization
**Requirement**: Support multiple languages  
**Current**: 鉂?Not Implemented  
**Priority**: LOW

### NFR-5: Maintainability

#### NFR-5.1: Code Quality
**Requirement**: Zero Clippy warnings  
**Current**: 鉂?61 warnings  
**Priority**: HIGH

**Action Items**:
- Run cargo clippy --fix
- Enable clippy in CI/CD
- Add pre-commit hooks

#### NFR-5.2: Test Coverage
**Requirement**: > 80% line coverage  
**Current**: Not measured  
**Priority**: MEDIUM

**Current Tests**:
- 116 Rust unit tests
- 36 TypeScript unit tests
- 0 integration tests
- 0 E2E tests

#### NFR-5.3: Documentation
**Requirement**: All public APIs documented  
**Current**: 鉁?Partial  
**Priority**: MEDIUM

**Missing**:
- API documentation (Swagger/OpenAPI)
- Architecture decision records (ADRs)
- Deployment guide
- Troubleshooting guide

### NFR-6: Scalability

#### NFR-6.1: Data Volume
**Requirement**: Support 100,000 transactions  
**Current**: Not tested  
**Priority**: LOW

**Optimization Strategies**:
- Database indexes
- Pagination
- Virtual scrolling in UI
- Archive old data

#### NFR-6.2: Concurrent Users
**Requirement**: N/A (single-user desktop app)  
**Note**: Multi-user support not in scope

---
## Architecture Specification

### DDD Architecture Overview

The system follows **Domain-Driven Design (DDD)** with a 4-layer architecture:

```
鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?鈹?                 Presentation Layer                      鈹?鈹? - Tauri Commands (tauri_commands/)                     鈹?鈹? - REST API (api/)                                       鈹?鈹? - React UI (src/)                                       鈹?鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?                          鈫?鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?鈹?                 Application Layer                       鈹?鈹? - Services (services/)                                  鈹?鈹? - DTOs (dtos/)                                          鈹?鈹? - Use Case Orchestration                               鈹?鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?                          鈫?鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?鈹?                   Domain Layer                          鈹?鈹? - Aggregates (aggregates/)                             鈹?鈹? - Value Objects (value_objects/)                       鈹?鈹? - Domain Events                                         鈹?鈹? - Repository Interfaces (repositories/)                鈹?鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?                          鈫?鈹屸攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?鈹?               Infrastructure Layer                      鈹?鈹? - Repository Implementations (repositories/)           鈹?鈹? - Database (SQLite, PostgreSQL)                        鈹?鈹? - External Services (notifications, sync)              鈹?鈹斺攢鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹?```

### Bounded Contexts

#### 1. Account Management Context
**Aggregate Root**: Account  
**Entities**: Account  
**Value Objects**: Money, Currency, AccountType  
**Repository**: AccountRepository

**Responsibilities**:
- Create and manage financial accounts
- Track account balances
- Enforce account type rules

**Invariants**:
- Cash/Bank/Investment accounts cannot have negative balance
- CreditCard/Loan accounts can have negative balance
- Balance currency must match account currency

#### 2. Transaction Context
**Aggregate Root**: Transaction  
**Entities**: Transaction  
**Value Objects**: TransactionEntry, Money  
**Repository**: TransactionRepository

**Responsibilities**:
- Record financial transactions
- Enforce double-entry bookkeeping
- Update account balances

**Invariants**:
- Every transaction must have 鈮?2 entries
- Debit sum must equal credit sum
- All entries must use same currency
- Transactions are immutable after creation

#### 3. Category Context
**Aggregate Root**: Category  
**Entities**: Category  
**Value Objects**: CategoryType  
**Repository**: CategoryRepository

**Responsibilities**:
- Manage income/expense categories
- Map categories to chart of accounts
- Support hierarchical organization

**Invariants**:
- Category cannot be its own parent
- Category type (income/expense) is immutable
- Chart code must be valid

#### 4. Debt Context
**Aggregate Root**: Debt  
**Entities**: Debt, DebtPayment  
**Value Objects**: Money, AmortizationSchedule  
**Repository**: DebtRepository

**Responsibilities**:
- Track loans and debts
- Generate amortization schedules
- Record payments

**Invariants**:
- Principal amount > 0
- Interest rate 鈮?0
- Due date > start date

#### 5. Reminder Context
**Aggregate Root**: Reminder  
**Entities**: Reminder  
**Value Objects**: ReminderFrequency  
**Repository**: ReminderRepository

**Responsibilities**:
- Schedule payment reminders
- Trigger notifications
- Track reminder status

### Layer Responsibilities

#### Presentation Layer
**DO**:
- Handle HTTP requests/responses
- Validate input format
- Transform DTOs to/from JSON
- Handle authentication/authorization
- Route requests to application services

**DON'T**:
- Contain business logic
- Access repositories directly
- Perform domain calculations
- Manage transactions

**Current Issues**:
- 鉂?No authentication implemented
- 鉂?No input validation middleware
- 鈿狅笍 Some commands too complex (expose double-entry)

#### Application Layer
**DO**:
- Orchestrate use cases
- Coordinate multiple aggregates
- Manage transactions
- Transform domain objects to DTOs
- Handle application-level errors

**DON'T**:
- Contain domain logic
- Know about HTTP/UI details
- Directly manipulate domain state

**Current Issues**:
- 鉂?Missing facade methods for common operations
- 鈿狅笍 TransactionService exposes low-level API

**Improvement**: Add convenience methods:
```rust
// Current (complex)
create_transaction(CreateTransactionDto) -> Result<Uuid>

// Proposed (simple)
create_income(SimpleIncomeDto) -> Result<Uuid>
create_expense(SimpleExpenseDto) -> Result<Uuid>
create_transfer(SimpleTransferDto) -> Result<Uuid>
```

#### Domain Layer
**DO**:
- Enforce business rules
- Maintain invariants
- Emit domain events
- Contain core business logic
- Be framework-agnostic

**DON'T**:
- Access database
- Know about DTOs
- Depend on infrastructure

**Current Implementation**: 鉁?Excellent
- Rich domain models (not anemic)
- Strong invariant enforcement
- Domain events for side effects
- Repository interfaces (not implementations)

**Example**:
```rust
impl Transaction {
    pub fn new(...) -> Result<Self, TransactionError> {
        // Validate business rules
        if entries.len() < 2 {
            return Err(TransactionError::MinimumEntries);
        }
        
        let mut transaction = Self { ... };
        transaction.validate()?; // Enforce invariants
        transaction.emit_event(TransactionCreated); // Domain event
        Ok(transaction)
    }
}
```

#### Infrastructure Layer
**DO**:
- Implement repository interfaces
- Handle database operations
- Integrate external services
- Manage connections and resources

**DON'T**:
- Contain business logic
- Expose implementation details to domain

**Current Issues**:
- 鉂?PostgreSQL repositories not integrated
- 鉂?Sync service not connected to repositories
- 鉂?Notification service not integrated

### Design Patterns

#### 1. Repository Pattern
**Status**: 鉁?Implemented correctly

**Interface** (domain layer):
```rust
#[async_trait]
pub trait AccountRepository {
    async fn create(&self, account: &Account) -> Result<()>;
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Account>>;
    async fn find_all(&self) -> Result<Vec<Account>>;
    async fn update(&self, account: &Account) -> Result<()>;
}
```

**Implementation** (infrastructure layer):
```rust
pub struct SqliteAccountRepository {
    pool: SqlitePool,
}
```

**Benefits**:
- Domain layer independent of database
- Easy to swap implementations
- Testable with mock repositories

#### 2. Aggregate Pattern
**Status**: 鉁?Implemented correctly

**Rules**:
- Each aggregate has one root entity
- External objects can only reference the root
- Aggregates enforce invariants
- Aggregates are transaction boundaries

**Example**: Transaction aggregate
```rust
pub struct Transaction {
    pub id: Uuid,
    pub entries: Vec<TransactionEntry>, // Owned entities
    // ...
}

impl Transaction {
    pub fn validate(&self) -> Result<()> {
        // Enforce invariants across all entries
        let (debit, credit) = self.totals()?;
        if debit != credit {
            return Err(UnbalancedTransaction);
        }
        Ok(())
    }
}
```

#### 3. Value Object Pattern
**Status**: 鉁?Implemented correctly

**Characteristics**:
- Immutable
- Equality by value (not identity)
- Self-validating

**Example**: Money value object
```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Money {
    pub amount: Decimal,
    pub currency_code: String,
}

impl Money {
    pub fn new(amount: Decimal, currency_code: &str) -> Result<Self> {
        if amount.scale() > 2 {
            return Err(InvalidPrecision);
        }
        Ok(Self { amount, currency_code: currency_code.to_string() })
    }
    
    pub fn add(&self, other: &Money) -> Result<Money> {
        if self.currency_code != other.currency_code {
            return Err(CurrencyMismatch);
        }
        Ok(Money::new(self.amount + other.amount, &self.currency_code)?)
    }
}
```

#### 4. Domain Events Pattern
**Status**: 鉁?Implemented correctly

**Purpose**: Decouple side effects from core logic

**Example**:
```rust
pub enum AccountEvent {
    AccountCreated { account_id: Uuid, account_type: AccountType },
    BalanceUpdated { account_id: Uuid, previous_balance: Money, new_balance: Money },
}

impl Account {
    pub fn update_balance(&mut self, balance: Money) -> Result<()> {
        let previous = self.balance.clone();
        self.balance = balance.clone();
        self.pending_events.push(AccountEvent::BalanceUpdated {
            account_id: self.id,
            previous_balance: previous,
            new_balance: balance,
        });
        Ok(())
    }
    
    pub fn pull_events(&mut self) -> Vec<AccountEvent> {
        std::mem::take(&mut self.pending_events)
    }
}
```

#### 5. Factory Pattern
**Status**: 鈿狅笍 Could be improved

**Current**: Direct construction in services  
**Proposed**: Dedicated factories for complex aggregates

**Example**:
```rust
pub struct TransactionFactory {
    category_repo: Arc<dyn CategoryRepository>,
    account_repo: Arc<dyn AccountRepository>,
}

impl TransactionFactory {
    pub async fn create_income(
        &self,
        dto: SimpleIncomeDto,
    ) -> Result<Transaction> {
        let category = self.category_repo.find_by_id(&dto.category_id).await?;
        let account = self.account_repo.find_by_id(dto.account_id).await?;
        
        let entries = vec![
            TransactionEntry::debit(account.id, &account.chart_code, dto.amount),
            TransactionEntry::credit(Uuid::nil(), &category.chart_code, dto.amount),
        ];
        
        Transaction::new(Uuid::new_v4(), dto.date, dto.description, entries, metadata)
    }
}
```

#### 6. Specification Pattern
**Status**: 鉂?Not Implemented

**Use Case**: Complex query logic

**Proposed**:
```rust
pub trait Specification<T> {
    fn is_satisfied_by(&self, candidate: &T) -> bool;
}

pub struct TransactionInDateRange {
    start: NaiveDate,
    end: NaiveDate,
}

impl Specification<Transaction> for TransactionInDateRange {
    fn is_satisfied_by(&self, tx: &Transaction) -> bool {
        tx.transaction_date >= self.start && tx.transaction_date <= self.end
    }
}
```

---
## Known Issues & Technical Debt

### Critical Issues (P0 - Blockers)

#### ISSUE-001: No Authentication on Sync API
**Severity**: CRITICAL  
**Impact**: Anyone can access sync endpoints  
**Location**: `src-tauri/src/presentation/api/sync_routes.rs`  
**Risk**: Data breach, unauthorized access

**Remediation**:
1. Implement JWT-based device authentication
2. Add middleware for token validation
3. Implement token refresh mechanism
4. Add rate limiting

**Effort**: 3-5 days  
**Priority**: Must fix before production

#### ISSUE-002: No Data Encryption
**Severity**: CRITICAL  
**Impact**: Sensitive financial data stored in plaintext  
**Location**: SQLite database  
**Risk**: Data exposure if device compromised

**Remediation**:
1. Integrate SQLCipher for encrypted SQLite
2. Implement key derivation from user password
3. Secure key storage (OS keychain)
4. Add TLS for network communication

**Effort**: 5-7 days  
**Priority**: Must fix before production

#### ISSUE-003: Sync Not Functional
**Severity**: CRITICAL  
**Impact**: Multi-device sync doesn't work  
**Location**: `src-tauri/src/infrastructure/sync/`  
**Root Cause**: PostgreSQL repositories not integrated

**Remediation**:
1. Wire PostgreSQL repositories into SyncService
2. Implement conflict resolution (Last Write Wins)
3. Add sync error handling
4. Test multi-device scenarios

**Effort**: 7-10 days  
**Priority**: Required for multi-device support

### High Priority Issues (P1)

#### ISSUE-004: Complex Transaction UX
**Severity**: HIGH  
**Impact**: Users must understand double-entry accounting  
**Location**: `src/pages/TransactionsPage.tsx`  
**User Feedback**: "Too complicated to add a simple expense"

**Remediation**:
1. Add SimpleIncomeDto, SimpleExpenseDto, SimpleTransferDto
2. Implement convenience methods in TransactionService
3. Create simplified UI forms
4. Hide journal entries by default

**Effort**: 3-4 days  
**Priority**: Critical for user adoption

**Status**: 鉁?DTOs created, service methods pending

#### ISSUE-005: 61 Clippy Warnings
**Severity**: HIGH  
**Impact**: Code quality, maintainability  
**Location**: Throughout Rust codebase  
**Types**: Unused imports, dead code, style issues

**Remediation**:
1. Run `cargo clippy --fix`
2. Review and remove dead code
3. Add clippy to CI/CD
4. Enable `#![deny(clippy::all)]`

**Effort**: 1-2 days  
**Priority**: Should fix before next release

#### ISSUE-006: No Structured Logging
**Severity**: HIGH  
**Impact**: Difficult to debug production issues  
**Location**: Throughout codebase  
**Current**: console.error, println!

**Remediation**:
1. Integrate `tracing` crate for Rust
2. Add structured logging to TypeScript
3. Implement log levels (debug, info, warn, error)
4. Add log rotation and retention

**Effort**: 2-3 days  
**Priority**: Required for production support

#### ISSUE-007: Notification Service Not Integrated
**Severity**: HIGH  
**Impact**: Payment reminders don't trigger  
**Location**: `src-tauri/src/infrastructure/notifications/`  
**Root Cause**: NotificationService not connected to ReminderScheduler

**Remediation**:
1. Wire NotificationService into ReminderScheduler
2. Implement OS notification scheduling
3. Add notification preferences
4. Test notification delivery

**Effort**: 2-3 days  
**Priority**: Required for debt management feature

### Medium Priority Issues (P2)

#### ISSUE-008: No Integration Tests
**Severity**: MEDIUM  
**Impact**: Cross-feature bugs not caught  
**Location**: N/A  
**Current**: Only unit tests

**Remediation**:
1. Set up integration test framework
2. Test critical workflows (account 鈫?transaction 鈫?report)
3. Test sync scenarios
4. Add to CI/CD pipeline

**Effort**: 5-7 days  
**Priority**: Should have for quality assurance

#### ISSUE-009: Large Bundle Size (1.1MB)
**Severity**: MEDIUM  
**Impact**: Slow application startup  
**Location**: Frontend build  
**Current**: No code splitting

**Remediation**:
1. Implement route-based code splitting
2. Lazy load heavy components
3. Tree-shake unused dependencies
4. Optimize images and assets

**Effort**: 2-3 days  
**Priority**: Nice to have

#### ISSUE-010: No Pagination
**Severity**: MEDIUM  
**Impact**: Performance degrades with large datasets  
**Location**: Transaction list, report pages  
**Current**: Load all data at once

**Remediation**:
1. Implement cursor-based pagination in API
2. Add virtual scrolling in UI
3. Implement infinite scroll
4. Add page size preferences

**Effort**: 3-4 days  
**Priority**: Required for scalability

### Low Priority Issues (P3)

#### ISSUE-011: No Dark Mode
**Severity**: LOW  
**Impact**: User preference  
**Location**: UI theme  

**Effort**: 1-2 days

#### ISSUE-012: No Data Export
**Severity**: LOW  
**Impact**: Users can't export data  
**Location**: N/A

**Effort**: 2-3 days

#### ISSUE-013: No Budget Feature
**Severity**: LOW  
**Impact**: Missing planned feature  
**Location**: N/A

**Effort**: 7-10 days

### Technical Debt Summary

| Category | Count | Effort (days) |
|----------|-------|---------------|
| Critical (P0) | 3 | 15-22 |
| High (P1) | 4 | 10-14 |
| Medium (P2) | 3 | 10-14 |
| Low (P3) | 3 | 10-15 |
| **Total** | **13** | **45-65** |

---

## Improvement Roadmap

### Phase 2.1: Security & Stability (2-3 weeks)

**Goal**: Make application production-ready

**Tasks**:
1. 鉁?ISSUE-001: Implement authentication
2. 鉁?ISSUE-002: Add data encryption
3. 鉁?ISSUE-003: Fix sync functionality
4. 鉁?ISSUE-006: Add structured logging
5. 鉁?ISSUE-007: Integrate notifications

**Deliverables**:
- Secure, encrypted local storage
- Working multi-device sync
- Production-grade logging
- Payment reminders functional

**Success Criteria**:
- All P0 issues resolved
- Security audit passed
- Sync tested with 3+ devices

### Phase 2.2: User Experience (1-2 weeks)

**Goal**: Simplify transaction creation

**Tasks**:
1. 鉁?ISSUE-004: Simplified transaction UX
2. 鉁?Add onboarding wizard
3. 鉁?Contextual help system
4. 鉁?Sample data for new users

**Deliverables**:
- Simple income/expense forms
- Transfer wizard
- Interactive tutorial
- Help documentation

**Success Criteria**:
- New user completes first transaction in < 5 minutes
- User satisfaction score > 4/5

### Phase 2.3: Quality & Performance (1-2 weeks)

**Goal**: Improve code quality and performance

**Tasks**:
1. 鉁?ISSUE-005: Fix Clippy warnings
2. 鉁?ISSUE-008: Add integration tests
3. 鉁?ISSUE-009: Optimize bundle size
4. 鉁?ISSUE-010: Implement pagination

**Deliverables**:
- Zero Clippy warnings
- 50+ integration tests
- Bundle size < 500KB
- Pagination on all lists

**Success Criteria**:
- All tests passing
- Application startup < 2s
- Report generation < 1s for 10K transactions

### Phase 3: Advanced Features (4-6 weeks)

**Goal**: Add missing features

**Tasks**:
1. Budget management
2. Investment tracking
3. Tax reporting
4. Data import/export
5. Dark mode
6. Mobile app (React Native)

**Deliverables**:
- Budget creation and tracking
- Stock/bond portfolio management
- Tax schedule mapping
- CSV/OFX import
- Theme switcher
- iOS/Android apps

---

## AI Development Harness

### Purpose

This section defines tools, guidelines, and constraints for AI-assisted development on this project.

### Development Principles

#### 1. DDD First
**Rule**: All changes must respect DDD boundaries

**Checklist**:
- [ ] Does this change belong in the correct layer?
- [ ] Does it violate any aggregate boundaries?
- [ ] Are domain invariants maintained?
- [ ] Are repository interfaces used (not implementations)?

**Example Violation**:
```rust
// 鉂?BAD: Presentation layer accessing repository
#[tauri::command]
async fn get_account(id: Uuid, repo: AccountRepository) -> Account {
    repo.find_by_id(id).await.unwrap()
}

// 鉁?GOOD: Use application service
#[tauri::command]
async fn get_account(id: Uuid, service: AccountService) -> AccountDto {
    service.get_account(id).await.map(|a| to_dto(a))
}
```

#### 2. Test-Driven Development
**Rule**: Write tests before implementation for domain logic

**Process**:
1. Write failing test
2. Implement minimum code to pass
3. Refactor
4. Repeat

**Required for**:
- Domain model changes
- Business rule modifications
- Critical algorithms

**Optional for**:
- UI components
- Infrastructure code

#### 3. Type Safety
**Rule**: Leverage Rust's type system for correctness

**Guidelines**:
- Use `Result<T, E>` for fallible operations
- Use `Option<T>` for nullable values
- Avoid `unwrap()` in production code
- Use `?` operator for error propagation
- Define custom error types

**Example**:
```rust
// 鉂?BAD
fn divide(a: i32, b: i32) -> i32 {
    a / b  // Panics on b=0
}

// 鉁?GOOD
fn divide(a: i32, b: i32) -> Result<i32, DivisionError> {
    if b == 0 {
        return Err(DivisionError::DivideByZero);
    }
    Ok(a / b)
}
```

#### 4. Immutability by Default
**Rule**: Prefer immutable data structures

**Guidelines**:
- Use `&self` over `&mut self` when possible
- Clone value objects instead of mutating
- Use builder pattern for complex construction

#### 5. Explicit Over Implicit
**Rule**: Make behavior obvious

**Guidelines**:
- Avoid magic numbers (use constants)
- Name boolean variables clearly (`is_active`, `has_balance`)
- Use descriptive function names
- Add doc comments for public APIs

### Code Review Checklist

#### Domain Layer
- [ ] Aggregates enforce invariants
- [ ] Value objects are immutable
- [ ] Domain events emitted for state changes
- [ ] No infrastructure dependencies
- [ ] Business rules in domain, not services

#### Application Layer
- [ ] Services orchestrate, don't contain logic
- [ ] DTOs used for data transfer
- [ ] Transactions managed properly
- [ ] Error handling comprehensive
- [ ] No direct repository access from presentation

#### Infrastructure Layer
- [ ] Repository implementations match interfaces
- [ ] Database queries optimized
- [ ] Connections properly managed
- [ ] External service errors handled

#### Presentation Layer
- [ ] Input validation before service calls
- [ ] Errors translated to user-friendly messages
- [ ] No business logic
- [ ] Authentication/authorization enforced

### Testing Strategy

#### Unit Tests
**Coverage**: > 80% for domain layer  
**Location**: `src-tauri/src/domain/aggregates/*_test.rs`

**Test Structure**:
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    mod account {
        use super::*;
        
        mod business_rules {
            #[test]
            fn cash_account_rejects_negative_balance() {
                // Arrange
                // Act
                // Assert
            }
        }
        
        mod domain_events {
            #[test]
            fn emits_balance_updated_event() {
                // ...
            }
        }
    }
}
```

#### Integration Tests
**Coverage**: Critical workflows  
**Location**: `src-tauri/tests/`

**Scenarios**:
- Create account 鈫?Create transaction 鈫?Verify balance
- Create debt 鈫?Record payment 鈫?Verify remaining balance
- Sync data 鈫?Verify conflict resolution

#### E2E Tests
**Coverage**: User journeys  
**Tool**: Playwright

**Scenarios**:
- New user onboarding
- Record income and expense
- Generate report

### Common Patterns

#### Creating a New Aggregate

1. Define aggregate root in `domain/aggregates/`
2. Define value objects in `domain/value_objects/`
3. Define repository interface in `domain/repositories/`
4. Implement repository in `infrastructure/repositories/`
5. Create application service in `application/services/`
6. Define DTOs in `application/dtos/`
7. Add Tauri commands in `presentation/tauri_commands/`
8. Create UI components in `src/`

#### Adding a New Feature

1. Write spec in this document
2. Design domain model
3. Write domain tests (TDD)
4. Implement domain logic
5. Create application service
6. Add API endpoints
7. Build UI
8. Write integration tests
9. Update documentation

### AI Agent Guidelines

#### When to Ask for Clarification
- Business rule ambiguity
- Architecture decision needed
- Breaking change proposed
- Security implications unclear

#### When to Proceed Autonomously
- Bug fixes with clear root cause
- Code quality improvements
- Test additions
- Documentation updates
- Refactoring within layer

#### Prohibited Actions
- 鉂?Removing tests without replacement
- 鉂?Bypassing domain validation
- 鉂?Adding dependencies without justification
- 鉂?Committing secrets or credentials
- 鉂?Disabling security features

---

## References

### Industry Standards
1. **ISO 4217**: Currency Codes - https://www.iso.org/iso-4217-currency-codes.html
2. **IFRS**: International Financial Reporting Standards - https://www.ifrs.org/
3. **GAAP**: Generally Accepted Accounting Principles
4. **Double-Entry Bookkeeping**: Universal accounting standard

### Open Source References
1. **Firefly III**: https://github.com/firefly-iii/firefly-iii
   - Laravel-based personal finance manager
   - REST API design
   - Transaction collector pattern
2. **GnuCash**: https://www.gnucash.org/
   - Desktop accounting software
   - Investment tracking
   - MVC architecture
3. **Actual Budget**: https://actualbudget.com/
   - Modern web-based budgeting
   - Offline-first sync
4. **hledger**: https://hledger.org/
   - Plain-text accounting
   - Command-line interface

### DDD Resources
1. **Domain-Driven Design** by Eric Evans
2. **Implementing Domain-Driven Design** by Vaughn Vernon
3. **DDD Reference** by Eric Evans - https://www.domainlanguage.com/ddd/reference/

### Rust Resources
1. **The Rust Book**: https://doc.rust-lang.org/book/
2. **Rust API Guidelines**: https://rust-lang.github.io/api-guidelines/
3. **sqlx Documentation**: https://docs.rs/sqlx/

### React Resources
1. **React Documentation**: https://react.dev/
2. **TanStack Query**: https://tanstack.com/query/
3. **shadcn/ui**: https://ui.shadcn.com/

---

## Document Maintenance

**Owner**: Development Team  
**Review Frequency**: Monthly  
**Last Updated**: 2026-05-12  
**Next Review**: 2026-06-12

**Change Log**:
- 2026-05-12: Initial version created
- Future updates will be tracked here

---

**END OF SPECIFICATION KIT**
