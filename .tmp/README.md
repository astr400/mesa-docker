# Local MESA archives

Place the x86_64 MESA source zip and MESA SDK tarball here before building the full image. These files are gitignored because they are large.

Expected filenames:

- `mesa-26.04.1.zip`
- `mesasdk-x86_64-linux-26.6.1.tar.gz`

If they are missing, run `scripts/fetch-archives.sh` to download them from Zenodo. GitHub Actions should not fetch these on every PR; that comes later.
