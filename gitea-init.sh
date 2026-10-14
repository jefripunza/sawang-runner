#!/bin/bash
set -e

# ==============================================================================
# Gitea / Forgejo Runner (act_runner) Initialization Script with PM2
# Usage: ./gitea-init.sh <runner-name> <token> [gitea-url]
# ==============================================================================

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"
GITEA_URL="$3"

if [ -z "$RUNNER_NAME" ] || [ -z "$RUNNER_TOKEN" ] || [ -z "$GITEA_URL" ]; then
    echo "======================================================================"
    echo "❌ Error: Argumen tidak lengkap! Gitea wajib menyertakan URL instance."
    echo "Penggunaan:"
    echo "  $0 <runner-name-yang-akan-dipakai-di-yaml> <token> <gitea-url>"
    echo ""
    echo "Contoh:"
    echo "  $0 gitea-runner-01 ABCD1234EFGH5678 https://gitea.example.com"
    echo "======================================================================"
    exit 1
fi

# Format URL jika user memasukkan hostname saja
if [[ ! "$GITEA_URL" =~ ^https?:// ]]; then
    GITEA_URL="https://$GITEA_URL"
fi

echo "======================================================================"
echo "🚀 Memulai inisialisasi Gitea Actions Runner..."
echo "  - Nama Runner : $RUNNER_NAME"
echo "  - Gitea URL   : $GITEA_URL"
echo "  - Token       : ${RUNNER_TOKEN:0:6}******"
echo "======================================================================"

# Pastikan binary gitea-runner atau act_runner tersedia
RUNNER_BIN=""
if command -v gitea-runner &>/dev/null; then
    RUNNER_BIN="gitea-runner"
elif command -v act_runner &>/dev/null; then
    RUNNER_BIN="act_runner"
else
    echo "❌ Error: binary 'gitea-runner' atau 'act_runner' tidak ditemukan di sistem."
    exit 1
fi

BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}/gitea"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"

if [ -d "$TARGET_RUNNER_DIR" ]; then
    echo "⚠️  Direktori runner $TARGET_RUNNER_DIR sudah ada."
    pm2 stop "$RUNNER_NAME" 2>/dev/null || true
    pm2 delete "$RUNNER_NAME" 2>/dev/null || true
    rm -rf "$TARGET_RUNNER_DIR"
fi

mkdir -p "$TARGET_RUNNER_DIR"
cd "$TARGET_RUNNER_DIR"

# Registrasi runner ke instance Gitea
echo "⚙️  Mendaftarkan runner ke Gitea ($GITEA_URL)..."
$RUNNER_BIN register \
    --instance "$GITEA_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_NAME:host,ubuntu-latest:host" \
    --no-interactive

# Jalankan dengan PM2 agar auto-restart saat reboot
echo "⚡ Menjalankan Gitea runner dengan PM2..."
pm2 start "$RUNNER_BIN" --name "$RUNNER_NAME" --cwd "$TARGET_RUNNER_DIR" -- daemon

# Simpan state PM2
pm2 save

echo "======================================================================"
echo "🎉 Gitea Runner [$RUNNER_NAME] BERHASIL DIAKTIFKAN!"
echo "======================================================================"
echo "Status PM2 saat ini:"
pm2 status "$RUNNER_NAME"
echo ""
echo "📌 Cara pemakaian di Gitea Actions Workflow (.gitea/workflows/ci.yaml):"
echo "jobs:"
echo "  build:"
echo "    runs-on: $RUNNER_NAME"
echo "    # atau: runs-on: [self-hosted, $RUNNER_NAME]"
echo "    steps:"
echo "      - uses: actions/checkout@v4"
echo "======================================================================"
