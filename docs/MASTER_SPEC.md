You are the lead product engineer, game systems designer, UX designer, and technical architect for a personal application called **FORGE**.

Your job is not to merely propose architecture or write a product plan.

Your job is to **build a working V1 of the product**, make reasonable decisions independently, test your work, and leave the repository in a runnable, documented state.

Do not over-engineer.
Do not spend excessive time discussing alternatives.
Do not stop after producing documentation.
Do not ask questions unless progress is genuinely impossible without an answer.

When information is ambiguous, choose the simplest robust solution consistent with this specification and document the choice.

---

# 1. PRODUCT MISSION

FORGE is a private personal operating system that turns real-life progress into a game.

The fundamental idea:

> Make improving real life more compelling than passive entertainment.

It combines:

- MMR / competitive ranking
- XP and levels
- RPG skill trees
- daily quests
- weekly boss fights
- monthly final bosses
- streaks
- reward currency
- automatic evidence
- Screen Time restrictions
- health tracking
- business tracking
- technical-skill progression
- analytics
- an AI Game Master

This is NOT primarily a habit tracker.

It is a **real-life progression engine**.

The product should reward measurable outcomes instead of fake productivity.

---

# 2. PRIMARY USER

A single local player.

The application is being built for personal use first.

Do NOT optimize V1 for thousands of users, social networks, teams, subscriptions, App Store growth, or monetization.

Optimize for:

1. usefulness
2. reliability
3. speed
4. daily retention
5. low friction
6. visual quality

---

# 3. EXAMPLE 12-MONTH OBJECTIVE

The following example defines the default scenario. Players can change it during onboarding:

> Reach at least **5,000,000 KZT monthly income within 12 months**, preferably through a business.

Priority order:

1. Business / money
2. Career / hard skills
3. Health / body
4. Social / network

Career is Plan B.

However, technical skills should preferably have **dual utility**:

- useful for building businesses
- valuable in the job market

Primary technical direction:

- Python
- backend engineering
- APIs
- databases
- AI engineering
- LLM applications
- automation
- system integration
- product building

Primary complementary high-leverage skills:

- sales
- communication
- execution
- analytical thinking
- discipline

Follow the Pareto principle.

Do NOT create a giant skill tree containing hundreds of low-value skills.

---

# 4. PRODUCT PHILOSOPHY

The application should make the user feel:

- "I am leveling up."
- "My rating matters."
- "I do not want to lose MMR."
- "I can see myself becoming stronger."
- "There is something meaningful waiting for me today."
- "My real life is progressing."
- "I want to beat yesterday's version of myself."

The application must NOT depend primarily on motivational quotes.

Motivation must come from:

- measurable progress
- scarcity
- competition
- progression
- unlocking
- consequences
- evidence
- visible outcomes

---

# 5. CORE PRODUCT LOOP

The main daily loop is:

1. Open FORGE.
2. See current Life MMR, rank, level, streak, Coins, and today's state.
3. Receive 3-5 intelligently selected quests.
4. Complete the highest-value real-world actions.
5. Provide evidence automatically where possible.
6. Gain XP / Coins / MMR.
7. Unlock optional entertainment.
8. See visible progress toward long-term goals.
9. Review the day.
10. Return tomorrow.

The app must remain useful even if AI is unavailable.

Game calculations must be deterministic in local code.

AI recommends and prioritizes.

AI must NOT control fundamental scoring rules.

---

# 6. PLATFORM STRATEGY

Build a native Apple application.

Target:

- iPhone
- macOS

Use:

- Swift
- SwiftUI
- SwiftData
- CloudKit/iCloud sync where practical
- async/await
- modern Apple APIs
- latest stable SDK installed locally
- avoid beta-only APIs

Prefer a shared Swift package/module containing:

- models
- game engine
- scoring logic
- quest logic
- analytics logic
- domain services

Platform-specific code should live behind protocols.

The application should be local-first.

Core functionality must work offline.

---

# 7. PRIVACY

This application contains personal data.

Default principles:

- local-first
- minimal external transmission
- explicit permissions
- no advertising
- no analytics SDK
- no selling data
- no hidden tracking

Sensitive values must use Keychain when appropriate.

Never hardcode API keys.

---

# 8. VISUAL DESIGN

Visual target:

**10/10 premium Apple-quality application with subtle gaming mechanics.**

Style:

- Apple minimalism
- clean
- dark/light mode
- spacious layouts
- high-quality typography
- premium animations
- restrained gradients
- subtle haptics
- strong data visualization
- no childish RPG aesthetic
- no cartoon avatars
- no clutter

Think:

Apple Fitness + Linear + premium finance dashboard + competitive ranking system.

Game mechanics should be emotionally strong but visually sophisticated.

Use system SF Symbols wherever appropriate.

Respect Reduce Motion.

Animations should be meaningful:

- XP gain
- level up
- rank promotion
- quest completion
- boss victory
- streak milestones

Do not use animation everywhere.

---

# 9. NAVIGATION

Create these main sections:

1. **Command Center**
2. **Quests**
3. **Progress**
4. **Skills**
5. **Settings**

On macOS, use a sidebar.

On iPhone, use a TabView or equivalent native navigation.

---

# 10. COMMAND CENTER

The home screen is the most important screen.

It should immediately answer:

- How am I doing?
- What matters today?
- Am I winning or losing?
- What should I do next?
- How much real progress have I made?

Display prominently:

### Life MMR
Example:

LIFE MMR  
1847  
PLATINUM II  
+42 this week

### Level
Example:

LEVEL 23  
AI BUILDER  
3,420 / 4,000 XP

### Current long-term objective

12-MONTH OBJECTIVE  
5,000,000 KZT / MONTH

Current monthly revenue:
XXX KZT

Progress bar.

### Domain ratings

Business
Builder
Health
Network

### Today's quests

Main Quest

Secondary Quest

Health Quest

Optional quests

### Coins

Entertainment balance.

### Current streak

### Today's momentum

Example:

Strong / Neutral / At Risk / Recovery Mode

### AI Game Master message

Maximum 2-4 short sentences.

No generic motivational fluff.

---

# 11. CORE DOMAINS

Initial Life MMR composition:

Business: 45%
Builder: 30%
Health: 20%
Network: 5%

Formula:

LifeMMR =
round(
BusinessMMR * 0.45 +
BuilderMMR * 0.30 +
HealthMMR * 0.20 +
NetworkMMR * 0.05
)

Make weights configurable in Settings.

Default each domain MMR to:

1000

Life MMR is derived.

Never update Life MMR independently.

---

# 12. RANK SYSTEM

Create rank tiers based on MMR.

Suggested starting structure:

0-899 — Iron  
900-1199 — Bronze  
1200-1499 — Silver  
1500-1799 — Gold  
1800-2099 — Platinum  
2100-2399 — Diamond  
2400-2699 — Master  
2700-2999 — Grandmaster  
3000+ — Apex

Keep thresholds configurable in a central GameConfig.

Show divisions where useful:

Gold III  
Gold II  
Gold I

etc.

Rank changes should have meaningful visual feedback.

---

# 13. XP SYSTEM

XP represents permanent accumulated development.

XP NEVER decreases.

MMR can decrease.
XP cannot.

XP sources:

- completed quests
- verified skill exercises
- projects
- boss fights
- milestones
- meaningful consistency

XP should NOT reward meaningless repetition indefinitely.

Use diminishing returns and/or caps for repetitive low-value tasks.

Create central XP configuration.

Do not scatter magic numbers throughout UI code.

---

# 14. LEVEL SYSTEM

Implement levels using XP.

The XP requirement should increase progressively.

Do NOT use a completely linear progression.

Use a simple predictable formula and isolate it inside GameEngine.

Example conceptual progression:

Level 1 -> easy
Level 10 -> meaningful commitment
Level 25 -> serious progress
Level 50 -> substantial long-term achievement
Level 100 -> exceptional

The exact formula can be adjusted later.

Implement unit tests.

---

# 15. MMR PHILOSOPHY

MMR measures current execution strength.

MMR CAN decrease.

It should react to approximately the last several weeks of behavior.

MMR should not be destroyed by a single bad day.

MMR should reward:

- completion of high-impact actions
- measurable outcomes
- difficult work
- consistency
- verified evidence

MMR should penalize:

- repeatedly abandoning important commitments
- intentional distraction during protected work
- consistently missing high-impact quests
- bypassing restrictions

Avoid extreme penalties.

The psychological target is:

"I want to recover my rating."

NOT:

"I have ruined everything, so I may as well quit."

---

# 16. DAILY PERFORMANCE ENGINE

Each quest has:

- id
- title
- description
- domain
- quest type
- priority
- difficulty
- impact score
- base XP
- Coin reward
- MMR weight
- evidence requirement
- status
- estimated duration
- deadline
- completion timestamp

Quest types:

- outcome
- skill
- health
- maintenance
- recovery
- boss
- optional

Priority levels:

- Main
- Secondary
- Supporting
- Optional

Never generate more than 3 mandatory quests by default.

Total visible quests should generally stay between 3 and 5.

Outcome-based quests are preferred over time-based quests.

Bad:

"Study Python for 2 hours."

Better:

"Implement authentication endpoint and pass the tests."

Time-based quests are acceptable where output is naturally difficult to define.

---

# 17. EVIDENCE ENGINE

Every quest has an evidence confidence.

Possible evidence sources:

- automatic integration
- Git commit
- coding activity
- Apple Health
- Device Activity
- calendar event
- timer
- manual confirmation
- external metric
- revenue entry
- customer record

Represent evidence as structured records.

Suggested confidence:

Automatic verified: 1.0

Strong local evidence: 0.9

Timer + app activity: 0.8

Manual evidence: 0.6

Never reject manually completed real work merely because integration is unavailable.

Instead lower verification confidence.

Display confidence subtly.

---

# 18. BUSINESS SYSTEM

Business is the highest-priority domain.

The Business screen should track:

- monthly revenue
- target revenue
- paying customers
- qualified leads
- customer conversations
- demos
- proposals
- outreach
- products shipped
- current bottleneck
- sales pipeline

The business scoring hierarchy is:

1. Revenue
2. Paying customers
3. Customer conversations
4. Qualified outreach
5. Product shipped
6. Learning

Learning alone must generate very little Business MMR.

Do NOT reward the user heavily for consuming business content.

Example philosophy:

Watching a sales video:
small XP

Sending qualified outreach:
meaningful XP

Talking to an actual customer:
large XP/MMR

Receiving money:
very large outcome milestone

Use caps so that sending hundreds of low-quality messages cannot farm infinite MMR.

Revenue milestones should strongly affect progress.

Allow manual revenue entry in V1.

Fields:

- amount
- currency
- client
- source
- date
- recurring/non-recurring
- optional note

Currency default:
KZT

---

# 19. BUSINESS QUEST EXAMPLES

Good:

- Send 10 personalized messages to qualified leads.
- Speak with one decision maker.
- Send a proposal to client X.
- Ship working demo.
- Ask 5 prospects about their current workflow.
- Collect payment.
- Close first recurring customer.

Bad:

- Think about business.
- Research startups for three hours.
- Watch entrepreneurship videos.
- Perfect the logo.

AI should actively detect fake productivity.

---

# 20. BUILDER / CAREER SYSTEM

Create a compact high-value skill tree.

Initial categories:

### Python
- fundamentals
- data structures
- functions
- modules
- errors
- OOP
- typing
- testing
- async

### Backend
- HTTP
- REST
- FastAPI or current equivalent
- authentication
- validation
- APIs
- background jobs
- testing
- deployment

### Databases
- SQL
- PostgreSQL
- schema design
- indexes
- transactions

### AI Engineering
- LLM API usage
- structured outputs
- tool use
- retrieval
- embeddings
- evaluation
- agents/workflows
- safety/reliability
- observability

### Automation / Integration
- n8n
- webhooks
- third-party APIs
- queues
- CRM integration

### Product Engineering
- Git
- GitHub
- architecture
- debugging
- deployment
- telemetry

### Sales
Keep this smaller but visible.

---

# 21. SKILL MASTERY

A skill cannot be mastered by merely spending time.

Skill states:

Locked
Learning
Practicing
Test Ready
Verified
Mastered

Mastery requires some combination of:

- quiz
- practical exercise
- debugging
- independent implementation
- project evidence
- Boss Fight

The app should support prerequisites.

Example:

Python Fundamentals
↓
Functions
↓
Modules
↓
Backend Fundamentals
↓
FastAPI
↓
Production API

Represent the graph in structured data.

Do not hardcode the whole tree into views.

---

# 22. HEALTH SYSTEM

Initial tracked health metrics:

- sleep duration
- sleep consistency
- wake time
- workouts
- steps
- cardio
- weight
- water
- Screen Time

Use Apple Health on supported devices with permission.

Do NOT attempt to access Apple Health data from macOS.

Sync relevant derived health summaries to Mac through the app's own data model.

Health should reward consistency.

Do not punish reasonable rest days.

Support planned rest.

Avoid medical diagnosis or medical recommendations.

---

# 23. HEALTH LEVEL DISPLAY

Show a Health rating plus components:

Sleep
Strength
Cardio
Activity
Recovery

Example:

HEALTH  
MMR 1720  
Gold I

Sleep 78  
Strength 64  
Cardio 59  
Activity 81

These can initially be normalized scores from 0-100.

Keep formulas centralized and explainable.

---

# 24. COINS / REWARD ECONOMY

Coins are earned by meaningful action.

Coins are spent on optional entertainment.

Default example reward costs:

30 minutes YouTube: 30 Coins

20 minutes Instagram: 35 Coins

1 Dota match: 80 Coins

Gaming evening: 200 Coins

These values MUST be configurable.

Coins should not be purchasable with money.

Coins cannot be farmed infinitely through tiny repetitive tasks.

Add daily earning caps for low-impact actions.

Main Quest completion should be one of the strongest daily Coin sources.

---

# 25. SCREEN TIME / DISTRACTION CONTROL

On iPhone, design an integration using Apple's supported Screen Time frameworks where entitlements are available:

- FamilyControls
- ManagedSettings
- DeviceActivity

Request individual authorization.

Allow the user to choose distracting apps/categories.

Examples:

- Instagram
- YouTube
- browsers
- other selected apps

Support modes such as:

### Focus Lock
Apps blocked during protected work sessions.

### Earned Access
Apps blocked until the user spends Coins.

### Daily Limit
Restrict usage after configurable thresholds.

Never use private APIs.

Never pretend restrictions are impossible to bypass.

If the user intentionally bypasses or revokes restrictions:

- record a bypass event
- show it in analytics
- optionally apply configurable MMR/Coin consequences

Always provide a safe emergency override.

Emergency override should require friction, for example:

1. press Override
2. show consequence
3. wait configurable delay
4. enter reason
5. confirm

Do not create dangerous lockouts.

For macOS V1:

Do NOT invent unsupported Screen Time APIs.

Focus first on tracking / workflow / optional local focus mechanisms that use public APIs.

Architect Mac distraction blocking behind a protocol for future implementation.

---

# 26. RECOVERY MODE

This feature is essential.

A bad morning must NOT automatically destroy the entire day.

Trigger Recovery Mode when appropriate, for example:

- major quests untouched late into the day
- distraction usage unusually high
- repeated abandonment
- user manually requests recovery

Recovery Mode should shrink the challenge.

Example:

Normal Main Quest:

"Implement authentication API."

Recovery Quest:

"Open project, implement one endpoint, run tests. 25 minutes maximum."

Completing Recovery Mode:

- does not give full normal rewards
- reduces or prevents part of the day's MMR loss
- preserves momentum
- counts as a comeback

Core philosophy:

Bad early game != game over.

---

# 27. STREAKS

Have multiple streaks rather than one fragile streak.

Examples:

Execution Streak
Training Streak
No-Zero-Day Streak
Main Quest Streak

Missing one optional action should not destroy everything.

Allow planned rest days.

Do not make streaks the central metric.

MMR and real outcomes matter more.

---

# 28. GHOST COMPETITOR

Create a feature called **Ghost**.

The user's primary competitor is their previous best self.

Examples:

Best 7-day MMR gain:
+142

Current:
+101

41 points behind your personal record.

Or:

This week:
14 meaningful actions

Best week:
19

Ghost gives competitive pressure without requiring social networking.

V1 can derive Ghost data from historical best periods.

---

# 29. WEEKLY BOSS

Once per week, generate or assign a Boss Fight.

A Boss Fight must test capability or create a meaningful external outcome.

Examples:

Builder:
Build and deploy a small API independently.

Business:
Book a conversation with a qualified decision maker.

Health:
Complete a measurable planned physical challenge.

Bosses have:

- title
- objective
- domain
- difficulty
- proof
- reward
- deadline

Boss rewards should be materially larger than normal quests.

---

# 30. MONTHLY FINAL BOSS

Every approximately 30 days, define a major outcome.

Examples:

- deploy a complete usable project
- acquire paying customer
- ship business MVP
- achieve measurable fitness milestone

The monthly boss should be linked to the 12-month objective.

Display previous monthly bosses as a history/trophy section.

---

# 31. AI GAME MASTER

AI Game Master is central, but the app must function without it.

AI responsibilities:

- review current goals
- analyze recent execution
- inspect unfinished work
- identify bottlenecks
- propose daily quests
- propose Recovery Quests
- propose weekly Boss Fight
- summarize weekly progress
- detect fake productivity
- recommend deleting low-value tasks
- recommend priority changes
- explain why today's Main Quest matters

AI must be:

- concise
- strict
- rational
- specific
- evidence-based

Avoid:

- motivational clichés
- fake praise
- excessive empathy
- long speeches

Example:

"Your bottleneck is not coding. You spent 7.2 hours building this week and contacted only four prospects. Today's Main Quest is 10 qualified outreach attempts before additional product work."

That is the intended tone.

---

# 32. AI AUTHORITY

AI may:

- recommend
- prioritize
- generate quests
- suggest plan modifications
- suggest skill tests
- suggest recovery mode

AI may NOT silently change:

- long-term goals
- domain weights
- revenue target
- scoring configuration
- restrictions
- saved user preferences

For meaningful changes, present a proposal.

---

# 33. AI ARCHITECTURE

Create an abstraction:

AIService

Methods can include:

- generateDailyPlan(...)
- analyzeBottleneck(...)
- generateRecoveryQuest(...)
- generateWeeklyBoss(...)
- summarizeWeek(...)

Implement:

1. MockAIService
2. RemoteAIService

Core app should compile and work using MockAIService.

RemoteAIService should call a configurable backend endpoint.

Do NOT store a provider API secret in the mobile application.

Create a minimal server-side proxy/template in a separate server directory if appropriate.

Use the current OpenAI Responses API through the backend implementation, but keep the app-level architecture provider-agnostic.

Use structured JSON responses.

Validate all model output.

Never trust arbitrary model output to mutate the database directly.

---

# 34. AI INPUT CONTEXT

Do NOT send the entire database to AI.

Construct a compact context object.

Example:

- primary goal
- active season objective
- domain MMR
- 7-day performance
- 30-day performance
- unfinished quests
- today's calendar
- health summary
- recent screen-time summary
- current skills
- business pipeline summary
- current bottleneck
- recent failures
- recent wins

Keep prompts efficient.

---

# 35. ANALYTICS

Progress view must make improvement undeniable.

Show:

Today
7 days
30 days
90 days
All time

Core charts:

Life MMR
Business MMR
Builder MMR
Health MMR
Revenue
Main Quest completion
Deep work / coding activity
Screen Time
Sleep
Workouts

Also show:

### 30 DAYS AGO → TODAY

Example:

Revenue
0 → 350,000 KZT

Builder MMR
1000 → 1382

Screen Time
8h 20m → 5h 10m

Workouts
5 → 13

Main Quest completion
42% → 78%

The goal is to show evidence that real life changed.

---

# 36. "REAL LIFE ROI" PANEL

Create a powerful summary:

TIME INVESTED
↓

OUTPUT CREATED
↓

REAL RESULTS

Example:

42 hours invested

3 projects shipped

87 qualified outreach attempts

11 customer conversations

2 customers

350,000 KZT revenue

This is more important than superficial streaks.

---

# 37. DAILY REVIEW

At the end of the day, allow a review taking less than 60 seconds.

Questions:

What moved forward?

What blocked you?

Was today's Main Quest correct?

Energy:
1-5

Day rating:
1-5

Optional note.

AI can use the review tomorrow.

Do not require long journaling.

---

# 38. BAD DAY LOGIC

If the user has a bad day:

Do not display shame.

Do display consequences accurately.

Example:

"MMR -14"

"Main Quest missed."

"4h 12m distraction during protected window."

Then immediately:

"Recovery available."

The system should be strict without becoming self-defeating.

---

# 39. INITIAL DAILY QUEST GENERATION

For V1, before remote AI is configured, create deterministic templates.

At first launch, seed example quests based on current objectives.

Business Main Quest examples.

Builder Secondary Quest examples.

Health Quest examples.

Allow manual creation/editing.

AI-generated quests can replace templates later.

---

# 40. CALENDAR

Use EventKit where appropriate.

With permission, read today's calendar.

Use events to:

- avoid scheduling impossible quests
- understand available work windows
- display commitments

Do not automatically create calendar events without explicit user action.

---

# 41. GITHUB

Create an integration abstraction.

Eventually track:

- commits
- repositories
- coding streak
- PRs where useful

For V1, prioritize a reliable implementation over OAuth complexity.

A personal token stored securely in Keychain or local repository observation on macOS is acceptable for personal-use development.

Do not expose secrets.

GitHub activity should provide evidence.

Do not equate number of commits with productivity.

A single meaningful commit can be more valuable than 20 trivial commits.

---

# 42. VS CODE ACTIVITY

Architect a future integration for coding activity.

Preferred approach:

- lightweight VS Code extension OR
- local companion service

Track:

- active coding duration
- project/repository
- session start/end

Do NOT record source-code contents or keystrokes.

Privacy first.

V1 may ship without the extension if core loop is working.

Create protocol and integration placeholder.

---

# 43. N8N

Allow n8n activity to enter the system through a secure webhook or simple integration.

Potential events:

workflow created
workflow updated
workflow executed
production automation deployed

Do not make n8n integration a blocker for V1.

---

# 44. LEETCODE

Create integration abstraction only.

Do not build a brittle scraper in the core app.

Manual evidence is acceptable initially.

If a stable supported integration is unavailable, defer automatic syncing.

---

# 45. SCREEN TIME DATA

Where Apple's supported APIs permit it, expose useful privacy-preserving usage summaries.

Do not attempt to exfiltrate protected per-app data in unsupported ways.

Respect Apple's privacy model.

The system should gracefully function when permissions are denied.

---

# 46. DATA MODEL

Create robust SwiftData models or equivalent structures for at least:

UserProfile
Goal
Domain
Quest
QuestEvidence
DailySnapshot
MMRSnapshot
XPTransaction
CoinTransaction
RevenueEntry
Customer
BusinessActivity
Skill
SkillEdge
SkillProgress
BossFight
Streak
Reward
ScreenTimeRule
RecoverySession
DailyReview
IntegrationStatus
AIRecommendation
Season

Use UUID identifiers.

Prefer explicit enums.

Support schema evolution.

Avoid giant god objects.

---

# 47. TRANSACTION LOG

For XP, Coins, and meaningful MMR changes, maintain an append-only transaction/history record.

Examples:

+80 XP
Quest completed

+45 Coins
Main Quest

Business MMR +12
Customer conversation

Coins -80
Dota reward

This allows debugging and prevents mysterious values.

---

# 48. GAME ENGINE

Create a pure testable GameEngine.

Responsibilities:

- XP calculation
- level calculation
- rank calculation
- domain MMR calculation
- Life MMR calculation
- Coin rewards
- penalties
- streak evaluation
- Recovery Mode outcome
- quest reward calculation

It should NOT depend on SwiftUI.

Write unit tests.

Centralize tunable constants inside GameConfig.

---

# 49. INITIAL MMR UPDATE MODEL

Implement a transparent V1 formula.

For each domain/day calculate:

performanceScore between 0.0 and 1.25

based on weighted planned quests and verified outcomes.

Suggested neutral target:
0.65

Base delta:

round(50 * (performanceScore - 0.65))

Clamp normal daily delta approximately:

-35 ... +30

Then apply small limited outcome bonuses for unusually meaningful real outcomes.

Do NOT allow infinite farming.

Business revenue/customer milestones may receive additional bounded bonuses.

Recovery Mode may reduce a negative daily delta but should not create a major positive result.

Keep all parameters configurable.

Write tests for:

perfect day
average day
bad day
recovery day
no planned work
rest day
outcome bonus

---

# 50. NO-ZERO-DAY SYSTEM

A zero day is not simply "didn't finish everything."

A zero day means:

No meaningful progress in any primary domain when progress was realistically possible.

A 25-minute Recovery Quest can convert a zero day into a recovery day.

Do not reward it like a strong day.

But preserve momentum.

---

# 51. ONBOARDING

Make onboarding concise.

Collect:

Name
12-month income target
Current monthly revenue
Main objective
Domain weights
Typical wake time
Typical sleep time
Primary work window
Preferred training frequency
Selected distraction apps
Reward preferences
Strictness
AI tone

Seed defaults from this specification.

The user should reach Command Center quickly.

Do not create a 25-screen onboarding flow.

---

# 52. DEFAULT USER CONFIGURATION

Use these defaults:

Target monthly income:
5,000,000 KZT

Primary objective:
Build own business.

Priority:
Business > Builder > Health > Network

Strictness:
High

AI tone:
Strict rational coach

Visual intensity:
High

Animation level:
8/10

Daily mandatory quests:
AI-selected, normally 3

Business weight:
45%

Builder:
30%

Health:
20%

Network:
5%

Reward types:
Gaming
YouTube
Instagram
Rest
Status/rank

Distractions:
browser wandering
pornography
daytime sleeping
YouTube
Instagram

Do not create explicit pornography-tracking details in UI unless the user manually configures a custom behavior.

A generic "Avoided distraction" or user-defined restricted website/app system is sufficient.

---

# 53. REWARDS

Create configurable reward definitions.

Examples:

Dota Match
Cost: 80 Coins
Duration: configurable

YouTube
Cost: 30 Coins
Duration: 30 minutes

Instagram
Cost: 35 Coins
Duration: 20 minutes

Free Evening
Cost: configurable

Rewards may trigger temporary unshielding on iPhone if the relevant APIs and permissions are available.

Log reward redemptions.

---

# 54. SETTINGS

Settings must expose:

Domain weights
MMR rules
Coin economy
Reward costs
AI endpoint
AI enabled/disabled
Health permissions
Calendar permissions
Screen Time permissions
GitHub configuration
Notifications
Animations
Sound
Haptics
Strictness
Data export
Reset options

Do not hide important scoring rules.

The user should understand why a score changed.

---

# 55. NOTIFICATIONS

Use notifications sparingly.

Useful examples:

Morning:
"Today's Main Quest is ready."

At-risk:
"Main Quest untouched. Recovery Mode is available."

Reward:
"You earned enough Coins for one Dota match."

Boss:
"Weekly Boss expires tonight."

No motivational spam.

No notification every hour.

---

# 56. ERROR STATES

The app must gracefully handle:

- no network
- CloudKit unavailable
- AI unavailable
- Health permission denied
- Calendar permission denied
- Screen Time authorization denied
- GitHub unavailable
- corrupted external response
- first launch with no data

Never show a blank screen.

Never make AI availability a requirement for opening the app.

---

# 57. ACCESSIBILITY

Use semantic accessibility labels.

Support Dynamic Type where reasonable.

Support VoiceOver.

Respect Reduce Motion.

Maintain strong contrast.

---

# 58. TESTING

Create tests for the GameEngine.

At minimum test:

XP calculation
level progression
rank thresholds
Life MMR weights
MMR gain/loss
Recovery Mode
reward redemption
Coin balance
streak logic
business outcome caps
rest day behavior

Where feasible, add UI smoke tests for:

launch
onboarding
quest completion
Command Center rendering

---

# 59. SAMPLE DATA

Create rich preview/demo data.

It should demonstrate:

- multiple ranks
- revenue growth
- recent quests
- health trends
- skills
- boss fight
- Ghost comparison

Preview/demo data must not pollute real user data.

---

# 60. DEVELOPMENT PHASES

Work in this order.

## PHASE 0 — Repository and documentation

Create:

README.md
PRODUCT.md
ARCHITECTURE.md
GAME_RULES.md
ROADMAP.md

Then immediately begin implementation.

Do not stop here.

---

## PHASE 1 — Core Engine

Implement:

models
GameConfig
GameEngine
XP
levels
MMR
ranks
Coins
quests
streaks
Recovery Mode
transaction logs
unit tests

This phase must compile before continuing.

---

## PHASE 2 — Usable Local App

Implement:

onboarding
Command Center
Quest list
quest creation
quest completion
Progress page
skill tree
business revenue entry
daily review
settings

Persist locally.

At the end of Phase 2 the app must be genuinely usable every day even with no integrations.

---

## PHASE 3 — iCloud Sync

Add SwiftData/CloudKit sync appropriately.

Handle sync errors safely.

Do not compromise the local-first experience.

---

## PHASE 4 — Apple Integrations

Add where supported:

Health
Calendar
Screen Time

Use public APIs only.

Permission denial must not break the app.

---

## PHASE 5 — AI Game Master

Implement AIService protocol.

Add deterministic/mock AI.

Add remote AI through backend endpoint.

Structured output only.

Add:

daily plan
bottleneck analysis
recovery quest
weekly review
weekly boss

---

## PHASE 6 — Automatic Evidence

Add prioritized integrations:

GitHub
coding activity architecture
n8n webhook
other evidence sources

Only after core loop is solid.

---

## PHASE 7 — Polish

Animations
haptics
sound
charts
rank-up screen
boss victory
performance
accessibility
visual refinements

---

# 61. V1 SCOPE DISCIPLINE

V1 MUST NOT contain:

- social feed
- multiplayer
- chat between users
- marketplace
- subscriptions
- public profiles
- complicated avatars
- crypto
- NFTs
- complex achievements catalog
- 100 integrations
- arbitrary AI agents
- enterprise backend
- microservices

Single user.

One excellent loop.

---

# 62. DEFINITION OF A SUCCESSFUL V1

V1 succeeds if the user can use it for 30 days and answer:

"What should I do today?"

"What matters most?"

"Am I improving?"

"Did I actually create value?"

"What is my current rating?"

"What did I earn?"

"What happens if I waste the day?"

"Can I recover after a bad start?"

"What changed in my real life over the last 30 days?"

without needing another productivity system.

---

# 63. CORE ACCEPTANCE TEST

On a fresh install:

1. Complete onboarding.
2. See Life MMR = approximately starting value.
3. See rank.
4. See level.
5. See 3 daily quests.
6. Complete one quest.
7. XP increases.
8. Coins increase.
9. Transaction appears.
10. Domain MMR updates according to rules.
11. Life MMR recalculates.
12. Progress graph reflects history.
13. Add revenue entry.
14. Business dashboard updates.
15. Skill progress can be updated.
16. Daily review can be completed.
17. Recovery Mode can be triggered.
18. Application survives relaunch.
19. Mac and iPhone interfaces both render correctly.
20. Core workflow works without AI.

---

# 64. PRODUCT QUALITY BAR

Do not accept:

- placeholder UI everywhere
- broken navigation
- fake integrations presented as working
- buttons that do nothing
- unhandled exceptions
- massive files
- spaghetti state management
- duplicate scoring logic
- arbitrary magic numbers
- important calculations inside Views

Use clean boundaries.

Prefer understandable code over clever code.

---

# 65. IMPLEMENTATION BEHAVIOR

While working:

1. Inspect the existing repository/environment first.
2. Determine what is already installed.
3. Create the smallest appropriate architecture.
4. Implement one vertical slice early.
5. Build/run tests frequently.
6. Fix compiler errors immediately.
7. Keep the project runnable.
8. Make commits/logical checkpoints if git is available.
9. Update ROADMAP.md as work progresses.
10. Document unfinished integrations honestly.

If a capability requires an entitlement or external credential:

- implement the code architecture
- add setup instructions
- provide graceful fallback
- continue with the rest of the product

Do not halt the entire build.

---

# 66. FIRST VERTICAL SLICE

The first working slice should be:

User opens app
↓
Command Center appears
↓
Life MMR / Rank / Level visible
↓
Three quests visible
↓
User completes Main Quest
↓
completion animation
↓
XP increases
↓
Coins increase
↓
MMR changes
↓
transaction recorded
↓
dashboard updates

Build this before advanced integrations.

---

# 67. GAME BALANCING PRINCIPLE

Do not spend days attempting perfect game balance before usage data exists.

Implement centralized configurable rules.

Seed sensible defaults.

The product will be balanced after real usage.

Optimize V1 for:

clarity
feedback
meaning
consistency

not mathematical perfection.

---

# 68. ONE CRITICAL RULE

Never let FORGE reward the illusion of progress more than real progress.

If the user spends:

3 hours watching courses
and
0 minutes producing output,

the app should reflect that accurately.

If the user spends:

45 minutes
and
gets a real customer conversation,

that may be a much better day.

The game must train the user to pursue leverage.

---

# 69. SECOND CRITICAL RULE

FORGE should not become another procrastination project.

Do not let the user endlessly customize:

colors
badges
avatars
skill icons
complex rules

before doing real work.

Customization should be limited.

The product must push attention OUTSIDE the app into real life.

Ideal usage:

Open FORGE
↓
Know what matters
↓
Close FORGE
↓
Do the work
↓
Return with evidence

---

# 70. FINAL INSTRUCTION

Begin implementation now.

Do not reply with only a proposed plan.

First inspect the development environment and repository.

Then create the project structure if needed.

Create the documentation files.

Implement the GameEngine and first vertical slice.

Run the build/tests.

Fix errors.

Continue until there is a runnable V1 foundation.

When forced to choose between:

more features

and

a reliable addictive core loop,

choose the reliable core loop.

The highest-priority product outcome is:

> The user opens FORGE every day because progressing in real life visibly feels like progressing in a competitive game.