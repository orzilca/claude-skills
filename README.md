# claude-skills

Skills for [Claude Code](https://claude.com/claude-code).

## Skills

### disk-cleanup

For when your Mac's disk is full. Claude runs only a read-only scan, explains what's taking the space (sorted into safe / review first / don't touch), and gives you one-line cleanup commands to run yourself. It never deletes anything on its own.

macOS only.

## Install

```bash
git clone https://github.com/orzilca/claude-skills.git
```

```bash
cp -R claude-skills/disk-cleanup ~/.claude/skills/
```

Then, in Claude Code, run `/disk-cleanup` or just say "my disk is full".
