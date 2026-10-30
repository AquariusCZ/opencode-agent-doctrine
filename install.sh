#!/usr/bin/env bash
# Install the OpenCode Agent Doctrine into an OpenCode config directory.
set -euo pipefail

DRY_RUN=0
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

usage() {
    cat <<'EOF'
Usage: ./install.sh [--dry-run] [--config-dir DIR]

  --dry-run          Print what would happen; write nothing.
  --config-dir DIR   Target OpenCode config directory.
                     Default: ${XDG_CONFIG_HOME:-$HOME/.config}/opencode
  -h, --help         Show this help.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        --config-dir|-c)
            shift
            [ "$#" -gt 0 ] || die "--config-dir needs a value"
            CONFIG_DIR="$1"
            ;;
        --config-dir=*)
            CONFIG_DIR="${1#*=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC_AGENTS="$SCRIPT_DIR/agents"
SRC_DOCTRINE="$SCRIPT_DIR/AGENTS.md"
SRC_EXAMPLE="$SCRIPT_DIR/config/opencode.example.jsonc"

[ -d "$SRC_AGENTS" ] || die "missing: $SRC_AGENTS"
[ -f "$SRC_DOCTRINE" ] || die "missing: $SRC_DOCTRINE"
[ -f "$SRC_EXAMPLE" ] || die "missing: $SRC_EXAMPLE"

shopt -s nullglob
AGENT_FILES=("$SRC_AGENTS"/*.md)
shopt -u nullglob
[ "${#AGENT_FILES[@]}" -gt 0 ] || die "no agent files in $SRC_AGENTS"

DEST_AGENTS="$CONFIG_DIR/agents"
DEST_DOCTRINE="$CONFIG_DIR/AGENTS.md"
DEST_SIDECAR="$CONFIG_DIR/AGENTS.opencode-doctrine.md"
DEST_CONFIG="$CONFIG_DIR/opencode.jsonc"

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$CONFIG_DIR/agents.bak-$STAMP"

say() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] $*"
    else
        echo "$*"
    fi
}

EXISTING_AGENTS=()
for src in "${AGENT_FILES[@]}"; do
    name=$(basename "$src")
    if [ -f "$DEST_AGENTS/$name" ]; then
        EXISTING_AGENTS+=("$name")
    fi
done

DOCTRINE_EXISTS=0
[ -f "$DEST_DOCTRINE" ] && DOCTRINE_EXISTS=1
SIDECAR_EXISTS=0
[ -f "$DEST_SIDECAR" ] && SIDECAR_EXISTS=1
CONFIG_EXISTS=0
[ -f "$DEST_CONFIG" ] && CONFIG_EXISTS=1

if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== DRY RUN: no files will be written ==="
fi
echo "package: $SCRIPT_DIR"
echo "config : $CONFIG_DIR"
echo

say "create directory: $DEST_AGENTS"

if [ "${#EXISTING_AGENTS[@]}" -gt 0 ]; then
    say "back up ${#EXISTING_AGENTS[@]} existing agent file(s) to: $BACKUP_DIR"
    for name in "${EXISTING_AGENTS[@]}"; do
        say "  backup $name"
    done
else
    say "no existing agent files to back up"
fi

for src in "${AGENT_FILES[@]}"; do
    say "install agent: $(basename "$src") -> $DEST_AGENTS/$(basename "$src")"
done

if [ "$DOCTRINE_EXISTS" -eq 1 ]; then
    say "AGENTS.md exists, writing sidecar instead: $DEST_SIDECAR"
    if [ "$SIDECAR_EXISTS" -eq 1 ]; then
        say "  overwrite existing sidecar (backed up first): $DEST_SIDECAR"
    fi
else
    say "AGENTS.md not found, install as: $DEST_DOCTRINE"
fi

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$DEST_AGENTS"

    if [ "${#EXISTING_AGENTS[@]}" -gt 0 ] || [ "$SIDECAR_EXISTS" -eq 1 ]; then
        mkdir -p "$BACKUP_DIR"
    fi

    for name in "${EXISTING_AGENTS[@]}"; do
        cp -f "$DEST_AGENTS/$name" "$BACKUP_DIR/$name"
    done

    for src in "${AGENT_FILES[@]}"; do
        cp -f "$src" "$DEST_AGENTS/$(basename "$src")"
    done

    if [ "$DOCTRINE_EXISTS" -eq 1 ]; then
        if [ "$SIDECAR_EXISTS" -eq 1 ]; then
            cp -f "$DEST_SIDECAR" "$BACKUP_DIR/AGENTS.opencode-doctrine.md"
        fi
        cp -f "$SRC_DOCTRINE" "$DEST_SIDECAR"
    else
        cp -f "$SRC_DOCTRINE" "$DEST_DOCTRINE"
    fi
fi

echo
if [ "$DOCTRINE_EXISTS" -eq 1 ]; then
    MERGE_PROMPT="已安装为 AGENTS.opencode-doctrine.md。请把它合并进你的 AGENTS.md，或加入 instructions。"
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would: $MERGE_PROMPT"
    else
        echo "$MERGE_PROMPT"
    fi
    say "sidecar: $DEST_SIDECAR"
else
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would install doctrine: $DEST_DOCTRINE"
    else
        echo "installed doctrine: $DEST_DOCTRINE"
    fi
fi

echo
echo "=== config/opencode.example.jsonc (merge manually; opencode.jsonc was NOT modified) ==="
cat "$SRC_EXAMPLE"
echo "=== end of example config ==="
if [ "$CONFIG_EXISTS" -eq 1 ]; then
    echo "existing config left untouched: $DEST_CONFIG"
fi
echo "Merge the keys you need into your opencode.jsonc by hand."
