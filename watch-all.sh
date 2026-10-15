#!/bin/bash
set -e

# ==============================================================================
# Helper Script to enable watch mode for all running PM2 processes
# ==============================================================================
echo "======================================================================"
echo "👀 Mengaktifkan Watch Mode untuk Semua Runner di PM2..."
echo "======================================================================"

# Ubah semua process PM2 yang terdaftar ke mode watch
pm2 restart all --watch || true

# Simpan state PM2 agar perubahan watch mode tetap tersimpan (persist)
pm2 save || true

echo ""
echo "✅ Semua runner berhasil diubah ke mode watch!"
echo ""
pm2 status
