# Set-PSDebug -Trace 1

function Add-CommitMsgHook {
    param (
        [string]$RepoPath = (Get-Location).Path
    )

    # Define the content of the commit-msg hook
    $commitMsgContent = @'
#!/bin/sh

# Define the conventional commit regex pattern including support for emojis anywhere in the message
commit_regex='^(feat|fix|docs|test|build|ci|perf|refactor|reverts|style|chore)(\([a-zA-Z0-9_-]+\))?: .{1,50}.*$'
error_msg="Commit message does not follow the Conventional Commits format:

<type>(<scope>): <subject>

Example Commit Messages:
- Valid: feat(parser): add ability to parse arrays 🚀
- Valid: fix(button): 🐛 handle edge cases on click
- Valid: docs: update README with new instructions 📚
- Valid: test: add unit tests for new components 🧪
- Valid: build: update dependencies for new release
- Invalid: Added new feature

Allowed types: feat, fix, docs, test, build, ci, perf, refactor, reverts, style, chore"

# Read the commit message from the file passed as the first argument
commit_message=$(cat "$1")

# Check the commit message against the regex pattern
if ! echo "$commit_message" | grep -iqE "$commit_regex"; then
  echo "$error_msg"
  exit 1
fi

exit 0
'@

    $IsUnix = $false
    if ($env:OS -ne "Windows_NT") {
        $IsUnix = $true
    }

    # Check if the repository path exists
    if (-Not (Test-Path -Path $RepoPath)) {
        Write-Error "🥺 The specified path does not exist."
        return
    }

    $gitFolderPath = Find-GitRoot -StartPath $RepoPath
    if ($null -eq $gitFolderPath) {
        Write-Error "🥺 The specified path is not a Git repository."
        return
    }

    # Define the path to the commit-msg hook
    $commitMsgHookPath = Join-Path -Path $gitFolderPath -ChildPath ".git/hooks/commit-msg"

    # Check if the commit-msg hook already exists
    if (Test-Path -Path $commitMsgHookPath) {
        Write-Host "🚀 The commit-msg hook already exists."
    } else {
        # Create the commit-msg hook file and add the content
        Set-Content -Path $commitMsgHookPath -Value $commitMsgContent -Force

         # Make the commit-msg hook executable on Unix-like systems
        if ($IsUnix) {
            & chmod +x $commitMsgHookPath
        }

        Write-Host "🚀 The commit-msg hook has been created and made executable."
    }
}

function Find-GitRoot {
    param (
        [string]$StartPath
    )

    $currentPath = (Get-Item -Path $StartPath).FullName
    if (-Not (Test-Path -Path $currentPath)) {
        return $null
    }

    while ($true) {
        $gitFolderPath = Join-Path -Path $currentPath -ChildPath ".git"
        if (Test-Path -Path $gitFolderPath) {
            return $currentPath
        }

        # Get the parent directory
        $parentPath = (Get-Item -Path $currentPath).Parent.FullName

        # Check if we have reached the root of the drive
        if ($null -eq $parentPath || $currentPath -eq $parentPath) {
            return $null
        }

        # Move to the parent directory
        $currentPath = $parentPath
    }
}

function InstallModuleIfNotInstalled {
    param (
        # The name of the module
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    
    if (!(Get-Module -ListAvailable -Name $Name))
    {
        Write-Host "'$Name' is not installed, installing as part of profile start-up."
        Install-Module $Name -Scope CurrentUser -AllowPrerelease -Force -AllowClobber
    }

    # if (!(Get-InstalledModule -Name $Name)) {
    #     Write-Host "Importing module $Name"
    #     Import-Module $Name -Verbose
    # }

    Import-Module -Name $Name
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
    git config --system core.longpaths true

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
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "Requires administrative privileges."

        sudo pwsh -Command SetEnvironmentVars
        return
    }

    # Set some environment variables.
    setx DOTNET_CLI_TELEMETRY_OPTOUT 1 /M > $null
    setx DOTNET_NOLOGO 1 /M > $null

    setx PYTHONIOENCODING "utf-8" /M > $null
    
    setx NCRUNCH_CACHE_ROOT_FOLDER "Z:\NCrunch\Cache\" /M > $null
    
    setx GOROOT "$HOME\scoop\apps\go\current" /M > $null
    setx GOPATH "$env:GOROOT\bin" /M > $null
    
    setx WSLENV USERPROFILE/p: /M > $null
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
    
    Set-Alias -Name ch -Value Add-CommitMsgHook -Scope Global
}

function NewInstall() {
    $IS_INSTALLED = where.exe scoop

    if (!$IS_INSTALLED) {
        Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression

        scoop install aria2 scoop-search git
        scoop config aria2-enabled true
        scoop config aria2-warning-enabled false

        git config --global credential.helper manager
    }

    scoop bucket add extras
    scoop bucket add java
    scoop bucket add sysinternals
    scoop bucket add nonportable

    # removed sudo from the list below as Windows currently supports it.

    # Utilities
    InstallFromScoop -Items curl, wget, touch, time, `
        lsd, nano, neofetch, ffmpeg, grep, `
        sed, less, grep, sysinternals, hwmonitor, `
        signal, whatsapp, `
        teracopy-np, `
        speedtest-cli, `
        treesize-free

    # Game dev
    InstallFromScoop -Items reshade, godot-mono

    # Tools
    InstallFromScoop -Items 7zip, typora, `
        plex-desktop, ipscan

    # Dev tools
    InstallFromScoop -Items `
        git, git-credential-manager, make, nvm, yarn, `
        openjdk, `
        github, gh, oh-my-posh, act, `
        azure-cli, `
        openapi-generator-cli, gitleaks, `
        winmerge, msbuild-structured-log-viewer, `
        postman, `
        azuredatastudio, dbeaver

    # Go dev tool specific
    InstallFromScoop -Items go, mockery, protobuf

    # Rust dev tool specific
    # InstallFromScoop -Items rust-analyzer, rust, rustup

    # k8s/ docker/ container specific tools
    InstallFromScoop -Items argocd, k9s, krew, dive, `
        trivy, kubectl, kubens, kubectx, ctop, `
        hadolint, kompose, kubeval, `
        draft, minikube, helm

    InstallGoApps
    
    winget install GitHub.GitHubDesktop --accept-package-agreements --accept-source-agreements --silent --disable-interactivity

    # Run gh auth login FIRST, or this won't even install
    # gh extension install github/gh-copilot
    # Required for disabling telemetry, which I can't find out how to
    # do with the cli/ switches
    # gh copilot config list 

    dotnet tool install -g DiffEngineTray > $null
    dotnet tool install -g dotnetCampus.UpdateAllDotNetTools > $null

    yarn config set --home enableTelemetry 0 > $null
    oh-my-posh disable notice > $null

    # nvm install lts > $null
    nvm install latest > $null

    nvm use latest > $null

    npm install -g @devcontainers/cli > $null

    az extension add --name azure-devops > $null

    NewInstallAdmin

    sysupdate
    storeupdate

    SetGitConfig
    SetEnvironmentVars

    . $PROFILE
}

function InstallGoApps() {
    go install github.com/liamg/comet@latest
    go install github.com/mrtazz/checkmake/cmd/checkmake@latest
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

    InstallModuleIfNotInstalled -Name Microsoft.WinGet.Client

    # PowerToys
    winget install XP89DCGQ3K6VLD --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
    # DevToys
    winget install 9PGCV4V3BK4W --accept-package-agreements --accept-source-agreements --silent --disable-interactivity

    winget install Valve.Steam --accept-package-agreements --accept-source-agreements --silent --disable-interactivity

    winget install Microsoft.DotNet.SDK.6
    winget install Microsoft.DotNet.SDK.7
    winget install Microsoft.DotNet.SDK.8
    winget install Microsoft.DotNet.SDK.Preview

    InstallFromScoop -Global -Items `
        rancher-desktop

    git config --system core.longpaths true

    rdctl set --container-engine.name=moby
    rdctl set --application.telemetry.enabled=false
    rdctl set --application.updater.enabled=false
    rdctl set --application.auto-start=true
    rdctl set --application.start-in-background=true
    
    winget settings --enable InstallerHashOverride

    oh-my-posh font install Meslo
    oh-my-posh font install CascadiaCode

    Write-Host "🚀 IMPORTANT: Restart your Windows Terminal and set the font to 'MesloLGS Nerd Font'."
}

function SysUpdate() {
    Write-Host "  ⏹️ Updating scoop installed applications..."

    scoop update --all --quiet
    scoop cleanup --all --cache

    oh-my-posh disable notice > $null

    Write-Host "  ⏹️ Updating Node/ npm Global Tools..."
    
    nvm install latest
    npm install -g npm@ > $null
    npm update -g > $null

    Write-Host "  ⏹️ Updating dotnet Global Tools..."
    
    Stop-Process -Name DiffEngineTray -ErrorAction SilentlyContinue > $null

    dotnet updatealltools > $null

    if ($env:computername -eq "TARS") {
        DiffEngineTray
    }

    Write-Host "  ⏹️ Updating PowerShell Modules..."
    
    Update-Module

    UpdateOffice

    sudo pwsh -Command SysUpdateAdmin
}

function SysUpdateAdmin() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "🔒 Requires administrative privileges."

        sudo pwsh -Command SysUpdateAdmin

        return
    }

    Write-Host "🔓 Updating global scoop installations, this will require elevated permissions."
    
    Write-Host "  ⏹️ Updating Global scoop Applications..."

    scoop update --all --quiet --global
    scoop cleanup --all --cache --global

    Write-Host "  ⏹️ Updating PowerShell Global Modules..."

    Update-Module -Scope AllUsers

    Write-Host "🟩 Finished Updating!"    
}

function EnableWSMan() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "🔒 Requires administrative privileges."

        sudo pwsh -Command EnableWSMan
        return
    }

    Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'MAJOR' -Concatenate

    # Run on MAJOR/ remote machine.

    # Enable-PSRemoting
    # restart-service winrm -confirm:$false -force
    
    # Register-PSSessionConfiguration -Name WithProfile -StartupScript C:\Users\Administrator\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
}

function ConnectToMajor() {
    enter-pssession -ComputerName MAJOR -ConfigurationName WithProfile
}

function StoreUpdate() {
    $isAdmin = IsAdmin
    if ($isAdmin -eq $false) {
        Write-Host "🔒 Requires administrative privileges."

        sudo pwsh -Command StoreUpdate
        return
    }

    Write-Host "  ⏹️ Updating winget/ store apps..."

    winget upgrade --include-unknown --silent --all --accept-package-agreements --accept-source-agreements --ignore-security-hash --disable-interactivity --force --purge

    UpdateOffice

    Write-Host "🟩 Finished Updating!"    
}

function UpdateOffice() {
    Write-Host "  ⏹️ Updating Office Apps..."

    cmd /c "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" /update $Env:UserName displaylevel=false forceappshutdown=true
}

function global:Init() {
    SetGlobalAliases
    InitCLI
}

function InitCLI() {
    if ($host.Name -eq 'ConsoleHost') {
        # From: https://github.com/PowerShell/PSReadLine

        #InstallModuleIfNotInstalled -Name PSReadLine

        Import-Module PSReadLine # -Force -PassThru

        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

        Set-PSReadLineOption -ShowToolTips
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -EditMode Windows
    }

    if (IsInstalled -CommandName oh-my-posh) {
        $directoryPath = Split-Path -Path $PROFILE
        $directoryPath = [IO.Path]::Combine($directoryPath, "theme.omp.json")
        oh-my-posh init pwsh --config $directoryPath | Invoke-Expression
    }

    if (IsInstalled -CommandName gh) {
        gh completion -s powershell | Out-String | Invoke-Expression
        gh copilot alias pwsh | Out-String | Invoke-Expression
    }

    if (IsInstalled -CommandName k9s) {
        k9s completion powershell  | Out-String | Invoke-Expression
    }

    if (IsInstalled -CommandName scoop-search) {
        scoop-search --hook | Invoke-Expression
    }

    ##f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

    #Import-Module -Force -PassThru -Name Microsoft.WinGet.CommandNotFound
    ##f45873b3-b655-43a6-b217-97c00aa0db58
}

Init

Set-PSDebug -Trace 0
