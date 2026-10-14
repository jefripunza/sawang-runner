#!/bin/bash
set -e

# ==============================================================================
# GitHub Runner Initialization Script with PM2 Process Manager
# Usage: ./github-init.sh <runner-name> <token> [github-url]
# ==============================================================================

RUNNER_NAME="$1"
RUNNER_TOKEN="$2"
REPO_INPUT="$3"

# Tampilkan petunjuk penggunaan jika argumen kurang
if [ -z "$RUNNER_NAME" ] || [ -z "$RUNNER_TOKEN" ] || [ -z "$REPO_INPUT" ]; then
    echo "======================================================================"
    echo "❌ Error: Argumen tidak lengkap! GitHub runner membutuhkan URL repository."
    echo "Penggunaan:"
    echo "  $0 <runner-name-yang-akan-dipakai-di-yaml> <token> <repo-atau-url>"
    echo ""
    echo "Contoh:"
    echo "  $0 runner-flutter-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ https://github.com/omni-ce/flutter-mobile-internal"
    echo "  $0 runner-flutter-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ omni-ce/flutter-mobile-internal"
    echo "======================================================================"
    exit 1
fi

# Jika user menginput 'owner/repo', ubah otomatis menjadi 'https://github.com/owner/repo'
if [[ "$REPO_INPUT" =~ ^https?:// ]]; then
    REPO_URL="$REPO_INPUT"
else
    REPO_URL="https://github.com/${REPO_INPUT#/}"
fi

echo "======================================================================"
echo "🚀 Memulai inisialisasi GitHub Runner..."
echo "  - Nama Runner : $RUNNER_NAME"
echo "  - GitHub URL  : $REPO_URL"
echo "  - Token       : ${RUNNER_TOKEN:0:6}******"
echo "======================================================================"

# 1. Deteksi arsitektur OS
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64)
        RUNNER_ARCH="x64"
        ;;
    aarch64|arm64)
        RUNNER_ARCH="arm64"
        ;;
    armv7l)
        RUNNER_ARCH="arm"
        ;;
    *)
        echo "❌ Arsitektur $ARCH_RAW tidak didukung oleh GitHub Runner."
        exit 1
        ;;
esac
echo "ℹ️  Arsitektur terdeteksi: $RUNNER_ARCH ($ARCH_RAW)"

# 2. Ambil versi rilis terbaru GitHub Runner
echo "🔍 Mengecek versi GitHub Runner terbaru..."
LATEST_VERSION=""

# Cara 1: Cek HTTP header redirect (tidak terkena rate limit GitHub API)
REDIRECT_URL=$(curl -fsSLI -o /dev/null -w "%{url_effective}" https://github.com/actions/runner/releases/latest 2>/dev/null || true)
if [ -n "$REDIRECT_URL" ]; then
    LATEST_TAG=$(basename "$REDIRECT_URL" | tr -d '\r')
    LATEST_VERSION="${LATEST_TAG#v}"
fi

# Cara 2: Fallback ke GitHub REST API jika cara 1 kosong
if [ -z "$LATEST_VERSION" ]; then
    LATEST_TAG=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest 2>/dev/null | grep -oP '"tag_name":\s*"v?\K([^"]+)' || true)
    LATEST_VERSION="${LATEST_TAG#v}"
fi

# Fallback terakhir jika koneksi ke GitHub release gagal
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION="2.322.0"
    echo "⚠️  Gagal mendeteksi versi via internet, menggunakan versi default: $LATEST_VERSION"
else
    echo "✅ Versi terbaru ditemukan: v$LATEST_VERSION"
fi

TARBALL_NAME="actions-runner-linux-${RUNNER_ARCH}-${LATEST_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${LATEST_VERSION}/${TARBALL_NAME}"

# 3. Setup direktori cache installer & download jika belum ada di cache
CACHE_DIR="${RUNNER_CACHE_DIR:-/home/runner/cache}"
mkdir -p "$CACHE_DIR"

if [ ! -f "$CACHE_DIR/$TARBALL_NAME" ]; then
    echo "📥 Mengunduh package runner: $DOWNLOAD_URL ..."
    curl -fSL -o "$CACHE_DIR/$TARBALL_NAME" "$DOWNLOAD_URL"
    echo "✅ Download selesai dan disimpan di cache: $CACHE_DIR/$TARBALL_NAME"
else
    echo "⚡ Menggunakan file tarball dari cache: $CACHE_DIR/$TARBALL_NAME"
fi

# 4. Buat folder terisolasi untuk runner ini
BASE_RUNNERS_DIR="${RUNNERS_BASE_DIR:-/home/runner/runners}"
TARGET_RUNNER_DIR="$BASE_RUNNERS_DIR/$RUNNER_NAME"

if [ -d "$TARGET_RUNNER_DIR" ]; then
    echo "⚠️  Direktori runner $TARGET_RUNNER_DIR sudah ada."
    # Jika sudah jalan di PM2, hentikan dulu
    pm2 stop "$RUNNER_NAME" 2>/dev/null || true
    pm2 delete "$RUNNER_NAME" 2>/dev/null || true
    rm -rf "$TARGET_RUNNER_DIR"
fi

mkdir -p "$TARGET_RUNNER_DIR"
echo "📦 Mengekstrak installer ke $TARGET_RUNNER_DIR..."
tar xzf "$CACHE_DIR/$TARBALL_NAME" -C "$TARGET_RUNNER_DIR"

# 5. Konfigurasi GitHub Runner
echo "⚙️  Mendaftarkan runner ke GitHub..."
cd "$TARGET_RUNNER_DIR"

export RUNNER_ALLOW_RUNASROOT=1

./config.sh \
    --url "$REPO_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_NAME" \
    --work "_work" \
    --unattended \
    --replace

# 6. Registrasikan ke PM2 agar auto-start & auto-restart
echo "⚡ Menjalankan runner dengan PM2..."
pm2 start ./run.sh --name "$RUNNER_NAME" --cwd "$TARGET_RUNNER_DIR" --interpreter bash

# Simpan state PM2 agar survive saat container atau host reboot
pm2 save

echo "======================================================================"
echo "🎉 GitHub Runner [$RUNNER_NAME] BERHASIL DIAKTIFKAN!"
echo "======================================================================"
echo "Status PM2 saat ini:"
pm2 status "$RUNNER_NAME"
echo ""
echo "📌 Cara pemakaian di GitHub Actions Workflow (.github/workflows/ci.yml):"
echo "jobs:"
echo "  build:"
echo "    runs-on: $RUNNER_NAME"
echo "    # atau: runs-on: [self-hosted, $RUNNER_NAME]"
echo "    steps:"
echo "      - uses: actions/checkout@v4"
echo "======================================================================"
