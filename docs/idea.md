# Fixwaala --- Project Idea and Module Overview

## 1. Project Idea

**Fixwaala** is a college-project prototype for a **hyperlocal on-demand
home repair service platform** that connects customers with nearby
plumbers, electricians, and carpenters.

A customer describes a household problem, such as a leaking pipe or
broken fan. The system uses **AI-assisted fault classification** to
identify the service category and complexity, then searches for
available providers within an expanding geographic radius.

The project's core feature is **Trust-Gated Matching**. When a nearby
provider accepts a service request, they are not immediately assigned.
The customer gets **30 seconds** to review the provider's profile,
Aadhaar and selfie verification status, ratings, reviews, completed
jobs, distance, and estimated time of arrival (ETA).

The customer can confirm or reject the provider. The customer's exact
service address is revealed only after the provider is confirmed.

Once confirmed, the provider travels to the customer, checks in,
inspects the issue, submits a repair estimate, and waits for customer
approval before starting work.

After the repair is completed, the customer confirms completion, a
simulated payment is processed, and both users can rate each other.

The system consists of three primary user roles:

- **Customer**
- **Service Provider**
- **Admin**

The project uses:

- Flutter
- Firebase
- Google Maps
- AI-based fault assistance
- Sandbox/demo Aadhaar verification API
- Selfie verification API

> **In one line:** Fixwaala is an AI-assisted hyperlocal home-repair
> marketplace with customer-controlled, trust-based provider matching
> before private location details are shared.

---

# 2. Project Modules

The Fixwaala project consists of **12 main modules**.

---

## Module 1 --- Authentication & Role Management

### Main Purpose

Authenticate users and identify whether they are a **Customer**,
**Service Provider**, or **Admin**.

### Workflow

```text
App Opens
    ↓
Select Customer or Service Provider
    ↓
Enter Phone Number
    ↓
OTP Verification
    ↓
System Checks Role and Onboarding Status
    ↓
New User → Complete Registration
Returning User → Redirect to Correct Home Screen
```

The Admin uses a separate login and is redirected to the Admin
Dashboard.

---

## Module 2 --- Provider Identity & Selfie Verification

### Main Purpose

Demonstrate that service providers are identity-verified before they can
receive customer service requests.

### Workflow

```text
Provider Registers
    ↓
Enter Aadhaar Details
    ↓
Aadhaar Sandbox/Demo Verification API
    ↓
Capture Selfie
    ↓
Liveness and/or Face-Match Verification
    ↓
Store Verification Results
    ↓
Admin Reviews Provider
    ↓
Approve / Reject / Request Resubmission
    ↓
Approved Provider Receives Verified Status
    ↓
Provider Can Go Online
```

---

## Module 3 --- Customer Ticket & Service Request

### Main Purpose

Allow customers to create structured service requests for household
repair problems.

### Workflow

```text
Customer Selects "Create Service Request"
    ↓
Describe the Problem
    ↓
Upload Issue Images (Optional)
    ↓
Answer Guided Questions
    ↓
Service Category Suggested
    ↓
Customer Confirms Category
    ↓
Select Service Location
    ↓
Review Ticket
    ↓
Submit Request
    ↓
Ticket Enters Matching Process
```

---

## Module 4 --- Fault Intelligence & AI Ticket Assist

### Main Purpose

Help customers identify whether they need a **Plumber**,
**Electrician**, or **Carpenter** and estimate the basic complexity of
the issue.

### Workflow

```text
Customer Enters Problem Description
    ↓
System Checks Safety Keywords
    ↓
Guided Questions Collect More Information
    ↓
Rules and AI Analyze the Issue
    ↓
Category and Complexity Suggested
    ↓
Confidence Score Generated
    ↓
Low Confidence?
    ├── Yes → Ask Clarifying Question or Manual Category Selection
    └── No  → Continue
    ↓
Customer Confirms Final Category
```

---

## Module 5 --- Geo-Broadcast & Provider Discovery

### Main Purpose

Find nearby verified and available service providers with the correct
skill for the customer's problem.

### Workflow

```text
Ticket Enters Matching
    ↓
Use Customer's Approximate Location
    ↓
Search Eligible Providers Within 5 km
    ↓
Filter Providers By:
    • Skill
    • Verification Status
    • Availability
    • Account Status
    • Location Freshness
    ↓
Notify Eligible Providers
    ↓
No Provider Accepts Within 2 Minutes?
    ├── Search Within 10 km
    ↓
Still No Provider?
    ├── Search Within 15 km
    ↓
No Provider Found
    ↓
Matching Failed
    ↓
Customer Can Retry or Edit Ticket
```

---

## Module 6 --- Trust-Gated Matching

### Main Purpose

Allow the customer to review and approve a provider before the provider
is officially assigned and before the customer's exact address is
shared.

This is the **core feature of Fixwaala**.

### Workflow

```text
Provider Receives Opportunity
    ↓
Provider Presses "Accept"
    ↓
Backend Atomically Checks Ticket Availability
    ↓
One Provider Receives Temporary Candidate Lease
    ↓
Customer Receives 30-Second Review Screen
    ↓
Customer Views:
    • Verification Status
    • Ratings
    • Reviews
    • Completed Jobs
    • Distance
    • ETA
    ↓
Customer Decision
    ├── Confirm Provider
    │       ↓
    │   Provider Assigned
    │       ↓
    │   Exact Address Revealed
    │
    └── Reject Provider / Timer Expires
            ↓
        Candidate Removed
            ↓
        Matching Resumes
```

---

## Module 7 --- Service Job Lifecycle

### Main Purpose

Manage the complete repair process after a provider has been confirmed.

### Workflow

```text
Customer Confirms Provider
    ↓
Provider Starts Travel
    ↓
Customer Views Provider Status
    ↓
Provider Arrives
    ↓
Provider Checks In
    ↓
Provider Inspects Problem
    ↓
Provider Enters Diagnosis and Repair Estimate
    ↓
Customer Reviews Estimate
    ↓
Customer Decision
    ├── Reject → Service Does Not Continue
    └── Accept
            ↓
        Provider Starts Work
            ↓
        Provider Completes Repair
            ↓
        Provider Requests Completion
            ↓
        Customer Confirms Completion
```

---

## Module 8 --- Simulated Payment

### Main Purpose

Demonstrate a payment workflow without processing real money.

### Workflow

```text
Customer Confirms Job Completion
    ↓
Open Simulated Payment Screen
    ↓
Customer Selects Payment Action
    ↓
Payment Processing Animation
    ↓
Generate Success or Failure Result
    ↓
Store Payment Record
    ↓
Successful Payment
    ↓
Continue to Ratings and Ticket Closure
```

---

## Module 9 --- Ratings & Reputation

### Main Purpose

Build provider trust information and maintain service-quality records.

### Workflow

```text
Ticket Completed
    ↓
Customer Rates Provider
    ↓
Provider Rates Customer
    ↓
System Checks for Duplicate Rating
    ↓
Store Rating
    ↓
Recalculate Provider Rating Average
    ↓
Update Completed Job Statistics
    ↓
Update Internal Trust / Reliability Score
    ↓
Display Updated Provider Reputation
```

---

## Module 10 --- Provider Dashboard & Analytics

### Main Purpose

Allow providers to monitor their work history, earnings records, and
service performance.

### Workflow

```text
Provider Opens Dashboard
    ↓
Load Active and Completed Job Data
    ↓
Calculate:
    • Earnings
    • Ratings
    • Completion Rate
    • Cancellation Rate
    • Response Time
    • Arrival Time
    ↓
Display Summary Cards
    ↓
Provider Opens Performance Section
    ↓
Display Charts:
    • Weekly Jobs
    • Monthly Earnings
    • Service Category Distribution
    • Demand Trends
```

---

## Module 11 --- Reports, Safety & Dispute

### Main Purpose

Allow customers and providers to report problems and demonstrate a
safety and moderation system.

### Workflow

```text
Customer or Provider Opens Report / Dispute
    ↓
Select Report Reason
    ↓
Enter Description
    ↓
Attach Evidence (Optional)
    ↓
Assign Report Severity
    ↓
Send Report to Admin Dashboard
    ↓
High-Severity Report?
    ├── Yes → Temporary Account Restriction May Be Applied
    └── No  → Standard Admin Review
    ↓
Admin Reviews Case
    ↓
Restore / Restrict / Suspend Account
    ↓
Report Resolved
```

### SOS Workflow

```text
Active Service Session
    ↓
User Presses SOS
    ↓
Safety Alert Created
    ↓
Active Ticket Flagged
    ↓
Admin Dashboard Alerted
```

---

## Module 12 --- Admin Panel

### Main Purpose

Give administrators centralized control over provider verification,
users, tickets, reports, and system configuration.

### Workflow

```text
Admin Logs In
    ↓
Admin Dashboard
    ↓
View:
    • Pending Provider Verifications
    • Active Tickets
    • Matching Failures
    • Reports
    • Safety Alerts
    ↓
Open Provider Verification
    ↓
Check Aadhaar API Result
    ↓
Check Selfie Verification Result
    ↓
Approve / Reject / Request Resubmission
    ↓
Monitor Tickets and Matching History
    ↓
Review Reports and Disputes
    ↓
Restrict or Suspend Accounts if Required
    ↓
Store Important Actions as Audit Events
```

---

# 3. Complete End-to-End Workflow

```text
Authentication
    ↓
Provider Verification
    ↓
Customer Ticket Creation
    ↓
AI Fault Classification
    ↓
Geo Provider Discovery
    ↓
Trust-Gated Matching
    ↓
Provider Confirmation
    ↓
Travel & Check-In
    ↓
Inspection
    ↓
Estimate Approval
    ↓
Repair Work
    ↓
Completion
    ↓
Simulated Payment
    ↓
Ratings
    ↓
Analytics & Ticket Closure
```

---

# 4. Core Technical Modules

The modules that primarily differentiate Fixwaala are:

### Module 4 --- Fault Intelligence & AI Ticket Assist

Uses AI and guided questions to understand the customer's problem and
suggest the appropriate service category.

### Module 5 --- Geo-Broadcast & Provider Discovery

Discovers nearby eligible service providers using location, skills,
availability, and an expanding search radius.

### Module 6 --- Trust-Gated Matching

Allows customers to review and approve a provider before final
assignment and before their exact service address is revealed.

> **Trust-Gated Matching is the central feature and main technical
> identity of Fixwaala.**

---

# 5. Project Summary

Fixwaala combines:

```text
AI-Assisted Fault Classification
            +
Hyperlocal Geo Provider Discovery
            +
Trust-Gated Provider Matching
            +
Provider Identity Verification
            +
Complete Repair Job Lifecycle
```

The project demonstrates how AI, geolocation, real-time backend
workflows, identity verification, and trust-based service matching can
be combined into a single home-service platform.
