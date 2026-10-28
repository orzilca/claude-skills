---
name: disk-cleanup
description: Use when the user says their Mac's disk or storage is full, asks what's taking disk space ("System Data", "Other storage", "Macintosh HD full"), or wants to free storage on macOS. Analyzes read-only, then hands the user one-line cleanup commands to run themselves. Never deletes anything itself. Triggers on "disk full", "free up space", "what's using my disk", "storage full", "disk-cleanup".
---

# Disk Cleanup (analyze + hand off)

**Hard rule:** never run anything that deletes, prunes, cleans, thins or uninstalls: no `rm`, `prune`, `cache clean`, `brew cleanup`, `simctl delete`, `docker volume rm`, `worktree remove`, `tmutil delete`/`thinlocalsnapshots`, `uninstall`. This holds even when the user says "just do it". Only read-only analysis runs. Cleanup is always handed to the user as commands they run themselves.

## 1. Analyze

Run `scripts/analyze.sh` from this skill's directory (the folder containing this SKILL.md) in the background. It walks the home folder once with `du`, which takes a few minutes on large disks:

```
bash <skill-dir>/scripts/analyze.sh [DEV_ROOT]
```

With no argument, the script looks for the first existing folder among `~/dev ~/code ~/src ~/Projects ~/repos ~/work ~/git ~/Developer`. If it reports that it found no dev root, ask the user where their code lives and re-run with that path.

Then read the output. Drill into anything big the scan didn't explain with extra read-only `du -xhd1 <dir>` calls.

If `df` used space is far above the scan totals, the gap is usually TCC-protected folders (the script warns when it lacks Full Disk Access), APFS snapshots, or purgeable space.

## 2. Report

Give one table sorted by size, with columns **what | size | tier | command**. Group the items into three tiers:

- **Safe.** Rebuilds or re-downloads on demand:
  - package caches: uv, npm, Yarn, pnpm, pip, go-build, Homebrew, bun, Gradle, Maven, Cargo registry
  - Docker unused **images** and **build cache**
  - IDE caches (`~/Library/Caches/JetBrains`, VS Code/Cursor `Cache*`)
  - app caches (Spotify, Telegram, browsers)
  - playwright browsers, Xcode DerivedData
  - logs (`~/Library/Logs`)
  - updater leftovers (`*.ShipIt`)
- **Review first.** User data may be lost:
  - Docker **volumes**: named volumes may hold database data. Show the names the scan listed.
  - git worktrees: show size, dirty/ignored counts and last-commit age for each one; flag dirty ones and those with ignored files.
  - `node_modules`, venvs and build/scratch dirs (`dist`, `build`, `target`, `.next`, `tmp`) in inactive repos
  - extra nvm, pyenv or rustup versions
  - old JetBrains version dirs in `Application Support/JetBrains` (settings and plugins; safe once a newer version has imported them)
  - Xcode iOS DeviceSupport and Archives, simulators
  - iOS backups (`MobileSync/Backup`)
  - AI models (Ollama, Hugging Face, torch): they can be re-downloaded but are huge and slow to fetch
  - app VM bundles, Parallels/UTM VMs
  - Claude Code transcripts (`~/.claude/projects`)
  - `~/Downloads`, `~/.Trash`, large files
- **Don't touch here.** Clean these in the owning app or leave them alone:
  - macOS system files, `/private/var`
  - APFS `com.apple.os.update-*` snapshots (finishing the OS update frees them)
  - Mail, Messages, Photos libraries (clean them from inside the app)

State the total reclaimable space for each tier. Say explicitly that nothing was deleted.

## 3. Hand off commands

Give each command in its own fenced `bash` block: one line, no `$` prompt, no `&&` chains. Order them from lowest risk and fastest to slowest. Put one line above each command saying what it frees and any precondition.

Build these known gotchas into the commands:

| Item | Command | Gotcha |
|---|---|---|
| uv | `uv cache clean` | Very slow on big caches (millions of files, 10+ min). Put it last and suggest a separate terminal tab. It hangs on "Cache is currently in-use" while uvx-launched MCP servers run, so check `pgrep -fl uvx` first. Then offer `uv cache prune --force`, which removes only unreachable entries so running envs keep working, or `uv cache clean --force`, which breaks running uvx servers until their sessions restart. |
| Yarn | `rm -rf ~/Library/Caches/Yarn` | "MISSING" in the script's PATH list reflects Claude's shell, not the user's terminal. Prefer `rm -rf` of the cache dir, which works either way. |
| npm | `npm cache clean --force` | The "Recommended protections disabled" warning is normal. |
| Homebrew | `brew cleanup --prune=all` | Prefer this to `rm -rf` of the cache. |
| Docker images/cache | `docker system prune -a` | No `--volumes`, no `-f`. It also removes stopped containers. Docker lists what it will delete and asks first. |
| Docker volumes | `docker volume ls` then `docker volume prune -a` | Review tier only. Named volumes may be databases. No `-f`, so the user sees the list and confirms. Docker.raw shrinks lazily; restarting Docker Desktop shows the freed space. |
| JetBrains caches | `rm -rf ~/Library/Caches/JetBrains` | Quit the IDEs first; they re-index afterwards. |
| App caches | `rm -rf ~/Library/Caches/<app>` | Quit the app first. |
| Simulators | `xcrun simctl delete unavailable` | Removes only simulators for SDKs that are no longer installed. |
| Stale worktree entries | `git -C <repo> worktree prune` | Removes only entries whose dir is already gone. |
| Worktree | `git -C <repo> worktree remove <path>` | Offer only when dirty=0. The dirty count excludes ignored files, so if ignored>0 first give `git -C <wt> status --porcelain --ignored` and have the user check for `.env` or local data. Never `--force` unless the user asks. |
| nvm version | `nvm uninstall <ver>` | Keep the default version and any pinned in `.nvmrc` files. |

Path rules:
- Escape spaces: `Application\ Support`.
- Keep `~` outside quotes: `"~/x"` is literal and does not expand.
- Never hardcode `/Users/<name>`.

## 4. Follow along

As the user pastes each command's output:
- Confirm in one line that it worked. No output from `rm -rf` means success.
- Note how much space it freed, then give the next command.
- If a command fails, give an alternative (for example, tool missing → delete its cache dir).

End with:

```bash
df -h /System/Volumes/Data
```
