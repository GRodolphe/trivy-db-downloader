# Trivy Database Downloader

## Synopsis
This script downloads the Trivy database without using Docker or Oras as described in the Trivy documentation in restrited environments. See: [Trivy Air-Gap Documentation](https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment).

## Description
This script queries the GitHub Container Registry API to get access tokens, lists the available tags for the desired Trivy databases (trivy-db and trivy-java-db), allows the user to select a specific tag, and downloads the corresponding database using system or custom proxy settings. 

## Usage
1. Linux
   ```sh
   git clone https://github.com/GhioRodolphe/trivy-db-downloader.git
   cd trivy-db-downloader
   chmod +x get-trivy-db.sh
   ./get-trivy-db.sh
   ```
2. Windows
   ```powershell
   git clone https://github.com/GhioRodolphe/trivy-db-downloader.git
   cd trivy-db-downloader
   .\Get-TrivyDB.ps1
   ```
The script will prompt you to select a tag for each database and download the corresponding files.

### Output
- `manifestFile-trivy-db.json`
- `trivy-db.tar.gz`
- `manifestFile-trivy-java-db.json`
- `manifestFile-trivy-java-db.tar.gz`

## References
- [ORAS Pull Command](https://oras.land/docs/commands/oras_pull/)
- [Trivy Air-Gap Documentation](https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment)
- [PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/)

## Notes
**Version:** 0.1

**Author:** GHIO Rodolphe

If you have any questions, feel free to contact me.
