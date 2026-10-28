#!/bin/bash
# Read-only disk usage report for macOS. Never deletes or modifies anything.
# Usage: analyze.sh [DEV_ROOT]

DEV_ROOT="${1:-}"
if [ -z "$DEV_ROOT" ]; then
  for d in ~/dev ~/code ~/src ~/Projects ~/projects ~/repos ~/work ~/git ~/Developer; do
    [ -d "$d" ] && DEV_ROOT="$d" && break
  done
fi
[ -n "$DEV_ROOT" ] && [ -d "$DEV_ROOT" ] && DEV_ROOT=$(cd "$DEV_ROOT" && pwd)

DU=$(mktemp -t disk-analyze)
trap 'rm -f "$DU"' EXIT

sec() { echo; echo "=== $1"; }
human() { awk -F'\t' '{s=$1; u="K"; if(s>=1024){s/=1024;u="M"} if(s>=1024){s/=1024;u="G"} printf "%7.1f%s\t%s\n", s, u, $2}'; }
# children PARENT [N]: immediate subdirs of PARENT, largest first (from the single du pass when possible)
children() {
  local p="${1%/}" n="${2:-15}"
  if [[ "$p" == "$HOME" || "$p" == "$HOME"/* ]]; then
    awk -F'\t' -v p="$p/" 'index($2,p)==1 && substr($2,length(p)+1) !~ /\// {print}' "$DU"
  else
    du -xk -d1 "$p" 2>/dev/null | awk -F'\t' -v p="$p" '$2!=p'
  fi | sort -nr | head -"$n" | human
}
# size PATH...: size of each existing path, largest first
size() {
  for p in "$@"; do
    [ -e "$p" ] || continue
    line=$(awk -F'\t' -v p="$p" '$2==p {print; exit}' "$DU")
    [ -n "$line" ] && echo "$line" || du -xsk "$p" 2>/dev/null
  done | sort -nr | human
}

sec "disk"; df -h /System/Volumes/Data | tail -1
ls ~/Library/Mail >/dev/null 2>&1 || echo "note: no Full Disk Access — Mail/Messages/Safari/Photos sizes may be missing or low"

echo; echo "(scanning home once, this takes a few minutes...)"
du -xk -d 4 ~ 2>/dev/null > "$DU"
sec "home total"; size ~
sec "home"; children ~ 25
sec "~/Library"; children ~/Library
sec "~/Library/Caches"; children ~/Library/Caches 25
sec "~/Library/Application Support"; children ~/Library/Application\ Support 20
sec "~/Library/Containers"; children ~/Library/Containers 8
sec "~/Library/Group Containers"; children ~/Library/Group\ Containers 8
sec "~/.cache"; children ~/.cache

sec "package-manager / dev-tool caches"
size ~/.cache/uv ~/.npm ~/Library/Caches/Yarn ~/Library/pnpm ~/Library/Caches/pip ~/Library/Caches/go-build \
  ~/go/pkg/mod ~/Library/Caches/node-gyp ~/Library/Caches/ms-playwright ~/Library/Caches/serverless-python-requirements \
  ~/Library/Caches/Homebrew ~/.gradle/caches ~/.m2/repository ~/.cargo/registry ~/.rustup/toolchains ~/.bun/install/cache \
  ~/.pub-cache ~/Library/Caches/CocoaPods ~/.terraform.d/plugin-cache ~/.conda/pkgs ~/miniconda3 ~/anaconda3 ~/miniforge3

sec "Xcode / mobile"
size ~/Library/Developer/Xcode/DerivedData ~/Library/Developer/Xcode/iOS\ DeviceSupport ~/Library/Developer/Xcode/Archives \
  ~/Library/Developer/CoreSimulator/Devices ~/Library/Developer/CoreSimulator/Caches \
  ~/Library/Application\ Support/MobileSync/Backup ~/Library/Android/sdk ~/.android/avd

sec "AI models / editors / Claude"
size ~/.ollama/models ~/.cache/huggingface ~/.cache/torch ~/.cache/lm-studio ~/.lmstudio \
  ~/Library/Application\ Support/Code ~/Library/Application\ Support/Cursor ~/.vscode/extensions ~/.cursor/extensions \
  ~/.claude/projects ~/.claude/debug ~/Library/Application\ Support/Claude/vm_bundles

sec "logs / trash / downloads / personal data"
size ~/Library/Logs /Library/Logs ~/.Trash ~/Downloads ~/Library/Mail ~/Library/Messages ~/Pictures/Photos\ Library.photoslibrary \
  ~/Parallels ~/Library/Containers/com.utmapp.UTM

sec "tools on PATH (Claude's non-interactive shell; MISSING here may still exist in the user's terminal)"
for t in uv npm yarn pnpm pip brew docker go conda xcrun; do printf "  %-7s %s\n" "$t" "$(command -v $t || echo MISSING)"; done

sec "docker"
if ! command -v docker >/dev/null; then echo "docker not installed"
elif ! docker info >/dev/null 2>&1; then echo "docker not running"
else
  docker system df
  echo; echo "unused volumes (may hold DB data, review names):"
  docker volume ls -f dangling=true 2>/dev/null | head -30
fi

sec "JetBrains (Caches = safe; Application Support = settings/plugins)"
size ~/Library/Caches/JetBrains/* ~/Library/Application\ Support/JetBrains/*

sec "node versions (nvm)"; size ~/.nvm/versions/node/*
sec "python versions (pyenv)"; size ~/.pyenv/versions/*

if [ -n "$DEV_ROOT" ] && [ -d "$DEV_ROOT" ]; then
  sec "$DEV_ROOT top"; children "$DEV_ROOT" 25
  sec "git worktrees under $DEV_ROOT (dirty excludes ignored files; ignored = .env, builds, local data)"
  find "$DEV_ROOT" -maxdepth 3 -type d -name .git -prune 2>/dev/null | while read -r g; do
    repo=$(dirname "$g")
    git -C "$repo" worktree list --porcelain 2>/dev/null | while read -r k v; do
      case "$k" in
        worktree) wt="$v"; prunable="" ;;
        prunable) prunable=1 ;;
        "")
          if [ -n "$prunable" ]; then echo "  PRUNABLE (dir gone) $wt  [repo $repo]"
          elif [ "$wt" != "$repo" ] && [ -d "$wt" ]; then
            st=$(git -C "$wt" --no-optional-locks status --porcelain --ignored 2>/dev/null)
            dirty=$(printf '%s\n' "$st" | grep -cv -e '^!!' -e '^$')
            ignored=$(printf '%s\n' "$st" | grep -c '^!!')
            last=$(git -C "$wt" log -1 --format=%cr 2>/dev/null)
            sz=$(du -sh "$wt" 2>/dev/null | cut -f1)
            echo "  $sz | dirty=$dirty ignored=$ignored | $last | $wt  [repo $repo]"
          fi ;;
      esac
    done
  done
  sec "node_modules under $DEV_ROOT"
  find "$DEV_ROOT" -maxdepth 5 -type d -name node_modules -prune -exec du -sh {} + 2>/dev/null | sort -hr | head -20
  sec "python venvs under $DEV_ROOT"
  find "$DEV_ROOT" -maxdepth 5 -type d \( -name .venv -o -name venv \) -prune -exec du -sh {} + 2>/dev/null | sort -hr | head -15
  sec "build/scratch dirs under $DEV_ROOT"
  find "$DEV_ROOT" -maxdepth 4 -type d \( -name dist -o -name build -o -name target -o -name .next -o -name tmp -o -name .cache \) \
    -not -path '*/node_modules/*' -prune -exec du -sh {} + 2>/dev/null | sort -hr | head -15
else
  sec "dev root"; echo "  (no dev root found; pass one as \$1)"
fi

sec "outside home"
for p in /Applications /opt /usr/local /Library; do children "$p" 8; done | sort -bhr | head -15
sec "APFS local snapshots"; tmutil listlocalsnapshots / 2>/dev/null
sec "large files >1G in home (excluding ~/Library)"
find ~ -xdev -path ~/Library -prune -o -type f -size +1G -exec du -sh {} + 2>/dev/null | sort -hr | head -15
