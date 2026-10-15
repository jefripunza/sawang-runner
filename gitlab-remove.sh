#!/bin/bash
set -e

# ==============================================================================
# GitLab Runner Removal Script
# Usage: ./gitlab-remove.sh <runner-name> [token]
# ==============================================================================

show_usage() {
    echo "======================================================================"
    echo "📖 Panduan Penggunaan GitLab Runner Removal"
    echo "======================================================================"
    echo "Penggunaan: $0 <runner-name> [token]"
    echo "Opsi:       -h, --help    Tampilkan bantuan ini"
    echo "Contoh:     $0 gitlab-runner-01"
    echo "            $0 gitlab-runner-01 glrt-ABC123xyz"
    echo "======================================================================"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"

if [ -z "$RUNNER_NAME" ]; then
    echo "❌ Error: Argumen tidak lengkap! Membutuhkan <runner-name>"
    echo ""
    show_usage
    exit 1
fi

BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}/gitlab"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"
CONFIG_FILE="$TARGET_RUNNER_DIR/config.toml"

echo "======================================================================"
echo "🗑️  Menghapus GitLab Runner: $RUNNER_NAME"
echo "======================================================================"

# 1. Hentikan dan hapus dari PM2
echo "⚡ Menghapus dari PM2..."
pm2 stop "$RUNNER_NAME" 2>/dev/null || true
pm2 delete "$RUNNER_NAME" 2>/dev/null || true
pm2 save

# 2. Hapus pendaftaran dari GitLab jika file konfigurasi ada
if [ -f "$CONFIG_FILE" ]; then
    echo "⚙️  Membatalkan pendaftaran dari GitLab..."
    if [ -n "$RUNNER_TOKEN" ]; then
        gitlab-runner unregister --config "$CONFIG_FILE" --token "$RUNNER_TOKEN" 2>/dev/null || true
    fi
    gitlab-runner unregister --config "$CONFIG_FILE" --all-runners 2>/dev/null || true
fi

# 3. Bersihkan direktori
if [ -d "$TARGET_RUNNER_DIR" ]; then
    echo "🧹 Membersihkan direktori $TARGET_RUNNER_DIR..."
    rm -rf "$TARGET_RUNNER_DIR"
fi

echo "✅ GitLab Runner $RUNNER_NAME berhasil dihapus."
pm2 status
