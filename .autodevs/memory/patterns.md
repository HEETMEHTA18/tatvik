# Discovered Architecture Patterns

Conventions learned from this codebase during Ralph Loop execution.

---

## Repository layout

| Path | Role |
|------|------|
| `packages/cli/cmd/` | Cobra commands |
| `packages/core/promptcapture/` | Session capture, DevMentor sync |
| `packages/core/scanner/` | Language/framework detection |
| `.autodevs/` | Prompt intelligence + Ralph Loop state |

---

## CLI patterns

- `FindProjectRoot()` walks up for `.git`, `package.json`, or `go.mod`
- `InitDirs()` scaffolds `.autodevs/` subdirectories
- DevMentor API default: production Render URL (override via env)

---

## Integration points

- `autodev prompts capture <cli>` — stdin proxy for codex, claude, gemini
- `autodev prompts daemon` — background process monitor
- `autodev prompts sync` — push `analytics/queue.json` to DevMentor

---

## Ralph Loop file flow

```
todo/ → plans/ + context/ + loops/ → git branch → completed/ + logs/ + prompts/
```
