<#
.SYNOPSIS
This script downloads the Trivy database without using Docker or Oras as described
in the Trivy documentation for air-gapped environments. See: https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment

.DESCRIPTION
This script queries the GitHub Container Registry API to get access tokens, lists the available tags for the desired Trivy databases (trivy-db and trivy-java-db), allows the user to select a specific tag, and downloads the corresponding database using system or custom proxy settings. This script outputs:
  - manifestFile-trivy-db.json
  - trivy-db.tar.gz
  - manifestFile-trivy-java-db.json
  - manifestFile-trivy-java-db.tar.gz

.REFERENCES
  - https://oras.land/docs/commands/oras_pull/
  - https://aquasecurity.github.io/trivy/v0.42/docs/advanced/air-gap/#transfer-the-db-files-into-the-air-gapped-environment
  - https://learn.microsoft.com/en-us/powershell/

.NOTES
Version: 0.1
Author: GHIO Rodolphe
If you have any questions, feel free to contact me.
#>

Write-Output "Initialization..."

# Define the GitHub repositories to process
$repositories = @('aquasecurity/trivy-db', 'aquasecurity/trivy-java-db')

# Define a tab character for formatting output
$Tab = [char]9

# Iterate over each specified repository
foreach ($repository in $repositories) {
    Write-Output "`r`n[i] Starting procedure with: $repository"
    try {
        $filename = ($repository -Split "/")[1]
        
        # Retrieve the bearer token for accessing the repository
        Write-Output "$Tab Collecting bearer token"
        $tokenUrl = "https://ghcr.io/token?service=ghcr.io&scope=repository:${repository}:pull&client_id=oras-pull"
        
        # Automatically detect system proxy settings
        $proxy = ([System.Net.WebRequest]::GetSystemWebproxy()).GetProxy($tokenUrl)
        
        # Request the token
        $response = Invoke-WebRequest -Uri $tokenUrl -Proxy $proxy -ProxyUseDefaultCredentials
        $jsonContent = $response.Content | ConvertFrom-Json
        Write-Output "$Tab [i] Bearer token collected: $jsonContent"
        $token = $jsonContent.token

        # Retrieve the list of available tags for the repository
        $tagsUrl = "https://ghcr.io/v2/${repository}/tags/list"
        $headers = @{Authorization = "Bearer $token"}
        $response = Invoke-WebRequest -Uri $tagsUrl -Proxy $proxy -ProxyUseDefaultCredentials -Headers $headers
        $tags = ($response.Content | ConvertFrom-Json).tags

        # Handle user tag selection
        if ($tags.Count -eq 1) {
            Write-Output "$Tab Only one tag available for $repository: $($tags[0])"
            $selectedTag = $tags[0]
        } else {
            Write-Output "$Tab Available tags for $repository: $($tags -join ', ')"
            do {
                $selectedTag = Read-Host "$Tab > Please enter the tag you wish to download"
                if ($selectedTag -notin $tags) {
                    Write-Output "$Tab Error: The specified tag is not available. Please try again."
                }
            } while ($selectedTag -notin $tags)
        }

        # Retrieve manifest information for the selected tag
        $manifestUrl = "https://ghcr.io/v2/${repository}/manifests/$selectedTag"
        $headers = @{
            "Accept" = "application/vnd.oci.image.manifest.v1+json"
            "Authorization" = "Bearer $token"
        }
        # Download the manifest
        $manifestFileName = "manifestFile-$filename.json"
        Invoke-WebRequest -Uri $manifestUrl -Proxy $proxy -ProxyUseDefaultCredentials -Headers $headers -Outfile $manifestFileName 
        $manifest = Get-Content $manifestFileName | ConvertFrom-Json
        Write-Output "$Tab [i] Manifest information: `r`n$Tab$Tab$manifest"
        $digest = $manifest.layers.digest
        Write-Output "$Tab [i] Identified digest: $digest"

        # Prepare the URL to download the database
        $dbUrl = "https://ghcr.io/v2/${repository}/blobs/$digest"
        Write-Output "$Tab [i] Database URL: `r`n$Tab$Tab$dbUrl"
        
        $headers = @{
            "Authorization" = "Bearer $token"
        }
        $proxy = ([System.Net.WebRequest]::GetSystemWebproxy()).GetProxy($dbUrl)
        
        # Ask the user if they want to proceed with the download
        $response = Read-Host "$Tab > Do you want to download the database? (Yes/No)"
        if ($response -eq "Yes") {
            Write-Output "$Tab [i] Download starting, please wait."
            Invoke-WebRequest -Uri $dbUrl -Proxy $proxy -ProxyUseDefaultCredentials -Headers $headers -Outfile "$filename.tar.gz"
            Write-Output "$Tab [OK] Download of $repository completed."
        } else {
            Write-Output "$Tab Download of $repository cancelled."
        }
    } catch {
        Write-Error "[NOK] An error occurred: $_"
    }
}
Write-Output "`r`nEnd, closing."
