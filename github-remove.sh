#!/bin/bash
set -e

# ==============================================================================
# GitHub Runner Removal Script
# Usage: ./github-remove.sh <runner-name> <token>
# ==============================================================================

show_usage() {
    echo "======================================================================"
    echo "📖 Panduan Penggunaan GitHub Runner Removal"
    echo "======================================================================"
    echo "Penggunaan: $0 <runner-name> <removal-token>"
    echo "Opsi:       -h, --help    Tampilkan bantuan ini"
    echo "Contoh:     $0 runner-flutter-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ"
    echo "======================================================================"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"

if [ -z "$RUNNER_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "❌ Error: Argumen tidak lengkap! Membutuhkan <runner-name> dan <removal-token>"
    echo ""
    show_usage
    exit 1
fi

BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"

echo "======================================================================"
echo "🗑️  Menghapus GitHub Runner: $RUNNER_NAME"
echo "======================================================================"

# 1. Hentikan dan hapus dari PM2
echo "⚡ Menghapus dari PM2..."
pm2 stop "$RUNNER_NAME" 2>/dev/null || true
pm2 delete "$RUNNER_NAME" 2>/dev/null || true
pm2 save

# 2. Hapus pendaftaran dari GitHub jika direktori konfigurasi ada
if [ -d "$TARGET_RUNNER_DIR" ]; then
    cd "$TARGET_RUNNER_DIR"
    if [ -f "./config.sh" ]; then
        echo "⚙️  Membatalkan pendaftaran dari GitHub..."
        export RUNNER_ALLOW_RUNASROOT=1
        ./config.sh remove --token "$RUNNER_TOKEN" || echo "⚠️  Gagal unregister dari GitHub via config.sh (mungkin token expired atau runner offline)."
    fi
    echo "🧹 Membersihkan direktori $TARGET_RUNNER_DIR..."
    rm -rf "$TARGET_RUNNER_DIR"
fi

echo "✅ Runner $RUNNER_NAME berhasil dihapus."
pm2 status
