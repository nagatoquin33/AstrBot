# =====================================================================
#  AstrBot Portable packaging script (Windows)
#
#  Produces a self-contained, removable-media-ready folder:
#    <OutputDir>\
#      python\        python-build-standalone runtime + core deps
#      astrbot\       AstrBot source package
#      main.py / runtime_bootstrap.py / requirements.txt
#      data\          seeded config dirs + pre-downloaded WebUI dist
#      launch.cmd / launch.sh / README-PORTABLE.md
#
#  Usage (from repo root, PowerShell 5.1+):
#    .\portable\build_portable.ps1
#    .\portable\build_portable.ps1 -OutputDir D:\AstrBot-Portable `
#        -GitHubProxy "https://gh-proxy.org/" -PipIndex "https://pypi.tuna.tsinghua.edu.cn/simple"
#    .\portable\build_portable.ps1 -PythonZip C:\downloads\cpython-...tar.gz
# =====================================================================
param(
    # Where the portable package is assembled.
    [string]$OutputDir = (Join-Path $PWD "AstrBot-Portable"),
    # CPython minor version to embed ("3.12" / "3.13").
    [string]$PythonVersion = "3.12",
    # Path to a manually downloaded python-build-standalone install_only tar.gz.
    # Use this when api.github.com is unreachable from the build machine.
    [string]$PythonZip = "",
    # Prefix prepended to GitHub release download URLs, e.g. "https://gh-proxy.org/".
    [string]$GitHubProxy = "",
    # Alternative pip index (e.g. a domestic mirror) for dependency install.
    [string]$PipIndex = "",
    # AstrBot source checkout to package. Defaults to the repo containing this script.
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "    $msg" }

if (-not (Test-Path (Join-Path $RepoRoot "main.py"))) {
    throw "RepoRoot '$RepoRoot' does not look like an AstrBot checkout (main.py missing)."
}

$pbsRepo = "astral-sh/python-build-standalone"
$assetPattern = "cpython-$PythonVersion\.\d+\+\d+\.x86_64-pc-windows-msvc-install_only\.tar\.gz"

# ---------------------------------------------------------------------
# Step 1: Python runtime
# ---------------------------------------------------------------------
$pythonExe = Join-Path $OutputDir "python\python.exe"
if (Test-Path $pythonExe) {
    Write-Step "Python runtime already present, skipping download"
    Write-Info (& $pythonExe --version)
} else {
    Write-Step "Acquiring python-build-standalone $PythonVersion runtime"

    $archive = $null
    if ($PythonZip -ne "") {
        if (-not (Test-Path $PythonZip)) { throw "PythonZip not found: $PythonZip" }
        $archive = (Resolve-Path $PythonZip).Path
        Write-Info "Using provided archive: $archive"
    } else {
        Write-Info "Querying GitHub releases..."
        $assetUrl = $null
        for ($page = 1; $page -le 3 -and -not $assetUrl; $page++) {
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$pbsRepo/releases?per_page=100&page=$page" `
                -Headers @{ "User-Agent" = "astrbot-portable-build" }
            foreach ($rel in $releases) {
                $asset = $rel.assets | Where-Object { $_.name -match $assetPattern } | Select-Object -First 1
                if ($asset) {
                    $assetUrl = $asset.browser_download_url
                    Write-Info "Found $($asset.name) in release $($rel.tag_name)"
                    break
                }
            }
        }
        if (-not $assetUrl) {
            throw ("No matching install_only asset found for Python $PythonVersion. " +
                   "Download it manually from https://github.com/$pbsRepo/releases and pass -PythonZip.")
        }

        if ($GitHubProxy -ne "") { $assetUrl = $GitHubProxy.TrimEnd("/") + "/" + $assetUrl }

        $archive = Join-Path $env:TEMP ("pbs_" + [IO.Path]::GetFileName(($assetUrl -split "/")[-1]))
        Write-Info "Downloading $assetUrl"
        Invoke-WebRequest -Uri $assetUrl -OutFile $archive -UseBasicParsing
        Write-Info ("Downloaded {0:N1} MB" -f ((Get-Item $archive).Length / 1MB))
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    Write-Info "Extracting to $OutputDir (top-level 'python/' folder)..."
    tar -xzf $archive -C $OutputDir
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed (exit $LASTEXITCODE)." }
    if (-not (Test-Path $pythonExe)) { throw "python.exe not found after extraction." }
    Write-Info (& $pythonExe --version)
}

# ---------------------------------------------------------------------
# Step 2: Core dependencies into the portable runtime
# ---------------------------------------------------------------------
Write-Step "Installing core dependencies into the portable runtime"
& $pythonExe -m pip --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Info "pip missing, bootstrapping via ensurepip..."
    & $pythonExe -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) { throw "ensurepip failed." }
}
$pipArgs = @("-m", "pip", "install", "--no-warn-script-location", "-r", (Join-Path $RepoRoot "requirements.txt"))
if ($PipIndex -ne "") { $pipArgs += @("--index-url", $PipIndex) }
& $pythonExe @pipArgs
if ($LASTEXITCODE -ne 0) { throw "pip install failed (exit $LASTEXITCODE)." }

# ---------------------------------------------------------------------
# Step 3: Copy the AstrBot source package
# ---------------------------------------------------------------------
Write-Step "Copying AstrBot source package"
robocopy (Join-Path $RepoRoot "astrbot") (Join-Path $OutputDir "astrbot") /E /NFL /NDL /NJH /NJS `
    /XD __pycache__ node_modules dist /XF "*.pyc" | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed for astrbot/ (exit $LASTEXITCODE)." }
foreach ($f in @("main.py", "runtime_bootstrap.py", "requirements.txt", "LICENSE", "EULA.md")) {
    $src = Join-Path $RepoRoot $f
    if (Test-Path $src) { Copy-Item $src $OutputDir -Force }
}
Write-Info "Source package ready."

# ---------------------------------------------------------------------
# Step 4: Seed data dirs + pre-download the WebUI dashboard
# ---------------------------------------------------------------------
Write-Step "Seeding data directory and pre-downloading WebUI dashboard"
& $pythonExe (Join-Path $PSScriptRoot "warmup_dashboard.py") $OutputDir
if ($LASTEXITCODE -ne 0) { throw "dashboard warmup failed (exit $LASTEXITCODE)." }

# ---------------------------------------------------------------------
# Step 5: Launchers and docs
# ---------------------------------------------------------------------
Write-Step "Installing launchers"
foreach ($f in @("launch.cmd", "launch.sh", "README-PORTABLE.md")) {
    Copy-Item (Join-Path $PSScriptRoot $f) $OutputDir -Force
}

# ---------------------------------------------------------------------
# Step 6: Tidy up + summary
# ---------------------------------------------------------------------
Write-Step "Cleaning build residue"
Get-ChildItem $OutputDir -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $OutputDir -Recurse -Filter "*.pyc" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$sizeGB = [math]::Round(((Get-ChildItem $OutputDir -Recurse -ErrorAction SilentlyContinue |
    Measure-Object Length -Sum).Sum) / 1GB, 2)
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " AstrBot Portable package ready: $OutputDir ($sizeGB GB)"
Write-Host " Launch it with: launch.cmd" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
