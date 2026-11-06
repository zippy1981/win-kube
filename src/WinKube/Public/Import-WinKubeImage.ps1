function Import-WinKubeImage {
    <#
    .SYNOPSIS
    Copies images from the local Docker engine into the Windows node's containerd.
    .DESCRIPTION
    For each image: docker save to a tarball in .cache/images (reused while the image ID is unchanged), scp it to
    the Windows node, and ctr images import it into the k8s.io namespace with --platform windows/amd64, so images
    for an older Windows build are kept too. A marker on the node records the imported image ID, so an unchanged
    image is skipped unless -Force is given. This avoids running a registry for images that exist only locally.
    .PARAMETER Image
    Image references in the local Docker engine. Accepts pipeline input. Defaults to the sample chart's images
    for -WindowsVersion: windows-nano-php and mysql-spike.
    .PARAMETER WindowsVersion
    The tag used for the default images. 2025 or 2022.
    .PARAMETER ClusterProfile
    The minikube profile. Defaults to winkube.
    .PARAMETER Force
    Import even when the node already has the same image ID.
    .EXAMPLE
    Import-WinKubeImage

    Imports windows-nano-php:2025 and mysql-spike:2025.
    .EXAMPLE
    'myapp:2025', 'myworker:2025' | Import-WinKubeImage -Force

    Imports two of your own images, even if they were imported before.
    .OUTPUTS
    WinKube.ImportedImage
    .NOTES
    Output: One object per image, with Image, ImageId, Node and Status (Imported or AlreadyPresent).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('WinKube.ImportedImage')]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Alias('Images')]
        [string[]]$Image,

        [ValidateSet('2025', '2022')]
        [string]$WindowsVersion = '2025',

        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile,

        [switch]$Force
    )

    begin {
        $requested = New-Object -TypeName System.Collections.Generic.List[string]
    }

    process {
        foreach ($item in @($Image)) {
            if ($item) {
                $requested.Add($item)
            }
        }
    }

    end {
        if ($requested.Count -eq 0) {
            $requested.Add("windows-nano-php:$WindowsVersion")
            $requested.Add("mysql-spike:$WindowsVersion")
        }
        $docker = Get-WinKubeToolPath -Name 'docker'
        $node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
        $imageCache = Join-Path -Path $script:CacheDir -ChildPath 'images'
        New-Item -ItemType Directory -Force -Path $imageCache | Out-Null

        foreach ($reference in $requested) {
            $id = "$(Invoke-WinKubeNative -FilePath $docker -Capture -ArgumentList @(
                'image', 'inspect', '--format', '{{.Id}}', $reference
            ))".Trim()
            $safe = $reference -replace '[^A-Za-z0-9._-]', '_'
            $marker = "$script:RemoteDir\imported\$safe.id"

            $present = Invoke-WinKubeWindowsNode -Node $node -ArgumentList $marker, $id -ScriptBlock {
                param($Marker, $Id)
                if ((Test-Path -LiteralPath $Marker) -and ((Get-Content -LiteralPath $Marker -Raw).Trim() -eq $Id)) {
                    'PRESENT'
                }
            }
            if (($present -join '') -match 'PRESENT' -and -not $Force) {
                Write-Verbose -Message "$reference already on $($node.Name)"
                [pscustomobject]@{
                    PSTypeName = 'WinKube.ImportedImage'
                    Image      = $reference
                    ImageId    = $id
                    Node       = $node.Name
                    Status     = 'AlreadyPresent'
                }
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($node.Name, "Import $reference")) {
                continue
            }

            $tar = Join-Path -Path $imageCache -ChildPath "$safe.tar"
            $idFile = "$tar.id"
            $cached = (Test-Path -LiteralPath $tar) -and (Test-Path -LiteralPath $idFile)
            if (-not ($cached -and (Get-Content -LiteralPath $idFile -Raw).Trim() -eq $id)) {
                Write-WinKubeStep -Message "Saving $reference"
                Invoke-WinKubeNative -FilePath $docker -ArgumentList @('save', '-o', $tar, $reference)
                Set-Content -LiteralPath $idFile -Value $id -Encoding Ascii
            }
            $sizeMB = [int]((Get-Item -LiteralPath $tar).Length / 1MB)
            Write-WinKubeStep -Message "Copying $reference to $($node.Name) ($sizeMB MB)"
            $remoteTar = "$script:RemoteDir\$safe.tar"
            Invoke-WinKubeWindowsNode -Node $node -ArgumentList "$script:RemoteDir\imported" -ScriptBlock {
                param($Path)
                New-Item -ItemType Directory -Force -Path $Path | Out-Null
            } | Out-Null
            Copy-WinKubeFileToWindowsNode -Node $node -Path $tar -Destination $remoteTar

            Write-WinKubeStep -Message "Importing $reference into containerd"
            Invoke-WinKubeWindowsNode -Node $node -ArgumentList $remoteTar, $marker, $id -ScriptBlock {
                param($Tar, $Marker, $Id)
                # --platform without an OS version lets ltsc2022 images in alongside ltsc2025 ones
                $ctr = Join-Path -Path $env:ProgramFiles -ChildPath 'containerd\ctr.exe'
                & $ctr -n k8s.io images import --platform windows/amd64 $Tar
                if ($LASTEXITCODE -ne 0) {
                    throw "ctr import failed ($LASTEXITCODE)"
                }
                Remove-Item -LiteralPath $Tar
                Set-Content -LiteralPath $Marker -Value $Id
            } | ForEach-Object -Process { Write-Verbose -Message $_ }

            [pscustomobject]@{
                PSTypeName = 'WinKube.ImportedImage'
                Image      = $reference
                ImageId    = $id
                Node       = $node.Name
                Status     = 'Imported'
            }
        }
    }
}
