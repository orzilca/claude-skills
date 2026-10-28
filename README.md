# claude-skills

Skills for [Claude Code](https://claude.com/claude-code).

## Skills

### disk-cleanup

For when your Mac's disk is full. Claude runs only a read-only scan, explains what's taking the space (sorted into safe / review first / don't touch), and gives you one-line cleanup commands to run yourself. It never deletes anything on its own.

macOS only.

## Install

In Claude Code (2.1.275 or later):

```
/plugin install disk-cleanup --marketplace orzilca/claude-skills
```

On older versions, add the marketplace first, then install:

```
/plugin marketplace add orzilca/claude-skills
```

```
/plugin install disk-cleanup@orzilca-skills
```

Then say "my disk is full", or run `/disk-cleanup:disk-cleanup`.

### Manual install (no plugin)

```bash
git clone https://github.com/orzilca/claude-skills.git
```

```bash
cp -R claude-skills/disk-cleanup/skills/disk-cleanup ~/.claude/skills/
```

Then run `/disk-cleanup`.
