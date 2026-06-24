# ============================================================
# AD-Setup.ps1
# Complete Active Directory Setup Script
# Author: Ayman Ibnousoufyane
# Domain: IB.local
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Active Directory Full Setup - IB.local  " -ForegroundColor Cyan
Write-Host "   By Ayman Ibnousoufyane                  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── STEP 1: Create OU Structure ──────────────────────────────
Write-Host "[1/5] Creating OU Structure..." -ForegroundColor Yellow

$OUs = @(
    "IB-Company",
    "IB-Company/IT",
    "IB-Company/Finance",
    "IB-Company/Management",
    "IB-Company/Users",
    "IB-Company/Computers",
    "IB-Company/Service-Accounts"
)

foreach ($ou in $OUs) {
    $parts = $ou.Split("/")
    if ($parts.Count -eq 1) {
        $path = "DC=IB,DC=local"
        $name = $parts[0]
    } else {
        $parent = $parts[0]
        $name = $parts[1]
        $path = "OU=$parent,DC=IB,DC=local"
    }
    try {
        New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
        Write-Host "   [+] OU Created: $name" -ForegroundColor Green
    } catch {
        Write-Host "   [!] OU already exists: $name" -ForegroundColor Gray
    }
}

# ── STEP 2: Create Security Groups ───────────────────────────
Write-Host ""
Write-Host "[2/5] Creating Security Groups..." -ForegroundColor Yellow

$Groups = @(
    @{ Name="GRP-IT";         Path="OU=IT,OU=IB-Company,DC=IB,DC=local";         Desc="IT Department Group" },
    @{ Name="GRP-Finance";    Path="OU=Finance,OU=IB-Company,DC=IB,DC=local";     Desc="Finance Department Group" },
    @{ Name="GRP-Management"; Path="OU=Management,OU=IB-Company,DC=IB,DC=local";  Desc="Management Department Group" },
    @{ Name="GRP-AllUsers";   Path="OU=IB-Company,DC=IB,DC=local";                Desc="All Company Users" }
)

foreach ($grp in $Groups) {
    try {
        New-ADGroup -Name $grp.Name -GroupScope Global -GroupCategory Security `
            -Path $grp.Path -Description $grp.Desc -ErrorAction Stop
        Write-Host "   [+] Group Created: $($grp.Name)" -ForegroundColor Green
    } catch {
        Write-Host "   [!] Group already exists: $($grp.Name)" -ForegroundColor Gray
    }
}

# ── STEP 3: Create Users ──────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Creating Users..." -ForegroundColor Yellow

$Password = ConvertTo-SecureString "User@123456" -AsPlainText -Force

$Users = @(
    @{ First="Ayman";  Last="Admin";   Sam="a.admin";    OU="IT";         Group="GRP-IT";         Title="IT Administrator" },
    @{ First="Sara";   Last="Finance"; Sam="s.finance";  OU="Finance";    Group="GRP-Finance";    Title="Financial Analyst" },
    @{ First="Karim";  Last="Manager"; Sam="k.manager";  OU="Management"; Group="GRP-Management"; Title="Department Manager" },
    @{ First="Leila";  Last="IT";      Sam="l.it";       OU="IT";         Group="GRP-IT";         Title="IT Support" },
    @{ First="Omar";   Last="Finance"; Sam="o.finance";  OU="Finance";    Group="GRP-Finance";    Title="Accountant" }
)

foreach ($u in $Users) {
    $ouPath = "OU=$($u.OU),OU=IB-Company,DC=IB,DC=local"
    $upn    = "$($u.Sam)@IB.local"
    try {
        New-ADUser `
            -GivenName       $u.First `
            -Surname         $u.Last `
            -Name            "$($u.First) $($u.Last)" `
            -SamAccountName  $u.Sam `
            -UserPrincipalName $upn `
            -Path            $ouPath `
            -AccountPassword $Password `
            -Enabled         $true `
            -Title           $u.Title `
            -Department      $u.OU `
            -Company         "IB-Company" `
            -PasswordNeverExpires $true `
            -ErrorAction Stop

        Add-ADGroupMember -Identity $u.Group -Members $u.Sam
        Add-ADGroupMember -Identity "GRP-AllUsers" -Members $u.Sam
        Write-Host "   [+] User Created: $($u.Sam) → $($u.Group)" -ForegroundColor Green
    } catch {
        Write-Host "   [!] User already exists: $($u.Sam)" -ForegroundColor Gray
    }
}

# ── STEP 4: Install & Configure DHCP ─────────────────────────
Write-Host ""
Write-Host "[4/5] Installing and Configuring DHCP..." -ForegroundColor Yellow

try {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop | Out-Null
    Write-Host "   [+] DHCP Role Installed" -ForegroundColor Green
} catch {
    Write-Host "   [!] DHCP already installed" -ForegroundColor Gray
}

# Authorize DHCP server in AD
try {
    Add-DhcpServerInDC -DnsName "DC01.IB.local" -IPAddress 192.168.1.10 -ErrorAction Stop
    Write-Host "   [+] DHCP Server authorized in AD" -ForegroundColor Green
} catch {
    Write-Host "   [!] DHCP already authorized" -ForegroundColor Gray
}

# Create DHCP Scope
try {
    Add-DhcpServerv4Scope `
        -Name        "IB-Company-Scope" `
        -StartRange  192.168.1.100 `
        -EndRange    192.168.1.200 `
        -SubnetMask  255.255.255.0 `
        -Description "IB Company DHCP Scope" `
        -State       Active `
        -ErrorAction Stop

    # Set gateway and DNS options
    Set-DhcpServerv4OptionValue `
        -ScopeId     192.168.1.0 `
        -Router      192.168.1.1 `
        -DnsServer   192.168.1.10 `
        -DnsDomain   "IB.local"

    Write-Host "   [+] DHCP Scope created: 192.168.1.100 - 192.168.1.200" -ForegroundColor Green
} catch {
    Write-Host "   [!] DHCP Scope already exists" -ForegroundColor Gray
}

# Notify DHCP config complete
Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 `
    -Name ConfigurationState -Value 2 -ErrorAction SilentlyContinue

# ── STEP 5: Create GPOs ───────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Creating GPOs..." -ForegroundColor Yellow

# GPO 1 — Password Policy
try {
    $gpo1 = New-GPO -Name "GPO-PasswordPolicy" -Comment "Enforce strong password policy" -ErrorAction Stop
    New-GPLink -Name "GPO-PasswordPolicy" -Target "DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-PasswordPolicy" `
        -Key "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" `
        -ValueName "MaximumPasswordAge" -Type DWord -Value 90 | Out-Null
    Write-Host "   [+] GPO Created: GPO-PasswordPolicy" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-PasswordPolicy" -ForegroundColor Gray
}

# GPO 2 — Screen Lock (lock after 10 min)
try {
    $gpo2 = New-GPO -Name "GPO-ScreenLock" -Comment "Lock screen after 10 minutes" -ErrorAction Stop
    New-GPLink -Name "GPO-ScreenLock" -Target "OU=IB-Company,DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-ScreenLock" `
        -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaveTimeOut" -Type String -Value "600" | Out-Null
    Set-GPRegistryValue -Name "GPO-ScreenLock" `
        -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "ScreenSaverIsSecure" -Type String -Value "1" | Out-Null
    Set-GPRegistryValue -Name "GPO-ScreenLock" `
        -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
        -ValueName "SCRNSAVE.EXE" -Type String -Value "scrnsave.scr" | Out-Null
    Write-Host "   [+] GPO Created: GPO-ScreenLock" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-ScreenLock" -ForegroundColor Gray
}

# GPO 3 — Disable USB Storage
try {
    $gpo3 = New-GPO -Name "GPO-DisableUSB" -Comment "Block USB storage devices" -ErrorAction Stop
    New-GPLink -Name "GPO-DisableUSB" -Target "OU=Finance,OU=IB-Company,DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-DisableUSB" `
        -Key "HKLM\System\CurrentControlSet\Services\UsbStor" `
        -ValueName "Start" -Type DWord -Value 4 | Out-Null
    Write-Host "   [+] GPO Created: GPO-DisableUSB (applied to Finance)" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-DisableUSB" -ForegroundColor Gray
}

# GPO 4 — Disable Control Panel for standard users
try {
    $gpo4 = New-GPO -Name "GPO-RestrictControlPanel" -Comment "Prevent access to Control Panel" -ErrorAction Stop
    New-GPLink -Name "GPO-RestrictControlPanel" -Target "OU=Finance,OU=IB-Company,DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-RestrictControlPanel" `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
        -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null
    Write-Host "   [+] GPO Created: GPO-RestrictControlPanel (applied to Finance)" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-RestrictControlPanel" -ForegroundColor Gray
}

# GPO 5 — Custom Wallpaper (company branding)
try {
    $gpo5 = New-GPO -Name "GPO-Wallpaper" -Comment "Set company wallpaper" -ErrorAction Stop
    New-GPLink -Name "GPO-Wallpaper" -Target "OU=IB-Company,DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-Wallpaper" `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
        -ValueName "Wallpaper" -Type String -Value "\\DC01\SYSVOL\IB.local\wallpaper.jpg" | Out-Null
    Set-GPRegistryValue -Name "GPO-Wallpaper" `
        -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
        -ValueName "WallpaperStyle" -Type String -Value "2" | Out-Null
    Write-Host "   [+] GPO Created: GPO-Wallpaper" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-Wallpaper" -ForegroundColor Gray
}

# GPO 6 — Disable CMD and PowerShell for standard users
try {
    $gpo6 = New-GPO -Name "GPO-DisableCMD" -Comment "Block CMD and PowerShell for standard users" -ErrorAction Stop
    New-GPLink -Name "GPO-DisableCMD" -Target "OU=Finance,OU=IB-Company,DC=IB,DC=local" | Out-Null
    Set-GPRegistryValue -Name "GPO-DisableCMD" `
        -Key "HKCU\Software\Policies\Microsoft\Windows\System" `
        -ValueName "DisableCMD" -Type DWord -Value 1 | Out-Null
    Write-Host "   [+] GPO Created: GPO-DisableCMD (applied to Finance)" -ForegroundColor Green
} catch {
    Write-Host "   [!] GPO already exists: GPO-DisableCMD" -ForegroundColor Gray
}

# ── Summary ───────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "         SETUP COMPLETE - SUMMARY          " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Domain      : IB.local" -ForegroundColor White
Write-Host "DC          : DC01 (192.168.1.10)" -ForegroundColor White
Write-Host ""
Write-Host "OUs created :" -ForegroundColor Yellow
Get-ADOrganizationalUnit -Filter * | Where-Object {$_.DistinguishedName -like "*IB-Company*"} | 
    Select-Object -ExpandProperty Name | ForEach-Object { Write-Host "   - $_" -ForegroundColor Green }
Write-Host ""
Write-Host "Users created :" -ForegroundColor Yellow
Get-ADUser -Filter * -SearchBase "OU=IB-Company,DC=IB,DC=local" | 
    Select-Object Name, SamAccountName | 
    ForEach-Object { Write-Host "   - $($_.Name) ($($_.SamAccountName))" -ForegroundColor Green }
Write-Host ""
Write-Host "GPOs created :" -ForegroundColor Yellow
Get-GPO -All | Where-Object {$_.DisplayName -like "GPO-*"} | 
    ForEach-Object { Write-Host "   - $($_.DisplayName)" -ForegroundColor Green }
Write-Host ""
Write-Host "DHCP Scope  : 192.168.1.100 - 192.168.1.200" -ForegroundColor White
Write-Host ""
Write-Host "Next step: Join CLIENT01 to IB.local domain!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
