# Ralph Loop — Self-Improving Execution Engine

**Version:** 1.0  
**Purpose:** Turn one-shot coding into an iterative, memory-aware pipeline that learns from failures.

---

## Philosophy

| Tool | Model |
|------|-------|
| GitHub Copilot | One prompt → one answer |
| Claude Code | One prompt → iterative coding |
| **DevMentor + AutoDevs + Ralph** | Voice idea → todo → multi-agent loop → memory → retry → PR |

**DevMentor** = Brain  
**Ralph Loop** = Thinking Process  
**AutoDevs** = Hands  
**GitHub** = Workspace  
**Mobile** = Command Center

---

## Loop diagram

```
todo_<id>.md
    │
    ▼
┌─────────┐
│ Planner │  reads todo, prompts-base, memory, repo
└────┬────┘
     ▼
┌─────────────────┐
│ Context Builder │  writes .autodevs/context/CONTEXT_<id>.md
└────┬────────────┘
     ▼
┌─────────┐
│ Builder │  implements smallest production-ready change
└────┬────┘
     ▼
┌──────────┐
│ Reviewer │  static review vs acceptance criteria
└────┬─────┘
     ▼
┌──────────┐
│ Verifier │  run tests, linters, build
└────┬─────┘
     │
     ├── PASS ──► PHASE 6–7 (git + PR) ──► completed/
     │
     └── FAIL ──► Optimizer ──► loop_<id>_<n+1>.md ──► Builder (retry)
```

---

## Configuration

```yaml
max_iterations: 5
max_repair_attempts_per_iteration: 3
human_review_after_max_iterations: true
```

If `loop_count > max_iterations` → write `failed_<id>.md` and stop.

---

## Stage 1: Planner

**Input:** `todo_<id>.md`, `prompts-base.md`, `memory/*`, `prompts.md`  
**Output:** Subtasks + risks in `plans/plan_<id>.md`

Example output structure:

```markdown
## Goal
Implement Google OAuth.

## Subtasks
1. Analyze existing auth flow
2. Add provider config
3. Build sign-in UI
4. Protect routes
5. Add tests

## Risks
- Breaking existing session handling
```

**Agent prompt:** `.autodevs/agents/planner.md`

---

## Stage 2: Context Builder

**Input:** README, relevant source, prior `logs/`, successful `completed/` reports  
**Output:** `.autodevs/context/CONTEXT_<id>.md`

Example:

```markdown
## Stack
- Flutter + Provider + Firebase Auth

## Conventions
- Use existing navigation in lib/routes/
- Widget tests in test/widgets/

## Unknowns
- Whether refresh tokens are already handled
```

**Agent prompt:** `.autodevs/agents/context.md`

---

## Stage 3: Builder

**Input:** todo, CONTEXT, plan, current loop prompt  
**Output:** Code changes

Rules:

- Smallest production-ready diff
- Preserve existing behavior unless todo says otherwise
- No architecture rewrites

**Agent prompt:** `.autodevs/agents/builder.md`

---

## Stage 4: Reviewer

**Input:** diff, acceptance criteria, `prompts-base.md`  
**Output:** Blocking issues list (or empty)

Check: security, edge cases, missing tests, architecture violations, UX.

**Agent prompt:** `.autodevs/agents/reviewer.md`

Blocking issues → skip Verifier repair, go to Optimizer.

---

## Stage 5: Verifier

**Input:** codebase after build  
**Output:** pass/fail + command output summary

Run stack-appropriate checks (see SYSTEM_PROMPT.md PHASE 4).

**Agent prompt:** `.autodevs/agents/verifier.md`

---

## Stage 6: Prompt Optimizer (on failure)

**Input:**

- Previous loop prompt (`.autodevs/loops/loop_<id>_<n>.md`)
- Reviewer feedback
- Verifier stderr/stdout
- `memory/mistakes.md`

**Output:**

- Updated prompt for next iteration
- Append to `memory/mistakes.md` if new failure pattern
- New file: `.autodevs/loops/loop_<id>_<n+1>.md`

Example optimizer output:

```markdown
## Why attempt N failed
- Provider pattern ignored; Riverpod introduced
- Widget tests missing for login screen

## Next iteration improvements
- Reuse existing Provider auth state
- Add test/widgets/login_test.dart
- Do not add new state management libraries
```

**Agent prompt:** `.autodevs/agents/optimizer.md`

---

## Loop prompt template

Each iteration writes `.autodevs/loops/loop_<task_id>_<n>.md`:

```markdown
# Ralph Loop — <task_id> — Iteration <n>/<max>

## Objective
{from todo}

## Repository Context
{from CONTEXT_<id>.md}

## Plan Summary
{from plan_<id>.md}

## Previous Attempts
{summary of loops 1..n-1}

## Reviewer Feedback
{blocking issues or "none"}

## Error Logs
{verifier output, truncated}

## Constraints
{from todo}

## Acceptance Criteria
{from todo}

## Build Instructions
- Follow existing architecture
- Minimize file churn
- Write/update tests
- Preserve unrelated functionality

## Active Agent
{Planner|Context|Builder|Reviewer|Verifier|Optimizer}

## Status
{in_progress|passed|failed}
```

---

## Memory retrieval (before every generation)

1. Read `memory/successes.md` — patterns that worked for this repo/stack
2. Read `memory/mistakes.md` — anti-patterns to avoid
3. Read `memory/patterns.md` — architectural conventions discovered
4. Search `prompts.md` and `prompts/prompt_*.md` for similar tasks
5. Read latest `logs/log_<id>.md` if resuming

Update memory after each task:

- **Success** → append to `successes.md` and `patterns.md`
- **Failure** → append to `mistakes.md`

---

## Prompt archive

After success, save the final effective prompt:

`.autodevs/prompts/prompt_<task_id>.md`

Include: objective, context summary, what worked, test commands run.

---

## Integration with `autodev prompts`

- `autodev prompts daemon` monitors Codex/Claude/Gemini — captured prompts feed `prompts.md`
- `autodev prompts sync` pushes telemetry to DevMentor
- Ralph Loop **reads** captured history; it does not replace local todo-driven execution

---

## Human approval mode (future)

When `approval_mode: true` in todo metadata:

- Pause before Builder if plan touches > N files
- Notify DevMentor: "AutoDevs wants to modify 12 files. Approve?"

Default: `approval_mode: false` for normal feature work.

---

## Priority mode

If todo `Priority: High` or `Critical`:

- Run immediately when detected
- Skip unrelated queued todos
- Still respect `max_iterations` and safety rules

---

## Cost tracking (future)

Log per-iteration model usage in `logs/log_<id>.md`:

```markdown
## Cost
- gemini: ₹4.20
- claude: ₹12.30
```

---

## Codex / CLI invocation

**Manual run (today):**

```bash
# In repo root — Codex reads AGENTS.md + .autodevs/*
codex

# Or explicit task
codex "Execute Ralph Loop for .autodevs/todo/todo_001.md per AGENTS.md"
```

**Future CLI:**

```bash
autodev watch    # fsnotify on .autodevs/todo/
autodev run todo_001.md
```

Until `watch`/`run` ship, Codex (or Cursor) executes the loop by following this file.
