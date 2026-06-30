# ============================================================
# Deploy-NXLog-GPO.ps1
# Sets up a software share + GPO to deploy NXLog to all
# domain-joined computers automatically (Computer Configuration
# > Software Installation > Assigned package).
#
# Author: Ibnousoufyane Ayman
# Domain: IB.local
# Run on: DC01
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   NXLog GPO Deployment Setup - IB.local" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ── STEP 1: Create software share ────────────────────────────
Write-Host "`n[1/4] Creating software share..." -ForegroundColor Yellow

New-Item -Path "C:\Software" -ItemType Directory -Force | Out-Null

try {
    New-SmbShare -Name "Software" -Path "C:\Software" -FullAccess "S-1-1-0" -ErrorAction Stop
    Write-Host "   [+] SMB Share 'Software' created" -ForegroundColor Green
} catch {
    Write-Host "   [!] Share already exists or error: $_" -ForegroundColor Gray
}

# Grant NTFS permissions so computer accounts can read/execute the MSI
icacls C:\Software /grant "Utilisateurs authentifiés:(OI)(CI)F" | Out-Null
icacls C:\Software /grant "Ordinateurs du domaine:(OI)(CI)F"   | Out-Null
Write-Host "   [+] NTFS permissions granted to domain computers" -ForegroundColor Green

# ── STEP 2: Place MSI ─────────────────────────────────────────
Write-Host "`n[2/4] Checking for NXLog MSI..." -ForegroundColor Yellow

$msiPath = "C:\Software\nxlog.msi"
if (Test-Path $msiPath) {
    $size = (Get-Item $msiPath).Length
    Write-Host "   [+] Found nxlog.msi ($([math]::Round($size/1MB,1)) MB)" -ForegroundColor Green
} else {
    Write-Host "   [!] nxlog.msi not found in C:\Software" -ForegroundColor Red
    Write-Host "       Download manually from https://nxlog.co/products/nxlog-community-edition/download" -ForegroundColor Red
    Write-Host "       and place it at C:\Software\nxlog.msi before continuing." -ForegroundColor Red
}

# ── STEP 3: Create the GPO ────────────────────────────────────
Write-Host "`n[3/4] Creating GPO..." -ForegroundColor Yellow

try {
    New-GPO -Name "GPO-Deploy-NXLog" -Comment "Deploy NXLog to all domain computers" -ErrorAction Stop | Out-Null
    Write-Host "   [+] GPO-Deploy-NXLog created" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists" -ForegroundColor Gray
}

# Link to the Computers OU
try {
    New-GPLink -Name "GPO-Deploy-NXLog" -Target "OU=Computers,OU=IB-Company,DC=IB,DC=local" -ErrorAction Stop | Out-Null
    Write-Host "   [+] GPO linked to OU=Computers,OU=IB-Company" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already linked" -ForegroundColor Gray
}

Write-Host "`n   NOTE: The Software Installation package itself (Computer" -ForegroundColor Yellow
Write-Host "   Configuration > Policies > Software Settings > Software" -ForegroundColor Yellow
Write-Host "   Installation > New > Package) must be added manually via" -ForegroundColor Yellow
Write-Host "   the Group Policy Management Editor GUI, pointing to:" -ForegroundColor Yellow
Write-Host "   \\DC01\Software\nxlog.msi  (deployment method: Assigned)" -ForegroundColor Yellow

# ── STEP 4: Summary ───────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "         SETUP COMPLETE - NEXT STEPS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "1. Ensure CLIENT-01 is moved into OU=Computers,OU=IB-Company" -ForegroundColor White
Write-Host "2. On the client: gpupdate /force" -ForegroundColor White
Write-Host "3. Full restart (not just gpupdate) is required for software" -ForegroundColor White
Write-Host "   installation policies to apply" -ForegroundColor White
Write-Host "4. Verify with: Get-Service nxlog" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
