<#

    :: Author  : Freenitial on GitHub
    :: Version : 1.2 - Now compatible PowerShell 2.0

    @cls & @echo off & cd /d "%~dp0"
    set "arch=x32"
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "arch=x64"
    if defined PROCESSOR_ARCHITEW6432      set "arch=x64"
    if "%arch%"=="x32" (set "powershell=%windir%\system32\WindowsPowerShell\v1.0\powershell.exe") ^
    else               (set "powershell=%windir%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe")
    if not exist %powershell% (echo ERROR - Powershell not detected & echo Press any key to exit. & pause >nul & exit /b 1)
    if exist %windir%\Sysnative\reg.exe (set "regNoRedirection=%windir%\Sysnative\reg.exe") else (set "regNoRedirection=%windir%\system32\reg.exe")
    net session >nul 2>&1 && (set "runas=") || (set "runas=-Verb RunAs")
    for /f "tokens=3*" %%A in ('%regNoRedirection% query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "osname=%%A %%B"
    set "os_name="
    echo %osname% | findstr /i /c:"Windows XP" >nul && set "os_name=XP"
    echo %osname% | findstr /i /c:" 2003"      >nul && set "os_name=2003"
    echo %osname% | findstr /i /c:"Vista"      >nul && set "os_name=Vista"
    %regNoRedirection% query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v CSDVersion >nul 2>&1 || (set "SP=0" & goto :skipSP)
    for /f "tokens=3*" %%A in ('%regNoRedirection% query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" /v CSDVersion 2^>nul') do set "SP=%%A %%B"
    :skipSP
    set "arg="
    if "%os_name%"=="XP"    if "%SP:~-1%" LSS "2" set "arg=-noXtendedInput True"
    if "%os_name%"=="2003"  if "%SP:~-1%" LSS "2" set "arg=-noXtendedInput True"
    if "%os_name%"=="Vista" if "%SP:~-1%" LSS "2" set "arg=-noXtendedInput True"
    if "%os_name%"=="XP" (set "runas=") else if "%os_name%"=="2003" (set "runas=")
    if defined runas (%powershell% -Nologo -NoProfile -Ex Bypass -Window Hidden -Command "SAPS '%~nx0' -WorkingDirectory '%~dp0' %runas%" & exit /b)
    copy /y "%~nx0" "%~n0.ps1" >nul && %powershell% -NoLogo -NoProfile -Ex Bypass -Window Hidden -file "%~n0.ps1" %arg%
    exit /b
#>
param($noXtendedInput)

#######################################
#               Assemblies            #
#######################################
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Win32Api
{
    [DllImport("gdi32.dll", SetLastError = true)]
    public static extern IntPtr CreateRoundRectRgn(
        int nLeftRect,  int nTopRect,
        int nRightRect, int nBottomRect,
        int nWidthEllipse, int nHeightEllipse);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowRgn(
        IntPtr hWnd, IntPtr hRgn, bool bRedraw);
}
"@

################################
#             Icon             #
################################
$base64Icon = @"
iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAACNUlEQVR4nO1Vv2siQRR+czusaBAEIZUIgi9ptkjAgKSITUhjK/4hgooQ2A0Y8kcIIY2FlYhgYQI2FqayiCCJWKisP0ARC43Omp0U6+2J8Y4jh8WBXzXz3sx873tv5g1BRNglfuz09D3BnmBPAAAA1BylUqlAIMAYI4RwzgkhhBAA4JybU875xv6tLkppv98PBAIAQHbdKuj6JBKJUEqXy6XVar29vTXtNzc3siwDQCwW45xTSkVR1HUdAGw2WyKRMJZFo1GLxSIIAudcFMX5fJ5MJgF/olgs8jWY9k6n0+12EfH5+ZlvAyI+Pj7+zvVLgd/vLxQKPp/v8PAQABRFURTl+vra5XIdHR0BwNnZGQBMp9PT09ONPFxeXgLAbDY7OTnZzJERZrPZrNVqiKiqqkGezWYRcTAYlEolRGw0GoZd1/XJZKJpmqlyPB5vDf/+/n6lIB6Pezye4+NjAKB0pWk+n8uy7HA4Hh4eEomE1+sFgH6/f3FxsRFiu91WVZUxxhiTJOng4MAw3t3drYocDAar1aqx2igdAJyfnzudznQ6bbfbw+GwYczn81/vSSgUMseVSsUgMJIGAJDL5d7f382Svr6+cs4XiwXn/O3tDRHL5bIh+eXlBRGfnp6+ZkPXdcbYx8fHYrHo9XqZTMY8cOfvYOetgrRaLbfbrWna+nM3mwSlVNM0SZK+T4CI9XpdEIStbqPVDIfD0WhkXrA/QBCEq6urTYJvR/c3+P//gz3BnuDf8Qn58GVyWQ8YbAAAAABJRU5ErkJggg==
"@
$iconBytes  = [Convert]::FromBase64String($base64Icon)
$iconStream = New-Object System.IO.MemoryStream(,$iconBytes)
$iconImage  = [System.Drawing.Image]::FromStream($iconStream)

#######################
#  Folder definitions #
#######################
$scriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$availableFolder = Join-Path $scriptDir "Scripts"
$activeFolder    = Join-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) "scripts"
$launcherFolder  = Split-Path $scriptDir -Parent
$launcherDest    = Join-Path $launcherFolder "StartNFSU2.bat"

if (-not (Test-Path $activeFolder))   { New-Item -ItemType Directory -Path $activeFolder  -Force | Out-Null }
if (-not (Test-Path $launcherFolder)) { New-Item -ItemType Directory -Path $launcherFolder -Force | Out-Null }

##########################################
#  Read available files (filter dirs)    #
##########################################
$availableFiles = Get-ChildItem -LiteralPath $availableFolder -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
if (-not $availableFiles) {
    [System.Windows.Forms.MessageBox]::Show("No mods available","Information",
        [System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
    return
}

$rootFolder    = Split-Path (Split-Path $scriptDir -Parent) -Parent
$launcherFiles = $availableFiles | Where-Object { $_.BaseName -like "StartNFSU2_*" -and $_.Extension -eq ".bat" }
$otherFiles    = $availableFiles | Where-Object { $_.BaseName -notlike "StartNFSU2_*" }
$groups        = $otherFiles   | Group-Object BaseName

##################################
#  Colors, fonts, GUI constants  #
##################################
$bgColor     = [System.Drawing.Color]::FromArgb(90,90,90)
$fgColor     = [System.Drawing.Color]::LightGreen
$editBgColor = [System.Drawing.Color]::FromArgb(50,60,50)
$font        = New-Object System.Drawing.Font("Consolas",10,[System.Drawing.FontStyle]::Bold)
$yellow      = [System.Drawing.Color]::Yellow

####################
#  Main Form set-up
####################
$form = New-Object System.Windows.Forms.Form
$form.Text            = " NFSU2 Mods Settings"
$form.Size            = New-Object System.Drawing.Size(450,280)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.BackColor       = $bgColor
$form.ForeColor       = $fgColor
$form.Font            = $font
$form.Icon            = [System.Drawing.Icon]::FromHandle($iconImage.GetHicon())

$titleBar           = New-Object System.Windows.Forms.Panel
$titleBar.Height    = $iconImage.Height        # 32
$titleBar.Dock      = 'Top'
$titleBar.BackColor = [System.Drawing.Color]::FromArgb(37,37,37)

$iconBox            = New-Object System.Windows.Forms.PictureBox
$iconBox.Image      = $iconImage
$iconBox.SizeMode   = 'AutoSize'
$iconBox.Location   = New-Object System.Drawing.Point(5,0)
$titleBar.Controls.Add($iconBox)

$titleLabel         = New-Object System.Windows.Forms.Label
$titleLabel.Text    = " NFSU2 Mods Settings"
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Font    = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize= $true
$titleLabel.Location= New-Object System.Drawing.Point(37,6)
$titleBar.Controls.Add($titleLabel)

$btnClose           = New-Object System.Windows.Forms.Button
$btnClose.Text      = "X"
$btnClose.Dock      = 'Right'
$btnClose.Width     = 40
$btnClose.FlatStyle = 'Flat'
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(60,20,20)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.Font      = New-Object System.Drawing.Font("Arial",10,[System.Drawing.FontStyle]::Bold)
$btnClose.Add_Click({ $form.Close() })
$titleBar.Controls.Add($btnClose)

# Drag window
$titleBar.Add_MouseDown({ $script:drag = $true; $script:off = $form.PointToScreen($_.Location) - $form.Location })
$titleBar.Add_MouseMove({ if($script:drag){ $form.Location = $titleBar.PointToScreen($_.Location) - $script:off } })
$titleBar.Add_MouseUp({   $script:drag = $false })

################################
#  Scrollable mods container   #
################################
$modsPanel               = New-Object System.Windows.Forms.FlowLayoutPanel
$modsPanel.Dock          = 'Fill'
$modsPanel.AutoScroll    = $true
$modsPanel.WrapContents  = $false
$modsPanel.FlowDirection = 'TopDown'
$modsPanel.BackColor     = $editBgColor

$modsLabel            = New-Object System.Windows.Forms.Label
$modsLabel.Text       = 'Mods (UnCheck/ReCheck = Restore default options):'
$modsLabel.ForeColor  = [System.Drawing.Color]::White
$modsLabel.AutoSize   = $true
$modsLabel.Font       = New-Object System.Drawing.Font('Arial',11,[System.Drawing.FontStyle]::Bold)
$modsLabel.Margin     = New-Object System.Windows.Forms.Padding(10,12,10,2)
$modsPanel.Controls.Add($modsLabel)

####################################################
#  Helpers – sync classic mods & launcher scripts  #
####################################################
function Sync-ModFiles {
    param([string]$baseName,[bool]$enabled)

    $targetFolder = if ($baseName -eq 'd3d9') { $rootFolder } else { $activeFolder }
    $sourceFiles  = Get-ChildItem -LiteralPath $availableFolder -Filter "$baseName.*" -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }

    foreach ($sf in $sourceFiles) {
        $dest = Join-Path $targetFolder $sf.Name
        if ($enabled) { Copy-Item -LiteralPath $sf.FullName -Destination $dest -Force }
        elseif (Test-Path $dest) { Remove-Item -LiteralPath $dest -Force }
    }
}

function Copy-Launcher {
    param([System.IO.FileInfo]$file)
    Copy-Item -LiteralPath $file.FullName -Destination $launcherDest -Force
}

#####################################################
#      Classic mods => CheckBox + OPTIONS button    #
#####################################################
foreach ($grp in $groups) {

    $row = New-Object System.Windows.Forms.TableLayoutPanel
    $row.ColumnCount   = 2
    $row.RowCount      = 1
    $row.AutoSize      = $true
    $row.Dock          = 'Top'
    $row.BackColor     = $editBgColor
    $row.Margin        = New-Object System.Windows.Forms.Padding(0,2,0,2)

    # Col styles : checkbox auto, bouton fixe à droite
    $row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent,100)))
    $row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))

    # ---------- CheckBox ----------
    $baseName    = $grp.Name
    $displayName = $baseName -replace '^NFSUnderground2\.','' -replace '^NFSU_',''
    $chk         = New-Object System.Windows.Forms.CheckBox
    $chk.Text    = $displayName
    $chk.ForeColor = $fgColor
    $chk.AutoSize  = $true
    $chk.Margin    = New-Object System.Windows.Forms.Padding(12,2,4,2)
    $chk.Tag       = $baseName

    if ($baseName -eq 'NFSU_XtendedInput')   { $chk.Text += ' - Force KeyBindings' }
    if ($baseName -eq 'd3d9')                { $chk.Text += ' (Can fix blinking HUD, lower FPS)'; $chk.ForeColor = $yellow }
    if ($noXtendedInput -eq "True" -and $baseName -eq 'NFSU_XtendedInput') {
        $chk.Text     += ' (Not compatible)'
        $chk.ForeColor = [System.Drawing.Color]::OrangeRed
        $chk.Font      = New-Object System.Drawing.Font($font,[System.Drawing.FontStyle]::Bold)
    }

    $initialFolder = if ($baseName -eq 'd3d9') { $rootFolder } else { $activeFolder }
    $chk.Checked   = Test-Path (Join-Path $initialFolder "$baseName.*")

    # ---------- Options button ----------
    $btnOpt = $null
    if (Test-Path (Join-Path $availableFolder "$baseName.ini")) {
        $btnOpt          = New-Object System.Windows.Forms.Button
        $btnOpt.Text     = 'Options'
        $btnOpt.AutoSize = $true
        $btnOpt.Margin   = New-Object System.Windows.Forms.Padding(4,2,4,2)
        $btnOpt.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btnOpt.FlatAppearance.BorderSize = 0
        $btnOpt.Tag      = if ($baseName -eq 'd3d9') {
                               Join-Path $rootFolder "$baseName.ini"
                           } else {
                               Join-Path $activeFolder "$baseName.ini"
                           }
        $btnOpt.Enabled  = $chk.Checked

        # Open associated .ini
        $btnOpt.Add_Click({
            param($s,$e)
            if (Test-Path $s.Tag) { & notepad $s.Tag }
            else {
                [System.Windows.Forms.MessageBox]::Show("File not found:`n$($s.Tag)",
                    "Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
            }
        })

        $btnOpt.Add_HandleCreated({
            param($sender,$e)
            $d = [Math]::Min($sender.Width, $sender.Height)
            $r = [Win32Api]::CreateRoundRectRgn(0,0,$sender.Width,$sender.Height,$d,$d)
            [Win32Api]::SetWindowRgn($sender.Handle,$r,$true) | Out-Null
        })
    }

    # ---------- Checkbox handler ----------
    $chk.Add_CheckedChanged({
        param($s,$e)
        try {
            Sync-ModFiles -baseName $s.Tag -enabled $s.Checked
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Could not process '$($s.Tag)' : $($_.Exception.Message)",
                "Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
            $s.Checked = -not $s.Checked
        }
        foreach ($ctl in $s.Parent.Controls) {
            if ($ctl -is [System.Windows.Forms.Button]) { $ctl.Enabled = $s.Checked }
        }
    })

    $row.Controls.Add($chk,    0, 0)
    if ($btnOpt) { $row.Controls.Add($btnOpt, 1, 0) }
    $modsPanel.Controls.Add($row)
}

#######################################
#    Launchers => RadioButton list    #
#######################################
if ($launcherFiles) {

    # --- Detect active launcher ---
    $currentSuffix = $null
    if (Test-Path $launcherDest) {
        foreach ($line in Get-Content -LiteralPath $launcherDest -TotalCount 5 -EA SilentlyContinue) {
            if ($line -match '\btitle\s+([^\s&]+)') {
                $val = $Matches[1].Trim()
                $currentSuffix = $val -replace '^StartNFSU2_',''
                break
            }
        }
    }

    # Label
    $sep = New-Object System.Windows.Forms.Label
    $sep.Text = 'Launcher:'
    $sep.ForeColor = [System.Drawing.Color]::White
    $sep.AutoSize = $true
    $sep.Font = New-Object System.Drawing.Font('Arial',11,[System.Drawing.FontStyle]::Bold)
    $sep.Margin = New-Object System.Windows.Forms.Padding(10,12,10,2)
    $modsPanel.Controls.Add($sep)

    foreach ($lf in $launcherFiles) {

        $suffix = $lf.BaseName.Substring(11)   # après "StartNFSU2_"

        $rb            = New-Object System.Windows.Forms.RadioButton
        $rb.Text       = $suffix
        $rb.ForeColor  = $fgColor
        $rb.AutoSize   = $true
        $rb.Margin     = New-Object System.Windows.Forms.Padding(22,4,10,4)
        $rb.Tag        = $lf.FullName          # <— chemin stocké ici

        if ($suffix -eq $currentSuffix) { $rb.Checked = $true }

        $rb.Add_CheckedChanged({
            param($sender,$e)
            if ($sender.Checked) {
                try {
                    Copy-Item -LiteralPath $sender.Tag -Destination $launcherDest -Force
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Could not copy launcher '$($sender.Text)' : $($_.Exception.Message)",
                        'Error',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
                }
            }
        })

        $modsPanel.Controls.Add($rb)
    }
}


#################
#      Main     #
#################
$form.Controls.Add($modsPanel)
$form.Controls.Add($titleBar)

$hRgn=[Win32Api]::CreateRoundRectRgn(0,0,$form.Width,$form.Height,15,15)
[Win32Api]::SetWindowRgn($form.Handle,$hRgn,$true) | Out-Null

$form.Add_Shown({
    $neededWidth = $modsPanel.PreferredSize.Width + 20
    if ($neededWidth -gt $form.Width) {
        $form.Width = $neededWidth
        $hRgn = [Win32Api]::CreateRoundRectRgn(0,0,$form.Width,$form.Height,15,15)
        [Win32Api]::SetWindowRgn($form.Handle,$hRgn,$true) | Out-Null
    }
})

[void]$form.ShowDialog()
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force