#!/bin/bash
set -e

# ==============================================================================
# GitLab Runner Initialization Script with PM2 Process Manager
# Usage: ./gitlab-init.sh <runner-name> <token> [gitlab-url]
# ==============================================================================

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"
GITLAB_URL="${3:-${GITLAB_URL:-https://gitlab.com}}"

if [ -z "$RUNNER_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "======================================================================"
    echo "❌ Error: Argumen tidak lengkap!"
    echo "Penggunaan:"
    echo "  $0 <runner-name-yang-akan-dipakai-di-ci> <token> [gitlab-url]"
    echo ""
    echo "Contoh:"
    echo "  $0 gitlab-runner-01 glrt-ABC123xyz"
    echo "  $0 gitlab-runner-01 glrt-ABC123xyz https://gitlab.example.com"
    echo ""
    echo "Catatan: Jika [gitlab-url] tidak diisi, script akan mengambil dari"
    echo "variabel environment GITLAB_URL atau default: https://gitlab.com"
    echo "======================================================================"
    exit 1
fi

echo "======================================================================"
echo "🚀 Memulai inisialisasi GitLab Runner..."
echo "  - Nama Runner : $RUNNER_NAME"
echo "  - GitLab URL  : $GITLAB_URL"
echo "  - Token       : ${RUNNER_TOKEN:0:6}******"
echo "======================================================================"

# Pastikan gitlab-runner terinstall
if ! command -v gitlab-runner &>/dev/null; then
    echo "❌ Error: binary 'gitlab-runner' tidak ditemukan di sistem."
    exit 1
fi

# Buat direktori kerja terisolasi untuk runner ini
BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}/gitlab"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"
CONFIG_FILE="$TARGET_RUNNER_DIR/config.toml"

if [ -d "$TARGET_RUNNER_DIR" ]; then
    echo "⚠️  Direktori runner $TARGET_RUNNER_DIR sudah ada."
    pm2 stop "$RUNNER_NAME" 2>/dev/null || true
    pm2 delete "$RUNNER_NAME" 2>/dev/null || true
    rm -rf "$TARGET_RUNNER_DIR"
fi

mkdir -p "$TARGET_RUNNER_DIR"

# Registrasi GitLab Runner non-interaktif
echo "⚙️  Mendaftarkan runner ke GitLab ($GITLAB_URL)..."
gitlab-runner register \
    --non-interactive \
    --url "$GITLAB_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --executor "shell" \
    --config "$CONFIG_FILE" \
    --tag-list "$RUNNER_NAME"

# Registrasikan ke PM2 agar auto-start & auto-resurrect
echo "⚡ Menjalankan GitLab runner dengan PM2..."
pm2 start gitlab-runner --name "$RUNNER_NAME" -- run --config "$CONFIG_FILE" --working-directory "$TARGET_RUNNER_DIR"

# Simpan state PM2 agar survive saat container atau host reboot
pm2 save

echo "======================================================================"
echo "🎉 GitLab Runner [$RUNNER_NAME] BERHASIL DIAKTIFKAN!"
echo "======================================================================"
echo "Status PM2 saat ini:"
pm2 status "$RUNNER_NAME"
echo ""
echo "📌 Cara pemakaian di GitLab CI/CD (.gitlab-ci.yml):"
echo "job_build:"
echo "  tags:"
echo "    - $RUNNER_NAME"
echo "  script:"
echo "    - echo 'Running on self-hosted GitLab runner!'"
echo "======================================================================"
