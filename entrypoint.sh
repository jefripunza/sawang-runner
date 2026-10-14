#!/bin/bash
set -e

# ==============================================================================
# Entrypoint for Multi-Runner Container with PM2
# Handles process resurrection and logs streaming
# ==============================================================================

echo "======================================================================"
echo "🤖 Menjalankan Container Multi-Runner dengan PM2..."
echo "======================================================================"

# Inisialisasi PM2 Daemon
pm2 ping > /dev/null 2>&1

# Cek apakah ada state PM2 yang sebelumnya disimpan
PM2_DUMP_FILE="${PM2_HOME:-$HOME/.pm2}/dump.pm2"
if [ -f "$PM2_DUMP_FILE" ]; then
    echo "🔄 Menemukan state PM2 tersimpan ($PM2_DUMP_FILE). Menjalankan pm2 resurrect..."
    pm2 resurrect || echo "⚠️  Gagal menjalankan pm2 resurrect, melanjutkan..."
else
    echo "ℹ️  Belum ada runner terdaftar di PM2."
    echo "💡 Gunakan: ./github-init.sh <runner-name> <token> [url] untuk menambahkan runner baru."
fi

# Tampilkan daftar runner yang aktif
echo ""
echo "📊 Daftar runner yang dikelola PM2:"
pm2 status || true
echo ""

# Tangani shutdown sinyal (docker stop / SIGTERM / SIGINT)
cleanup() {
    echo ""
    echo "🛑 Menghentikan semua runner PM2 dengan aman..."
    pm2 save || true
    pm2 kill || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Stream logs PM2 di foreground agar container tetap hidup
echo "📡 Melakukan stream log PM2 (Container siap digunakan)..."
pm2 logs &
PM2_LOG_PID=$!

wait $PM2_LOG_PID
