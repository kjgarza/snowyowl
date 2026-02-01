# Feature Research

**Domain:** Dual-mode automation systems (task execution + phase-based workflow)
**Researched:** 2026-02-01
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Environment variable mode switching | Standard daemon configuration pattern; systemd uses EnvironmentFile, Docker uses Environment directives | LOW | Single `SNOWYOWL_MODE` variable; no config file changes needed |
| Mode isolation (separate execution paths) | Each mode has different scanning logic, readiness criteria, and execution commands | MEDIUM | Shared infrastructure (worktree, PR, git) but isolated mode-specific modules |
| Readiness detection without AI invocation | File system scanning standard for daemon automation; polling hundreds of repos with Claude would be expensive/slow | MEDIUM | Deterministic file presence checks; no LLM needed |
| Unattended overnight execution | RPA/automation systems run 24/7 "lights out" mode; SnowyOwl's core value proposition | MEDIUM | Requires timeout handling, state saving on interruption |
| Sequential phase ordering | DAG workflows ensure dependencies resolved before next step; prevents out-of-order execution | MEDIUM | Phase N+1 only after phase N complete (all PLAN.md have SUMMARY.md) |
| PR creation with phase summaries | GitHub integration already exists for TASKS mode; users expect same delivery mechanism | LOW | Reuse existing PR infrastructure; extract SUMMARY.md content for body |
| Dry-run mode | Standard for automation systems; allows testing without side effects | LOW | Already exists in TASKS mode; extend to GSD mode |
| Comprehensive logging | Debugging overnight runs impossible without detailed logs | LOW | Already exists; extend with GSD-specific events |
| Graceful failure handling | Automation systems must handle network errors, timeouts, API limits without data loss | HIGH | Save state on timeout via `/gsd:pause-work`; resume via `/gsd:resume-work` |
| Prerequisite validation | Fail-fast if Claude Code CLI or GSD skills unavailable | LOW | Separate from TASKS mode prerequisites; check for `/gsd:*` availability |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Dual-mode architecture (TASKS + GSD coexist) | Users don't have to choose; TASKS for simple automation, GSD for planned phases | MEDIUM | Clean mode separation prevents feature creep; environment variable toggle simple |
| File system signal-based readiness (no Claude scanning) | Fast startup; scalable to hundreds of repos; deterministic behavior | LOW | PLAN.md exists + no SUMMARY.md = ready |
| Automatic phase chaining | If phases 1-3 planned during day, SnowyOwl runs all three overnight | MEDIUM | Re-scan after each completion; stop when next phase needs human |
| Shared worktree infrastructure | Reuse battle-tested isolation pattern from TASKS mode | LOW | DRY principle; avoids duplicating complex git worktree logic |
| Skip interactive commands | Only runs autonomous GSD commands (`execute-phase`, `resume-work`, `pause-work`) | LOW | Prevents overnight runs from hanging on user input prompts |
| Yolo mode enforcement | Config validation before execution; prevents hanging on interactive prompts | LOW | Check `.planning/config.json` mode field; skip repos not in "yolo" |
| Resume interrupted sessions | If previous overnight run timed out, automatically resume from `.continue-here` marker | MEDIUM | Check for marker file before `execute-phase`; call `/gsd:resume-work` first |
| Parallel repo execution (not phase) | Multiple repos can execute concurrently; phases within repo sequential | HIGH | Bounded parallelism (`GSD_MAX_PARALLEL`); prevents resource exhaustion |
| Phase limit per repo | Don't run more than N phases per repo overnight; prevents runaway execution | LOW | `GSD_MAX_PHASES_PER_REPO` config; safety valve |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic verification after execution | "Why not verify overnight too?" | Verification is inherently interactive (`/gsd:verify-work`); tests may require browser, databases, services; UAT requires human judgment | Human reviews PR next morning; runs verification interactively on PR branch |
| Parallel phase execution within repo | "Speed up execution by running phases 1+2+3 simultaneously" | Phases have dependencies; phase 2 requires phase 1 foundation; violates GSD sequential model | Phase chaining (automatic advance to next ready phase) achieves speed without breaking dependencies |
| AI-based readiness detection | "Use Claude to analyze if phase is ready" | Slow (invoke Claude per phase); expensive (hundreds of API calls); non-deterministic; file system signals already deterministic | File presence checks: PLAN.md exists, no SUMMARY.md, previous phase complete |
| Automatic planning | "SnowyOwl should plan phases overnight too" | Planning requires research, architecture decisions, human preferences; `/gsd:plan-phase` and `/gsd:discuss-phase` are interactive | Human plans during day; SnowyOwl executes overnight |
| Single unified mode | "Why have two modes? Just detect TASKS.md vs .planning/" | Mode mixing creates complexity; TASKS and GSD have fundamentally different execution models; environment variable toggle cleaner | Explicit mode selection via `SNOWYOWL_MODE`; users opt-in per environment |
| Real-time progress notifications | "Send webhook/Slack every time phase completes" | Creates notification fatigue; overnight runs = batch work; morning PR is the notification | Single summary webhook at completion (optional); PR notification via GitHub |
| Automatic merging after verification | "If tests pass, merge the PR" | Verification still needs human review; automated tests don't cover all cases; user may want to review code | Human merges PR after verification; keeps human in loop for quality gate |
| Interactive mode switching | "Add `/snowyowl:switch-mode` command" | Mode switching during execution dangerous; environment variable already exists; launchd/cron set environment | Set mode via environment variable in config or launchd plist |

## Feature Dependencies

```
[Mode Switching]
    └──requires──> [Mode Isolation]
                       └──requires──> [Shared Infrastructure]

[Readiness Detection]
    └──requires──> [Yolo Mode Enforcement]

[Sequential Ordering]
    └──requires──> [Readiness Detection]
                       └──enables──> [Phase Chaining]

[Unattended Execution]
    └──requires──> [Skip Interactive Commands]
    └──requires──> [Graceful Failure Handling]
                       └──requires──> [Resume Interrupted Sessions]

[PR Creation]
    └──requires──> [Shared Infrastructure]
    └──enhances──> [Comprehensive Logging]

[Parallel Repo Execution]
    └──requires──> [Shared Worktree Infrastructure]
    └──requires──> [Phase Limit Safety Valve]
```

### Dependency Notes

- **Mode Switching requires Mode Isolation:** Environment variable only works if execution paths cleanly separated (TASKS mode vs GSD mode)
- **Readiness Detection enables Phase Chaining:** Once we can detect "next phase ready", we can automatically advance
- **Unattended Execution requires Skip Interactive Commands:** Overnight runs hang forever if they hit interactive prompts
- **Graceful Failure Handling requires Resume:** Timeouts inevitable in long-running work; must save state and resume
- **Parallel Repo Execution conflicts with Parallel Phase Execution:** Can parallelize across repos OR within repo, not both; across repos safer

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] **Mode Switching** — Environment variable `SNOWYOWL_MODE=gsd` or `tasks`; essential for dual-mode architecture
- [ ] **Readiness Detection** — File system scanning for PLAN.md, SUMMARY.md, config.json yolo mode; core GSD integration
- [ ] **Sequential Phase Ordering** — Phase N+1 only after phase N complete; prevents dependency violations
- [ ] **Skip Interactive Commands** — Only run `/gsd:execute-phase`, `/gsd:resume-work`, `/gsd:pause-work`; prevents hangs
- [ ] **Unattended Execution** — Run via launchd/cron without human oversight; core value proposition
- [ ] **PR Creation** — Reuse existing worktree + PR infrastructure; delivery mechanism
- [ ] **Comprehensive Logging** — Extend existing logs with GSD events; debugging necessity
- [ ] **Yolo Mode Enforcement** — Skip repos not in yolo mode; prevents interactive prompts
- [ ] **Graceful Failure** — Save state on timeout via `/gsd:pause-work`; data loss prevention

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Phase Chaining** — Automatically advance to next ready phase after completion; efficiency improvement (trigger: users plan multiple phases, want all executed)
- [ ] **Resume Interrupted Sessions** — Check for `.continue-here`, call `/gsd:resume-work`; robustness (trigger: overnight timeouts observed)
- [ ] **Parallel Repo Execution** — Run multiple repos concurrently with `GSD_MAX_PARALLEL`; throughput (trigger: users have 5+ repos, want faster completion)
- [ ] **Phase Limit Safety Valve** — `GSD_MAX_PHASES_PER_REPO` config; prevents runaway (trigger: phase chaining enabled, need safety)
- [ ] **Dry-run for GSD Mode** — Test readiness detection without execution; testing tool (trigger: users want to verify before scheduling)

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Parallel Phase Execution** — Run independent phases simultaneously; complex dependency analysis (defer: MVP validates sequential model first)
- [ ] **Progress Webhooks** — Notify on completion via webhook; nice-to-have (defer: PR notification sufficient for MVP)
- [ ] **Interactive Verification** — Run `/gsd:verify-work` in headless mode with mocked inputs; complex (defer: human verification is feature, not bug)
- [ ] **Multi-mode Support** — Run TASKS and GSD modes in same overnight session; complexity (defer: users can run sequentially, or use two launchd jobs)
- [ ] **Auto-merge on Success** — Merge PR if verification passes; quality risk (defer: human review is safety gate)

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Mode Switching | HIGH | LOW | P1 |
| Readiness Detection | HIGH | MEDIUM | P1 |
| Sequential Ordering | HIGH | MEDIUM | P1 |
| Skip Interactive Commands | HIGH | LOW | P1 |
| Unattended Execution | HIGH | MEDIUM | P1 |
| PR Creation | HIGH | LOW | P1 |
| Comprehensive Logging | HIGH | LOW | P1 |
| Yolo Mode Enforcement | HIGH | LOW | P1 |
| Graceful Failure | HIGH | HIGH | P1 |
| Phase Chaining | MEDIUM | MEDIUM | P2 |
| Resume Interrupted | MEDIUM | MEDIUM | P2 |
| Parallel Repo Execution | MEDIUM | HIGH | P2 |
| Phase Limit Safety | MEDIUM | LOW | P2 |
| Dry-run GSD Mode | MEDIUM | LOW | P2 |
| Parallel Phase Execution | LOW | HIGH | P3 |
| Progress Webhooks | LOW | MEDIUM | P3 |
| Interactive Verification | LOW | HIGH | P3 |
| Multi-mode Support | LOW | HIGH | P3 |
| Auto-merge | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch (MVP)
- P2: Should have, add when possible (post-validation)
- P3: Nice to have, future consideration (post-PMF)

## Competitor Feature Analysis

| Feature | RPA Systems (UiPath, Blue Prism) | CI/CD (GitHub Actions) | Our Approach |
|---------|----------------------------------|------------------------|--------------|
| Mode switching | Attended vs Unattended bots (server vs desktop triggers) | Workflow dispatch with inputs | Environment variable (simpler, no UI needed) |
| Readiness detection | Scheduled triggers or queue monitoring | Event triggers (push, PR, schedule) | File system signals (deterministic, fast) |
| Sequential execution | Workflow dependencies via orchestrator | Job dependencies (`needs:` keyword) | Phase ordering via file presence checks |
| Parallel execution | Multiple robots on server farm | Matrix strategy, parallel jobs | Bounded parallelism across repos (not phases) |
| Failure handling | Error handling flows, retry logic | Continue-on-error, timeout settings | GSD pause/resume pattern |
| Execution isolation | Separate robot instances | Isolated runner environments, job containers | Git worktrees (filesystem isolation) |
| Reporting | Orchestrator dashboard, logs | Actions UI, job summaries, artifacts | PR body + comprehensive logs |
| Interactive vs batch | Attended bots (user-triggered) vs unattended (scheduled) | Workflow dispatch (manual) vs event/schedule (auto) | TASKS mode (user files) vs GSD mode (autonomous phases) |

**Our differentiation:** File-system-based readiness (no event infrastructure), Git worktree isolation (safer than containers for code changes), LLM-driven task understanding (more flexible than hardcoded workflows), Dual-mode coexistence (both simple tasks and complex phases).

## Implementation Complexity Notes

**LOW Complexity (1-3 days):**
- Mode switching (environment variable check, conditional routing)
- Yolo mode enforcement (jq config file parsing)
- Skip interactive commands (whitelist `/gsd:execute-phase`, `/gsd:resume-work`, `/gsd:pause-work`)
- PR creation (reuse existing infrastructure)
- Comprehensive logging (extend existing logging functions)
- Phase limit safety valve (counter + config check)
- Dry-run GSD mode (extend existing dry-run flag)

**MEDIUM Complexity (3-7 days):**
- Readiness detection (file system traversal, phase status logic, previous phase completion check)
- Sequential ordering (phase number extraction, completion validation, dependency enforcement)
- Unattended execution (timeout handling, signal trapping, launchd integration)
- Phase chaining (re-scan after completion, loop until no ready phases)
- Resume interrupted sessions (marker file detection, conditional resume call)

**HIGH Complexity (1-2 weeks):**
- Graceful failure handling (timeout detection, state preservation, cleanup on error, atomic operations)
- Parallel repo execution (process management, bounded concurrency, output interleaving, cleanup coordination)

## Sources

**Dual-mode automation systems:**
- [Arcturax: Automation Trends 2026](https://arcturax.com/3-automation-trends-every-oem-should-track/) - Industrial automation mode switching
- [Augusto Digital: AI Automation Trends 2026](https://augusto.digital/insights/blogs/what-are-the-top-2026-ai-automation-trends/) - AI-first vs automation-first patterns
- [DEV Community: Automotive Mode Management](https://dev.to/pooja1008/understanding-mode-management-in-automotive-systems-a-comprehensive-overview-58ck) - BswM mode arbitration
- [AI World Journal: Autonomous Systems 2026](https://aiworldjournal.com/ai-automation-in-2026-the-rise-of-autonomous-systems-at-scale/) - Intelligent agents with context understanding

**Task isolation and feature separation:**
- [Zestminds: AI Automation Tools 2026](https://www.zestminds.com/blog/ai-automation-tools-2026/) - Shift from isolated tools to interconnected ecosystems
- [Monday.com: Best AI Agents 2026](https://monday.com/blog/ai-agents/best-ai-agents/) - Multi-agent workflows, role-based access
- [The IT Source: AI Automation Trends](https://theitsource.asia/blog/ai-automation-2025-five-real-trends-transforming-how-enterprises-scale/) - Hyperautomation integration, environment separation

**Environment variable configuration:**
- [Baeldung: systemd Environment Variables](https://www.baeldung.com/linux/systemd-services-environment-variables) - EnvironmentFile pattern
- [Flatcar: systemd Units](https://www.flatcar.org/docs/latest/setup/systemd/environment-variables/) - Environment variables in unit files
- [Docker Docs: Daemon Proxy](https://docs.docker.com/engine/daemon/proxy/) - Daemon configuration via environment

**Sequential workflows and dependencies:**
- [Nected: Sequential Workflows](https://www.nected.ai/blog/automate-your-projects-with-sequential-workflows) - Task completion order
- [Workflows.guru: DAG Workflows](https://www.workflows.guru/workflow-types/dags-workflows) - Dependency management, task ordering
- [CrewAI: Sequential Processes](https://docs.crewai.com/en/learn/sequential-process) - Sequential task execution patterns
- [Medium: GitHub Actions Parallel/Sequential](https://medium.com/@nickjabs/running-github-actions-in-parallel-and-sequentially-b338e4a46bf5) - Job dependencies

**GitHub Actions isolation:**
- [RunsOn: Jobs and Steps](https://runs-on.com/github-actions/jobs-and-steps/) - Job isolation in separate environments
- [GitHub Docs: Control Concurrency](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs) - Concurrency groups
- [GitHub Blog: Let's Talk About GitHub Actions](https://github.blog/news-insights/product-news/lets-talk-about-github-actions/) - Q1 2026 roadmap (timezones, parallel steps)

**Polling vs event-driven patterns:**
- [Medium: Why We Replaced Polling](https://medium.com/@systemdesignwithsage/why-we-replaced-polling-with-event-triggers-234ecda134b2) - Jan 2026 case study, CPU usage 80% → 2%
- [Prefect: Event-Driven vs Scheduled](https://www.prefect.io/blog/event-driven-versus-scheduled-data-pipelines) - Data pipeline patterns
- [bugfree.ai: Event-Driven vs Poll-Based](https://bugfree.ai/knowledge-hub/event-driven-vs-poll-based-task-execution) - Task execution comparison

**File locking and readiness markers:**
- [Tomasz Poszytek: Locked File Checking Pattern](https://poszytek.eu/en/microsoft-en/office-365-en/powerautomate-en/locked-file-checking-pattern-in-power-automate/) - Power Automate loop patterns
- [Wikipedia: File Locking](https://en.wikipedia.org/wiki/File_locking) - Advisory locks, serialization
- [gavv.net: File Locks in Linux](https://gavv.net/articles/file-locks/) - Advisory vs mandatory locks

**Unattended automation:**
- [SS&C Blue Prism: Attended vs Unattended RPA](https://www.blueprism.com/resources/blog/attended-vs-unattended-rpa/) - Set-and-forget automation
- [Automation Anywhere: RPA Types](https://www.automationanywhere.com/rpa/attended-vs-unattended-rpa) - 24/7 server-based execution
- [Methods Machine Tools: Night Crew](https://www.methodsmachine.com/blog/night-crew-cnc-automation/) - Lights-out manufacturing overnight
- [MachineMetrics: Unattended Factory](https://www.machinemetrics.com/blog/the-unattended-factory-and-industrial-iot) - Continuous production via IoT

**Existing codebase analysis:**
- `/Users/kristiangarza/aves/snowyowl/.planning/PROJECT.md` - Core requirements, mode specifications
- `/Users/kristiangarza/aves/snowyowl/SnowyOwl-GSD-Plan-V3.md` - Integration strategy, readiness rules
- `/Users/kristiangarza/aves/snowyowl/.planning/codebase/ARCHITECTURE.md` - Existing modular architecture, worktree pattern

---
*Feature research for: Dual-mode automation systems (SnowyOwl TASKS + GSD modes)*
*Researched: 2026-02-01*
