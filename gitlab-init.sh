#!/bin/bash
set -e

# ==============================================================================
# GitLab Runner Initialization Script with PM2 Process Manager
# Usage: ./gitlab-init.sh <runner-name> <token> [gitlab-url]
# ==============================================================================

show_usage() {
    echo "======================================================================"
    echo "📖 Panduan Penggunaan GitLab Runner Initialization"
    echo "======================================================================"
    echo "Penggunaan:"
    echo "  $0 <runner-name> <token> [gitlab-hostname-atau-url]"
    echo ""
    echo "Argumen:"
    echo "  1. runner-name              : Nama unik runner (digunakan di tags .gitlab-ci.yml)"
    echo "  2. token                    : Registration/authentication token dari GitLab (glrt-...)"
    echo "  3. gitlab-hostname-atau-url : (Opsional) Hostname atau URL instance GitLab"
    echo "                                Default jika kosong: https://gitlab.com"
    echo ""
    echo "Opsi:"
    echo "  -h, --help                  : Tampilkan bantuan ini"
    echo ""
    echo "Contoh:"
    echo "  # 1. Menggunakan hostname utama (gitlab.com):"
    echo "  $0 gitlab-runner-01 glrt-ABC123xyz"
    echo ""
    echo "  # 2. Menggunakan self-hosted GitLab:"
    echo "  $0 gitlab-runner-01 glrt-ABC123xyz gitlab.example.com"
    echo "  $0 gitlab-runner-01 glrt-ABC123xyz https://gitlab.example.com"
    echo ""
    echo "📌 Cara pemakaian di GitLab CI/CD (.gitlab-ci.yml):"
    echo "  job_build:"
    echo "    tags:"
    echo "      - <runner-name>"
    echo "======================================================================"
}

# Tampilkan petunjuk bantuan jika tanpa argumen atau memakai flag bantuan
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"
GITLAB_INPUT="$3"

# Validasi kelengkapan argumen
if [ -z "$RUNNER_NAME" ] || [ -z "$RUNNER_TOKEN" ]; then
    echo "❌ Error: Argumen tidak lengkap! GitLab runner membutuhkan minimal <runner-name> dan <token>"
    echo ""
    show_usage
    exit 1
fi

if [ -n "$GITLAB_INPUT" ]; then
    if [[ "$GITLAB_INPUT" =~ ^https?:// ]]; then
        GITLAB_URL="$GITLAB_INPUT"
    else
        GITLAB_URL="https://$GITLAB_INPUT"
    fi
else
    GITLAB_URL="https://gitlab.com"
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
