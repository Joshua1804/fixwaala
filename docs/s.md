# Create three-member walkthrough plan

> refer the idea md file and the ppt
>
> in that the the project is diveded to 3 modeule i want u to go through that and make a walkthrough plan taht is divided for 3 member
>
> User context
>
> Attachments:
>
> - idea.md: `./docs/idea.md`
> - Fixwaala_presentation.pptx: `~/Downloads/Fixwaala_presentation.pptx`

<details><summary>1 previous message</summary>

> System error
>
> The 'gpt-5.3-codex' model is not supported when using Codex with a ChatGPT account.

</details>

> do again

<details><summary>9 previous messages</summary>

> I’ll review the idea document and presentation, then create a clear three-member walkthrough plan. I’m using the presentations workflow to inspect the slide deck accurately.
>
> <details><summary>Explored 2 files, a list</summary>
>
> - Read `~/.codex/skills/.system/presentations/Presentations/SKILL.md`
> - Read `./docs/idea.md`
> - Listed files
>
> </details>
>
> The first skill path alias was incorrect; I’m using the available presentations skill location and continuing with the source review.
>
> <details><summary>Explored a file, a list, ran 2 commands</summary>
>
> <details><summary>Explored 2 files, a list</summary>
>
> - Read `~/.codex/plugins/cache/openai-primary-runtime/presentations/26.715.12143/skills/presentations/SKILL.md`
> - Read `./docs/idea.md`
> - Listed files
>
> </details>
>
> - Ran `printf '%s\n' '--- IDEA 1 ---' && sed -n '1,260p' docs/idea.md && printf '%s\n' '--- IDEA 2 ---' && sed -n '261,520p' docs/idea.md && printf '%s\n' '--- TEMPLATE FOLLOWING ---' && sed -n '1,240p' /Users/joshuaphilip/.codex/plugins/cache/openai-primary-runtime/presentations/26.715.12143/skills/presentations/references/template-following.md && printf '%s\n' '--- PPTX INFO ---' && file /Users/joshuaphilip/Downloads/Fixwaala_presentation.pptx && unzip -l /Users/joshuaphilip/Downloads/Fixwaala_presentation.pptx | sed -n '1,140p'`
> - Ran `sed -n '521,900p' docs/idea.md && printf '\n--- PPTX INSPECT ---\n' && tmp_dir=$(mktemp -d /tmp/fixwaala-ppt-XXXXXX) && node /Users/joshuaphilip/.codex/plugins/cache/openai-primary-runtime/presentations/26.715.12143/skills/presentations/template_following_scripts/inspect_template_deck.mjs --workspace "$tmp_dir" --pptx /Users/joshuaphilip/Downloads/Fixwaala_presentation.pptx && printf '\nTMP=%s\n' "$tmp_dir" && find "$tmp_dir" -maxdepth 2 -type f | sort | sed -n '1,160p'`
>
> </details>
>
> The idea document is fully mapped into 12 modules. I’m now extracting the deck’s slide-by-slide content and visuals so the walkthrough follows both sources, including the project’s actual implementation structure.
>
> <details><summary>Ran 3 commands</summary>
>
> - Ran `tmp_dir=/tmp/fixwaala-ppt-adjl00; printf '%s\n' '--- MANIFEST ---'; sed -n '1,260p' "$tmp_dir/template-inspect/template-manifest.json"; printf '%s\n' '--- NDJSON HEAD ---'; sed -n '1,140p' "$tmp_dir/template-inspect/template-inspect.ndjson"; printf '%s\n' '--- ALL TMP FILES ---'; find "$tmp_dir" -maxdepth 4 -type f | sort`
> - Ran `python3 /Users/joshuaphilip/.codex/plugins/cache/openai-primary-runtime/presentations/26.715.12143/skills/presentations/container_tools/create_montage.py --input_dir /tmp/fixwaala-ppt-adjl00/template-inspect/source-slides --output_file /tmp/fixwaala-ppt-adjl00/template-inspect/contact-sheet.png --label_mode filename --retain_converted_files`
> - Ran `for slide_num in $(seq 1 14); do printf '\n--- SLIDE %s ---\n' "$slide_num"; unzip -p /Users/joshuaphilip/Downloads/Fixwaala_presentation.pptx "ppt/slides/slide${slide_num}.xml" | perl -ne 'while (/<a:t>(.*?)<\/a:t>/g) { print "$1\n" }'; done`
>
> </details>
>
> Viewed 3 images
>
> The deck’s three presentation modules are clear: Trust-Gated Matching, Fault Intelligence & Ticket Assist, and Provider Reputation & Earnings Dashboard. I’m checking the implementation files now so each member’s walkthrough matches what can actually be demonstrated.
>
> <details><summary>Explored a file, a search</summary>
>
> - Read `./README.md`
> - Searched for `class |Future<|Widget build|Trust|Matching|AI|Fault|Dashboard|Earnings|Trust Score|analytics|rating|acceptance|completion` in `features`
>
> </details>

</details>

Here is a walkthrough plan divided among the three members, based on the three modules in the PPT and the detailed modules in [idea.md](./docs/idea.md:1).

## Member 1 — Trust-Gated Matching

**Main responsibility:** Explain Fixwaala’s core innovation: customers approve the provider before sharing their exact address.

**Walkthrough:**

1. Introduce the problem with existing service platforms.
2. Explain provider verification and geo-broadcasting.
3. Demonstrate a provider receiving a service request.
4. Show the provider accepting the request.
5. Show the customer’s 30-second review window.
6. Display provider profile, verification, ratings, reviews, distance, and ETA.
7. Demonstrate:
   - Confirm provider
   - Reject provider
   - Timer expiry and re-broadcast
8. Explain that the exact address is revealed only after confirmation.

**Relevant implementation areas:**

- `lib/features/trust_gated_matching/`
- `lib/features/geo_broadcast/`
- `lib/features/provider_verification/`

**Handoff:**
“Now that the customer can safely choose a provider, Member 2 will explain how Fixwaala understands and classifies the customer’s repair problem.”

## Member 2 — Fault Intelligence & Ticket Assist

**Main responsibility:** Explain how customers create a structured ticket and receive AI-assisted diagnosis.

**Walkthrough:**

1. Open the customer dashboard.
2. Select “Create Service Request.”
3. Enter a sample issue, such as “My kitchen pipe is leaking.”
4. Upload an issue image if available.
5. Answer the guided diagnostic questions.
6. Show the AI/rule-based classification:
   - Suggested category: Plumber, Electrician, or Carpenter
   - Complexity: Minor, Moderate, or Major
   - Confidence score
7. Explain the low-confidence fallback and manual category selection.
8. Review and submit the final ticket.
9. Explain how the ticket is sent to geo-broadcasting.

**Relevant implementation areas:**

- `lib/features/customer_ticket/`
- `lib/features/ai_assist/`
- `lib/features/geo_broadcast/`

**Handoff:**
“After the issue is classified and matched with a provider, the completed service generates ratings, earnings, and performance data. Member 3 will demonstrate that dashboard.”

## Member 3 — Provider Reputation & Earnings Dashboard

**Main responsibility:** Explain how Fixwaala helps providers track performance and build trust.

**Walkthrough:**

1. Open the provider dashboard.
2. Show total earnings.
3. Show acceptance rate and completion rate.
4. Show average rating and rating trend.
5. Show completed jobs and service categories.
6. Explain peak demand insights.
7. Explain the Trust Score and how it is affected by:
   - Ratings
   - Completion rate
   - Response time
   - Cancellations
8. Demonstrate the service lifecycle:
   - Provider travels to customer
   - Check-in
   - Inspection
   - Estimate submission
   - Customer approval
   - Repair completion
   - Simulated payment
   - Mutual ratings
9. Briefly show the Admin panel for verification, reports, disputes, and account restrictions.
10. Conclude by connecting analytics to better service quality and provider growth.

**Relevant implementation areas:**

- `lib/features/provider_dashboard/`
- `lib/features/service_lifecycle/`
- `lib/features/payment/`
- `lib/features/ratings/`
- `lib/features/admin_panel/`

## Recommended presentation order

For the slides, follow the existing PPT order:

1. Member 1 — Trust-Gated Matching
2. Member 2 — Fault Intelligence & Ticket Assist
3. Member 3 — Provider Reputation & Earnings Dashboard

For the live application demo, the natural user journey is:

`Create Ticket → AI Classification → Provider Discovery → Trust-Gated Confirmation → Service Lifecycle → Payment → Ratings → Dashboard`

The three module descriptions are shown in slides 7–8 of [Fixwaala_presentation.pptx](~/Downloads/Fixwaala_presentation.pptx).

> now i want u to give me the full modules iin this projects

Fixwaala has **12 detailed functional modules**, grouped into the **3 major presentation modules** shown in the PPT.

## Group 1: Trust-Gated Matching

### 1. Authentication & Role Management

Handles login and identifies the user as:

- Customer
- Service Provider
- Admin

Main functions:

- Phone number and OTP login
- User registration
- Role selection
- Role-based home screens
- Admin login
- Session management

### 2. Provider Identity & Selfie Verification

Ensures that only verified providers can receive jobs.

Main functions:

- Aadhaar details submission
- Sandbox Aadhaar verification
- Selfie capture
- Liveness and face-match verification
- Verification status tracking
- Admin approval, rejection, or resubmission request
- Provider online/offline availability

### 3. Geo-Broadcast & Provider Discovery

Finds suitable nearby providers.

Main functions:

- Location permission and GPS tracking
- Provider search within 5 km
- Radius expansion to 10 km and 15 km
- Skill-based filtering
- Verification-status filtering
- Availability checking
- Provider notification
- Matching failure handling

### 4. Trust-Gated Matching

This is Fixwaala’s core feature.

Main functions:

- Provider accepts a ticket
- Backend temporarily reserves the provider
- Customer receives a 30-second review window
- Customer views:
  - Provider profile
  - Verification status
  - Ratings and reviews
  - Completed jobs
  - Distance
  - ETA
- Customer confirms, rejects, or ignores the provider
- Exact customer address is revealed only after confirmation
- Rejected or expired matches are re-broadcast

Relevant code folder: `lib/features/trust_gated_matching/`

## Group 2: Fault Intelligence & Ticket Assist

### 5. Customer Ticket & Service Request

Allows customers to create repair requests.

Main functions:

- Problem description
- Issue image upload
- Guided questions
- Service category selection
- Location selection
- Immediate or scheduled booking
- Ticket review
- Ticket submission
- Ticket status tracking

### 6. Fault Intelligence & AI Ticket Assist

Uses AI and guided rules to understand the repair issue.

Main functions:

- Safety keyword detection
- Guided diagnostic questions
- Problem classification
- Category suggestion:
  - Plumber
  - Electrician
  - Carpenter
- Complexity estimation:
  - Minor
  - Moderate
  - Major
- Confidence score
- Clarifying questions for low-confidence results
- Manual category selection

Relevant code folders:

- `lib/features/customer_ticket/`
- `lib/features/ai_assist/`

## Group 3: Provider Reputation & Earnings Dashboard

### 7. Service Job Lifecycle

Manages the repair process after provider confirmation.

Main functions:

- Provider starts travel
- Customer tracks provider
- Provider check-in
- Problem inspection
- Diagnosis submission
- Repair estimate submission
- Customer estimate approval or rejection
- Repair work
- Provider completion request
- Customer completion confirmation

Relevant code folder: `lib/features/service_lifecycle/`

### 8. Simulated Payment

Demonstrates payment without processing real money.

Main functions:

- Payment screen
- Payment processing animation
- Simulated success or failure
- Payment record creation
- Ticket closure after successful payment

Relevant code folder: `lib/features/payment/`

### 9. Ratings & Reputation

Builds trust between customers and providers.

Main functions:

- Customer rates provider
- Provider rates customer
- Duplicate-rating prevention
- Average rating calculation
- Completed-job statistics
- Trust-score updates
- Reputation display

Relevant code folder: `lib/features/ratings/`

### 10. Provider Dashboard & Analytics

Helps providers understand their performance.

Main functions:

- Total earnings
- Acceptance rate
- Completion rate
- Cancellation rate
- Average rating
- Response time
- Arrival time
- Weekly jobs
- Monthly earnings
- Popular service categories
- Peak demand periods
- Trust Score

Relevant code folder: `lib/features/provider_dashboard/`

### 11. Reports, Safety & Dispute

Provides safety and moderation features.

Main functions:

- Report a provider or customer
- Select report reason
- Add description
- Upload evidence
- Assign severity
- Admin review
- Account restriction or suspension
- Dispute resolution
- SOS alert during an active service
- Admin safety notification

Relevant code folder: `lib/features/reports_safety/`

### 12. Admin Panel

Gives administrators centralized control over the platform.

Main functions:

- Admin authentication
- Provider verification review
- User management
- Ticket monitoring
- Matching-failure monitoring
- Complaint and dispute handling
- Safety-alert monitoring
- Account restriction or suspension
- Blacklist management
- Analytics dashboard
- Audit-event logging

Relevant code folder: `lib/features/admin_panel/`

## Complete project flow

`Authentication → Provider Verification → Ticket Creation → AI Classification → Geo-Broadcast → Trust-Gated Matching → Job Tracking → Inspection → Estimate Approval → Repair → Payment → Ratings → Analytics`

The detailed 12-module structure comes from [idea.md](./docs/idea.md:1), while the PPT groups them into three presentation modules.

> in this there are some things i dont want included in my project
>
> - Selfi Varification
> - Aadhar varification

Understood. **Aadhaar verification and selfie verification will be completely excluded from Fixwaala.**

The revised project modules are now:

1. Authentication & Role Management
2. Customer Ticket & Service Request
3. Fault Intelligence & AI Ticket Assist
4. Geo-Broadcast & Provider Discovery
5. Trust-Gated Matching
6. Service Job Lifecycle
7. Simulated Payment
8. Ratings & Reputation
9. Provider Dashboard & Analytics
10. Reports, Safety & Disputes
11. Admin Panel

Changes to the original scope:

- Remove the **Provider Identity & Selfie Verification** module.
- Remove Aadhaar and selfie APIs.
- Provider onboarding will use basic registration and skill selection.
- Admin will no longer approve identity verification.
- Trust-Gated Matching will show profile, skills, experience, ratings, reviews, distance, and ETA—but no Aadhaar or selfie status.
- The technology stack should no longer mention Aadhaar or selfie verification.

The three presentation groups become:

- **Member 1:** Geo-Broadcast and Trust-Gated Matching
- **Member 2:** Customer Ticket and AI Fault Assistance
- **Member 3:** Job Lifecycle, Payment, Ratings, Dashboard, Safety, and Admin Panel

> in this create a prompt to complete the member 3 module in complete with proper structured build and and ideation of proper UI/UX and user workflow

Use this prompt with your coding agent:

```text
Complete Member 3 of the Fixwaala project with a production-ready structure, clear UI/UX, and complete user workflows.

Project context:
Fixwaala is a Flutter + Firebase hyperlocal home-repair platform with Customer, Service Provider, and Admin roles.

Important exclusions:
- Do not implement Aadhaar verification.
- Do not implement selfie verification.
- Do not add identity-verification screens, APIs, database fields, or admin workflows.
- Provider registration should only include basic profile information, skills, location, availability, and contact details.

Member 3 scope:
1. Service Job Lifecycle
2. Simulated Payment
3. Ratings and Reputation
4. Provider Dashboard and Analytics
5. Reports, Safety, and Disputes
6. Admin Panel

First inspect the existing codebase, routing, models, theme, screens, and services. Reuse the existing architecture and visual style. Do not rewrite unrelated modules.

Implement the following complete workflow:

CUSTOMER WORKFLOW:
1. Customer confirms a provider.
2. Customer sees provider travel status.
3. Provider marks “En Route”.
4. Provider checks in after arrival.
5. Provider inspects the issue.
6. Provider submits diagnosis and repair estimate.
7. Customer reviews the estimate.
8. Customer can accept or reject the estimate.
9. If accepted, provider starts the repair.
10. Provider requests completion.
11. Customer confirms job completion.
12. Customer opens the simulated payment screen.
13. Payment succeeds or fails in a controlled demo flow.
14. Customer rates and reviews the provider.
15. Customer can report the provider or trigger SOS during an active job.
16. Ticket is closed after payment and rating completion.

PROVIDER WORKFLOW:
1. Provider views incoming and accepted jobs.
2. Provider accepts or rejects a request.
3. Provider updates status:
   - Accepted
   - En Route
   - Arrived
   - Checked In
   - Inspecting
   - Estimate Submitted
   - Work In Progress
   - Completion Requested
   - Completed
4. Provider enters diagnosis and estimate details.
5. Provider views active and completed jobs.
6. Provider views earnings, ratings, acceptance rate, completion rate, cancellation rate, response time, and arrival time.
7. Provider views performance trends, popular service categories, and peak demand.
8. Provider views an overall Trust Score calculated from ratings, completion rate, response time, and cancellations.

ADMIN WORKFLOW:
1. Admin logs in.
2. Admin views dashboard summary:
   - Active tickets
   - Completed jobs
   - Matching failures
   - Open reports
   - High-severity safety alerts
   - Suspended accounts
3. Admin monitors ticket and job status.
4. Admin reviews customer/provider reports.
5. Admin reviews dispute evidence.
6. Admin can mark a report as:
   - Open
   - Under Review
   - Resolved
   - Rejected
7. Admin can restrict, suspend, or restore accounts.
8. Admin can view audit events for important actions.
9. Do not include Aadhaar or selfie verification in the Admin Panel.

UI/UX requirements:
- Follow the existing Fixwaala theme and reusable widgets.
- Use clear status badges and progress indicators.
- Make the job lifecycle easy to understand visually.
- Use separate sections for active jobs, completed jobs, earnings, and performance.
- Provide loading, empty, success, failure, and error states.
- Add confirmation dialogs for estimate rejection, job completion, payment, reporting, and account suspension.
- Use readable cards, clear primary actions, and consistent navigation.
- Make customer actions different from provider actions.
- Prevent invalid actions based on the current job status.
- Display helpful messages when actions are unavailable.
- Provide responsive layouts for mobile and Flutter Web.
- Keep the interface simple enough for a first-time user.

Data and architecture:
- Create or complete models for jobs, job events, estimates, payments, ratings, reports, safety alerts, analytics, and audit events.
- Use service/repository classes rather than placing business logic directly inside widgets.
- Keep the code Firebase-ready.
- Use Firestore-style persistence where configured.
- If Firebase functionality is unavailable, provide deterministic demo data so the complete workflow can still be demonstrated.
- Ensure payment is simulated only; no real payment gateway is required.
- Prevent duplicate ratings for the same completed job and user.
- Validate all user inputs.
- Maintain role-based access control.
- Ensure customer addresses remain protected according to the existing trust-gated matching flow.

Expected screens:
Customer:
- Job Tracking Screen
- Inspection/Estimate Review Screen
- Completion Confirmation Screen
- Simulated Payment Screen
- Rating and Review Screen
- Report/Dispute Screen
- SOS Screen

Provider:
- Provider Dashboard
- Active Jobs Screen
- Job Details Screen
- Status Update Screen
- Inspection and Estimate Screen
- Earnings Summary Screen
- Performance Analytics Screen
- Rating and Trust Score Screen

Admin:
- Admin Dashboard
- Active Tickets Screen
- Reports and Disputes Screen
- Safety Alerts Screen
- Account Management Screen
- Audit Events Screen

Implementation requirements:
- Connect all screens through the existing router.
- Replace placeholder services and TODO implementations where necessary.
- Keep file naming and folder structure consistent with the existing project.
- Do not remove existing working functionality.
- Do not add Aadhaar, selfie verification, or unrelated features.
- Add validation for every state transition.
- Add tests for job state transitions, payment outcomes, duplicate-rating prevention, report status updates, and Trust Score calculation.
- Run formatting, static analysis, and relevant tests.
- Fix all compilation errors before finishing.

Final acceptance criteria:
- A complete customer-to-provider job can be demonstrated from confirmation to payment and ratings.
- Provider performance data is visible and logically calculated.
- Customers can report issues and trigger SOS.
- Admins can review reports and manage account restrictions.
- All screens have proper loading, empty, success, failure, and validation states.
- No Aadhaar or selfie verification appears anywhere in the implementation.
- The project builds successfully with Flutter.
```

This prompt focuses Member 3 on the complete post-matching experience while keeping Aadhaar and selfie verification out of scope.
