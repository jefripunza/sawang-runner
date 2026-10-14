# Sawang Multi-Runner (GitHub Actions Runner with PM2)

Container Ubuntu untuk menjalankan **multiple GitHub Actions self-hosted runners** dalam satu container, dikelola secara otomatis menggunakan **PM2 Process Manager**.

Jika server fisik atau host Docker reboot, container akan menyala kembali secara otomatis (via Docker restart policy) dan **PM2 akan otomatis membangkitkan (resurrect) semua runner** yang pernah dibuat.

---

## 🌟 Fitur Utama

1. **Multi-Runner dalam Satu Container**:
   Setiap runner diisolasi di foldernya masing-masing (`/home/runner/runners/<nama-runner>`), memungkinkan puluhan runner berjalan paralel tanpa konflik.
2. **Auto-Restart & Resurrect dengan PM2**:
   Runner dijalankan di bawah pengawasan PM2. Jika runner crash atau host reboot, PM2 akan menghidupkan kembali runner secara otomatis (`pm2 resurrect`).
3. **Auto-Detect Versi GitHub Runner Terbaru**:
   Script `github-init.sh` secara dinamis mengambil versi rilis terbaru dari GitHub Actions runner, mendeteksi arsitektur sistem (`x64` atau `arm64`), dan mengunduh package yang tepat.
4. **Smart Package Caching**:
   File tarball installer di-cache di folder `/home/runner/cache`. Pembuatan runner ke-2, ke-3, dst. tidak perlu mengunduh ulang 100+ MB file installer.
5. **Dukungan Docker di Runner**:
   Docker CLI sudah terpasang dan docker socket `/var/run/docker.sock` dimount ke host sehingga pipeline CI/CD dapat mengeksekusi perintah Docker (`docker build`, `docker push`, dll).
6. **Data Terpersistensi**:
   Volume Docker digunakan untuk menyimpan folder `runners`, `cache`, dan konfigurasi state PM2 (`dump.pm2`), sehingga aman dari restart maupun recreate container.

---

## 🚀 Panduan Memulai Cepat

### 1. Menjalankan Container

Jalankan container menggunakan Docker Compose:

```bash
docker compose up -d --build
```

Cek log container:

```bash
docker logs -f sawang-runner
```

---

### 2. Menambahkan GitHub Runner Baru

Dapatkan token pendaftaran runner dari GitHub:
- **Repository**: Masuk ke `Settings > Actions > Runners > New runner`
- **Organization**: Masuk ke `Settings > Actions > Runners > New runner`

Jalankan perintah registrasi di dalam container:

```bash
# Sintaks:
# ./github-init.sh <runner-name-yang-akan-dipakai-di-yaml> <token> [github-url]

# Contoh 1: Menggunakan URL default dari GITHUB_URL di docker-compose.yml
docker exec -it sawang-runner ./github-init.sh flutter-runner-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ

# Contoh 2: Menentukan URL repositori atau organisasi secara spesifik
docker exec -it sawang-runner ./github-init.sh flutter-runner-02 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ https://github.com/omni-ce/flutter-mobile-internal
```

> **Catatan Label:** Script akan otomatis memberi label pada runner sesuai dengan `<runner-name>`.

---

### 3. Menggunakan Runner di Workflow GitHub Actions

Pada file workflow Anda (misal `.github/workflows/ci.yml`), tentukan `runs-on` menggunakan nama runner yang Anda daftarkan:

```yaml
name: Flutter Build CI

on:
  push:
    branches: [ main ]

jobs:
  build:
    # Cukup panggil nama runner yang didaftarkan tadi:
    runs-on: flutter-runner-01
    
    # Atau jika ingin spesifik kombinasi label:
    # runs-on: [self-hosted, flutter-runner-01]

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Tests / Build
        run: |
          echo "Running on self-hosted sawang-runner!"
          docker --version
```

---

### 4. Melihat Daftar Runner yang Sedang Aktif

Untuk memantau runner yang sedang berjalan di PM2:

```bash
docker exec -it sawang-runner ./runner-list.sh
```

Atau langsung menggunakan CLI PM2:

```bash
# Cek tabel status
docker exec -it sawang-runner pm2 status

# Pantau resource CPU & RAM real-time
docker exec -it sawang-runner pm2 monit

# Cek log spesifik suatu runner
docker exec -it sawang-runner pm2 logs flutter-runner-01
```

---

### 5. Menghapus Runner

Untuk menghapus runner dari GitHub dan menghentikannya dari PM2:

```bash
# Dapatkan 'removal token' dari halaman Settings > Actions > Runners di GitHub
docker exec -it sawang-runner ./github-remove.sh <runner-name> <removal-token>

# Contoh:
docker exec -it sawang-runner ./github-remove.sh flutter-runner-01 BKQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ
```

---

## 🛠️ Detail Teknis

| Komponen | Penjelasan |
| :--- | :--- |
| **Base Image** | Ubuntu 24.04 LTS |
| **Process Manager** | PM2 (dikendalikan via `entrypoint.sh` & `github-init.sh`) |
| **Node.js** | Node.js 22 LTS |
| **Path Runner** | `/home/runner/runners/<runner-name>` |
| **State PM2** | `/home/runner/.pm2/dump.pm2` (disimpan otomatis saat `pm2 save`) |
| **Entrypoint** | Mengeksekusi `pm2 resurrect` lalu streaming log dengan `pm2 logs` |
