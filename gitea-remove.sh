#!/bin/bash
set -e

# ==============================================================================
# Gitea Runner Removal Script
# Usage: ./gitea-remove.sh <runner-name>
# ==============================================================================

RUNNER_NAME="$1"

if [ -z "$RUNNER_NAME" ]; then
    echo "❌ Error: Argumen tidak lengkap!"
    echo "Penggunaan: $0 <runner-name>"
    echo "Contoh:     $0 gitea-runner-01"
    exit 1
fi

BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}/gitea"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"

echo "======================================================================"
echo "🗑️  Menghapus Gitea Runner: $RUNNER_NAME"
echo "======================================================================"

# 1. Hentikan dan hapus dari PM2
echo "⚡ Menghapus dari PM2..."
pm2 stop "$RUNNER_NAME" 2>/dev/null || true
pm2 delete "$RUNNER_NAME" 2>/dev/null || true
pm2 save

# 2. Bersihkan direktori runner
if [ -d "$TARGET_RUNNER_DIR" ]; then
    echo "🧹 Membersihkan direktori $TARGET_RUNNER_DIR..."
    rm -rf "$TARGET_RUNNER_DIR"
fi

echo "✅ Gitea Runner $RUNNER_NAME berhasil dihapus dari PM2 dan sistem."
echo "ℹ️  Catatan: Anda juga dapat menghapus runner dari antarmuka web Gitea di menu Settings > Actions > Runners jika diperlukan."
pm2 status
