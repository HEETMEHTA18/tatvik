# Successful Prompts & Patterns

Patterns that produced passing tests and merged-quality PRs in this repository.

---

## Format

```markdown
### <date> — <task summary>
**Stack:** Go / CLI
**What worked:**
- bullet
**Test command:** `go test ./...`
**Prompt archive:** `.autodevs/prompts/prompt_<id>.md`
```

---

## Seed entries

### 2026-06-05 — Prompt Capture Engine
**Stack:** Go
**What worked:**
- Break requirements into numbered deliverables
- Implement `InitDirs` before session logic
- Privacy-first local storage before API sync
**Test command:** `go test ./packages/core/promptcapture/...`
