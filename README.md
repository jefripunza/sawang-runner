# Sawang Multi-Runner (GitHub, GitLab, & Gitea Runner with PM2)

Container Ubuntu untuk menjalankan **multiple self-hosted runners** (**GitHub Actions**, **GitLab CI/CD**, dan **Gitea / Forgejo Actions**) dalam satu container terpusat, dikelola secara otomatis menggunakan **PM2 Process Manager**.

Jika server fisik atau host Docker reboot, container akan menyala kembali secara otomatis (via Docker restart policy) dan **PM2 akan otomatis membangkitkan (resurrect) semua runner** yang pernah dibuat.

---

## 🌟 Fitur Utama

1. **Multi-Platform CI/CD Runner**:
   Mendukung pembuatan runner untuk:
   - **GitHub Actions** (`./github-init.sh`)
   - **GitLab CI/CD** (`./gitlab-init.sh`)
   - **Gitea / Forgejo Actions** (`./gitea-init.sh`)
2. **Multi-Runner dalam Satu Container**:
   Setiap runner diisolasi di foldernya masing-masing (`/home/runner/runners/<platform>/<nama-runner>`), memungkinkan puluhan runner berjalan paralel tanpa konflik port atau file.
3. **Auto-Restart & Resurrect dengan PM2**:
   Runner dijalankan di bawah pengawasan PM2. Jika runner crash atau host reboot, PM2 akan menghidupkan kembali runner secara otomatis (`pm2 resurrect`).
4. **Pre-Installed Binaries & Auto-Detect**:
   - `gitlab-runner` dan `gitea-runner` (`act_runner`) sudah terpasang di sistem (`/usr/local/bin/`).
   - `github-init.sh` secara dinamis mendeteksi dan mengunduh versi GitHub Runner terbaru.
5. **Dukungan Docker di Runner (Opsional)**:
   Docker CLI sudah terpasang. Jika pipeline CI/CD Anda membutuhkan akses untuk mengeksekusi perintah Docker (`docker build`, dll), Anda dapat menambahkan mount socket `- /var/run/docker.sock:/var/run/docker.sock` di `docker-compose.yml`.
6. **Data Terpersistensi**:
   Volume Docker digunakan untuk menyimpan folder `runners`, `cache`, dan konfigurasi state PM2 (`dump.pm2`), sehingga aman dari restart maupun recreate container.
7. **CI/CD Release Otomatis**:
   Dilengkapi workflow `.github/workflows/release.yml` untuk build multi-arch (`linux/amd64`, `linux/arm64`) dan rilis otomatis.

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

### 2. Manajemen Runner

#### A. GitHub Actions Runner
```bash
# Tambah Runner baru (sertakan URL atau owner/repo):
docker exec -it sawang-runner ./github-init.sh <runner-name> <token> <repo-atau-url>

# Contoh:
docker exec -it sawang-runner ./github-init.sh flutter-runner-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ https://github.com/omni-ce/flutter-mobile-internal
# Atau shorthand repo:
docker exec -it sawang-runner ./github-init.sh flutter-runner-01 AIQM3AJEWK4Z2T2CJ2I4YLTKZ4TUQ omni-ce/flutter-mobile-internal

# Hapus Runner:
docker exec -it sawang-runner ./github-remove.sh <runner-name> <removal-token>
```

#### B. GitLab CI/CD Runner
```bash
# Tambah Runner baru (otomatis ke hostname utama gitlab.com jika URL tidak diisi):
docker exec -it sawang-runner ./gitlab-init.sh <runner-name> <token> [gitlab-hostname-atau-url]

# Contoh 1: Hostname Utama (gitlab.com) - cukup runner name dan token
docker exec -it sawang-runner ./gitlab-init.sh gitlab-runner-01 glrt-ABC123xyz

# Contoh 2: Self-hosted GitLab - sertakan hostname / url instance Anda
docker exec -it sawang-runner ./gitlab-init.sh gitlab-runner-01 glrt-ABC123xyz gitlab.example.com
docker exec -it sawang-runner ./gitlab-init.sh gitlab-runner-01 glrt-ABC123xyz https://gitlab.example.com

# Hapus Runner:
docker exec -it sawang-runner ./gitlab-remove.sh <runner-name> [token]
```

#### C. Gitea / Forgejo Actions Runner
```bash
# Tambah Runner baru (URL instance Gitea WAJIB disertakan):
docker exec -it sawang-runner ./gitea-init.sh <runner-name> <token> <gitea-url>

# Contoh:
docker exec -it sawang-runner ./gitea-init.sh gitea-runner-01 ABCD1234EFGH5678 https://gitea.example.com

# Hapus Runner:
docker exec -it sawang-runner ./gitea-remove.sh <runner-name>
```

---

### 3. Monitoring & Status Runner

Melihat semua runner (GitHub, GitLab, Gitea) yang sedang aktif di PM2:

```bash
docker exec -it sawang-runner ./runner-list.sh
# atau
docker exec -it sawang-runner pm2 status
```

Melihat log realtime dari runner tertentu:
```bash
docker exec -it sawang-runner pm2 logs flutter-runner-01
```

Dashboard monitoring CPU & RAM interaktif di terminal:
```bash
docker exec -it sawang-runner pm2 monit
```

---

### 4. Contoh Penggunaan di Workflow CI/CD

#### GitHub Actions (`.github/workflows/ci.yml`)
```yaml
jobs:
  build:
    runs-on: flutter-runner-01
    steps:
      - uses: actions/checkout@v4
      - run: docker --version
```

#### GitLab CI (`.gitlab-ci.yml`)
```yaml
build_job:
  tags:
    - gitlab-runner-01
  script:
    - echo "Running on sawang-runner!"
```

#### Gitea Actions (`.gitea/workflows/ci.yaml`)
```yaml
jobs:
  build:
    runs-on: gitea-runner-01
    steps:
      - uses: actions/checkout@v4
      - run: docker --version
```

---

## 📦 GitHub Actions Release Workflow

File `.github/workflows/release.yml` disediakan untuk automatisasi build image Docker multi-arsitektur:
- **Triggers**: Push ke branch `main`/`master` atau trigger manual via `workflow_dispatch`.
- **Target Docker Registry**: Docker Hub (`${DOCKERHUB_USERNAME}/sawang-runner`).
- **Arsitektur**: `linux/amd64` dan `linux/arm64`.
- **Fitur Otomatis**:
  - Penomoran versi otomatis integer incrementing (`1`, `2`, `3` ...).
  - Categorized release notes berbasis conventional commits (Features, Fixes, Improvements, Maintenance) dengan opsional integrasi AI NineRouter.
