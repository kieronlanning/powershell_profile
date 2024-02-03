function InstallModuleIfNotInstalled {
    param (
        # The name of the module
        [Parameter(Mandatory = $true)]
        [string]
        $moduleName
    )
    
    if (!(Get-Module -ListAvailable -Name $moduleName))
    {
        Write-Host "'$moduleName' is not installed, installing as part of profile start-up."
        Install-Module $moduleName -Scope CurrentUser -AllowPrerelease -Force -AllowClobber
    }

    # if (!(Get-InstalledModule -Name $moduleName)) {
    #     Write-Host "Importing module $moduleName"
    #     Import-Module $moduleName -Verbose
    # }

    Import-Module -Name $moduleName
}

function Make-Link ($target, $link) {
    New-Item -Path $link -ItemType Junction -Value $target
}

function MakeDirectoryAndMove {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $folder
    )

    mkdir $folder
    cd $folder
}

function IsInstalled {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName
    )
    
    $r = Get-Command -Name $CommandName -ErrorAction Ignore

    return $null -ne $r
}

function IsAdmin {
    $IsAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
    $IsAdmin
}

function GitHubFixAuthor {
    git config user.email "kieronlanning@users.noreply.github.com"
    git commit --amend --reset-author
}

function ExportScoopList {
    scoop list > $env:OneDriveConsumer\Software\Scripts\scoop-list-$env:COMPUTERNAME.txt
}

function GComet {
    param (
        [Alias('np')]
        [switch]
        ${nopush}
    )

    $IS_INSTALLED = where.exe comet
    if (!$IS_INSTALLED) {
        go install github.com/liamg/comet@latest
    }

    git add -A
    comet

    if (!$nopush) {
        git push
    }
}

function RestartExplorer() {
    stop-process -name explorer
}

function SetGitConfig {
    # Set some git aliases and config.
    git config --global alias.commite '!git commit --allow-empty -m'
    git config --global alias.commitx '!git add -A && git commit -m'
    git config --global alias.commitxp '!git add -A && git commit -m "$1" && git push'

    git config --global core.safecrlf false
    git config --global fetch.prune true
    git config --global init.defaultBranch main
    git config --global core.autocrlf input
    git config --global push.autoSetupRemote true
}

function SetEnvironmentVars() {
    # Set some environment variables.
    [System.Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1')
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1')
    [System.Environment]::SetEnvironmentVariable('NUKE_TELEMETRY_OPTOUT', '1')
    
    [System.Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8')
}

function SetGlobalAliases() {
    # Set some aliases, as they're in a function we need to use the -Scope Global parameter.
    Set-Alias -Name ghfa -Value GitHubFixAuthor -Scope Global
    Set-Alias -Name ls -Value lsd -Scope Global -Force

    Set-Alias -Name mkdirx -Value MakeDirectoryAndMove -Scope Global
    Set-Alias -Name sublime -Value "c:\Program Files\Sublime Text\sublime_text.exe" -Scope Global

    Set-Alias -Name gld -Value goland -Scope Global

    # k8s related
    Set-Alias -Name k -Value kubectl -Scope Global
    Set-Alias -Name kx -Value kubectx -Scope Global
    Set-Alias -Name kns -Value kubens -Scope Global

    Set-Alias -Name d -Value docker -Scope Global
    Set-Alias -Name n -Value nerdctl -Scope Global
    
    Set-Alias -Name re -Value RestartExplorer -Scope Global
}

function global:Init() {
    SetGlobalAliases
    SetGitConfig
    SetEnvironmentVars
}

function NewInstall() {
    $IS_INSTALLED = where.exe scoop

    if (!$IS_INSTALLED) {
        iwr -useb get.scoop.sh | iex

        scoop install aria2
        scoop config aria2-enabled true
        scoop config aria2-warning-enabled false
    }

    scoop bucket add extras
    scoop bucket add java
    scoop bucket add sysinternals

    # Utilities
    InstallFromScoop -Items sudo, wget, touch, time, `
        lsd, nano, neofetch, ffmpeg, grep, `
        sed, less, grep, sysinternals, authy, `
        signal, whatsapp

    # Game dev
    InstallFromScoop -Items reshade, godot-mono

    # Tools
    InstallFromScoop -Items 7zip, typora, `
        plex-desktop, ipscan, f.lux

    # Dev tools
    InstallFromScoop -Items git, make, nvm, yarn, `
        openjdk, `
        github, gh, glab, oh-my-posh, `
        aws, azure-cli, gcloud, `
        openapi-generator-cli, gitleaks

    # Python.. for thefuck - don't use > 3.11 right now.
    InstallFromScoop -Items python@3.11.0
    pip install thefuck

    # Go dev tool specific
    InstallFromScoop -Items go, mockery, protobuf

    # PHP dev tool specific
    InstallFromScoop -Items php, composer

    # Rust dev tool specific
    InstallFromScoop -Items rust-analyzer, rust, rustup

    # k8s/ docker/ container specific tools
    InstallFromScoop -Items argocd, k9s, krew, dive, `
        trivy, kubectl, kubens, kubectx, ctop, openlens `
        hidolint

    go install github.com/liamg/comet@latest

    yarn config set --home enableTelemetry 0

    NewInstallAdmin

    sysupdate
}

function InstallFromScoop([string[]]$Items, [switch]$Global) {
    foreach($item in $Items) {
        if ($Global) {
            scoop install $item --global
        }
        else {
            scoop install $item            
        }
    }
}

function NewInstallAdmin() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "Requires administrative privileges."

        sudo pwsh -Command NewInstallAdmin
        return
    }

    # scoop install rancher-desktop --global
    InstallFromScoop -Items rancher-desktop -Global

    rdctl set --container-engine.name=containerd
    rdctl set --application.telemetry.enabled=false
    rdctl set --application.updater.enabled=false

    winget settings --enable InstallerHashOverride

    oh-my-posh font install Meslo
    oh-my-posh font install CascadiaCode

    Write-Host "🚀 IMPORTANT: Restart your Windows Terminal and set the font to 'MesloLGS Nerd Font'."
}

function SysUpdate() {
    scoop update *

    Write-Host "🚀 Updating global scoop installations, this will require elevated permissions."

    sudo pwsh -Command SysUpdateAdmin
}

function SysUpdateAdmin() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "Requires administrative privileges."

        sudo pwsh -Command SysUpdateAdmin

        return
    }

    scoop update * -g
    # StoreUpdate
}

function StoreUpdate() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "Requires administrative privileges."

        sudo pwsh -Command StoreUpdate
        return
    }

    winget update -h --force --all --ignore-security-hash --include-unknown
}

Init

if ($host.Name -eq 'ConsoleHost') {
    # From: https://github.com/PowerShell/PSReadLine

    InstallModuleIfNotInstalled -moduleName PSReadLine

    Import-Module PSReadLine

    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    Set-PSReadLineOption -ShowToolTips
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -EditMode Windows
}

if (IsInstalled -CommandName oh-my-posh) {
    oh-my-posh init pwsh | Invoke-Expression
}

if (IsInstalled -CommandName thefuck) {
    iex "$(thefuck --alias)"
}

if (IsInstalled -CommandName glab) {
    glab completion -s powershell | Out-String | Invoke-Expression
}

if (IsInstalled -CommandName gh) {
    gh completion -s powershell  | Out-String | Invoke-Expression
}

if (IsInstalled -CommandName gitleaks) {
    gitleaks completion powershell  | Out-String | Invoke-Expression
}

if (IsInstalled -CommandName k9s) {
    k9s completion powershell  | Out-String | Invoke-Expression
}
