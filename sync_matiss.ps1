[CmdletBinding()]
param(
	[ValidateSet("pull", "push", "install-key")]
	[string]$Mode = "pull",
	[switch]$Mirror,
	[string]$Host = "100.106.134.111",
	[string]$User = "matiss",
	[string]$RemotePath = "/home/matiss/Kim",
	[string]$ProjectRoot = (Split-Path -Parent $PSCommandPath),
	[string]$KeyPath = (Join-Path $HOME ".ssh\notespace_matiss_ed25519")
)

$ErrorActionPreference = "Stop"

$script:SshExe = (Get-Command ssh.exe -ErrorAction Stop).Source
$script:ScpExe = (Get-Command scp.exe -ErrorAction Stop).Source
$script:SshKeygenExe = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source
$script:RobocopyExe = (Get-Command robocopy.exe -ErrorAction Stop).Source

$script:ExcludeDirs = @(".git", ".godot")
$script:ExcludeFiles = @("sync_matiss.ps1")
$script:WorkingRoot = Join-Path $env:TEMP "notespace-matiss-sync"
$script:PullStage = Join-Path $script:WorkingRoot "pull"
$script:PushStage = Join-Path $script:WorkingRoot "push"

function Write-Step([string]$Message) {
	Write-Host "[sync_matiss] $Message"
}

function Convert-ToPosixSingleQuotedString([string]$Value) {
	return "'" + ($Value -replace "'", "'""'""'") + "'"
}

function Reset-Directory([string]$Path) {
	if (Test-Path $Path) {
		Remove-Item -LiteralPath $Path -Recurse -Force
	}

	New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Ensure-KeyPair() {
	$keyDirectory = Split-Path -Parent $KeyPath
	New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null

	if (Test-Path $KeyPath) {
		return
	}

	Write-Step "Generating dedicated SSH key at $KeyPath"
	& $script:SshKeygenExe -t ed25519 -f $KeyPath -N "" -C "notespace-matiss-sync" | Out-Null
	if ($LASTEXITCODE -ne 0) {
		throw "ssh-keygen failed with exit code $LASTEXITCODE."
	}
}

function Test-KeyAuth() {
	& $script:SshExe `
		-i $KeyPath `
		-o BatchMode=yes `
		-o ConnectTimeout=5 `
		-o StrictHostKeyChecking=accept-new `
		"$User@$Host" `
		"exit" | Out-Null

	return $LASTEXITCODE -eq 0
}

function Install-Key() {
	Ensure-KeyPair

	$publicKeyPath = "$KeyPath.pub"
	if (-not (Test-Path $publicKeyPath)) {
		throw "Public key not found at $publicKeyPath."
	}

	$publicKey = (Get-Content -LiteralPath $publicKeyPath -Raw).Trim()
	$quotedPublicKey = Convert-ToPosixSingleQuotedString $publicKey
	$remoteCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && grep -qxF $quotedPublicKey ~/.ssh/authorized_keys || printf '%s\n' $quotedPublicKey >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

	Write-Step "Installing SSH key on $User@$Host"
	Write-Step "When OpenSSH prompts for a password, enter the password for $User."

	& $script:SshExe `
		-o StrictHostKeyChecking=accept-new `
		"$User@$Host" `
		$remoteCommand

	if ($LASTEXITCODE -ne 0) {
		throw "SSH key installation failed with exit code $LASTEXITCODE."
	}

	if (-not (Test-KeyAuth)) {
		throw "SSH key install completed, but key-based authentication still failed."
	}
}

function Ensure-KeyAuth() {
	Ensure-KeyPair
	if (Test-KeyAuth) {
		return
	}

	Install-Key
}

function Invoke-RobocopySync([string]$Source, [string]$Destination, [bool]$UseMirrorMode) {
	New-Item -ItemType Directory -Path $Destination -Force | Out-Null

	$arguments = @(
		$Source,
		$Destination,
		"/R:2",
		"/W:1",
		"/FFT",
		"/XJ",
		"/COPY:DAT",
		"/DCOPY:DAT",
		"/NP",
		"/NFL",
		"/NDL",
		"/NJH",
		"/NJS"
	)

	if ($UseMirrorMode) {
		$arguments += "/MIR"
	} else {
		$arguments += "/E"
	}

	if ($script:ExcludeDirs.Count -gt 0) {
		$arguments += "/XD"
		$arguments += $script:ExcludeDirs
	}

	if ($script:ExcludeFiles.Count -gt 0) {
		$arguments += "/XF"
		$arguments += $script:ExcludeFiles
	}

	& $script:RobocopyExe @arguments | Out-Null
	$exitCode = $LASTEXITCODE
	if ($exitCode -gt 7) {
		throw "robocopy failed with exit code $exitCode."
	}
}

function Pull-RemoteProject() {
	Ensure-KeyAuth
	Reset-Directory $script:PullStage

	$remoteSource = "${User}@${Host}:${RemotePath}/."
	Write-Step "Pulling $remoteSource into $ProjectRoot"

	& $script:ScpExe `
		-r `
		-i $KeyPath `
		-o BatchMode=yes `
		-o StrictHostKeyChecking=accept-new `
		$remoteSource `
		$script:PullStage

	if ($LASTEXITCODE -ne 0) {
		throw "scp pull failed with exit code $LASTEXITCODE."
	}

	Invoke-RobocopySync -Source $script:PullStage -Destination $ProjectRoot -UseMirrorMode:$Mirror.IsPresent

	if ($Mirror.IsPresent) {
		Write-Step "Pull complete (mirror mode)."
	} else {
		Write-Step "Pull complete."
	}
}

function Push-LocalProject() {
	Ensure-KeyAuth
	Reset-Directory $script:PushStage

	Write-Step "Preparing staged copy from $ProjectRoot"
	Invoke-RobocopySync -Source $ProjectRoot -Destination $script:PushStage -UseMirrorMode:$false

	Write-Step "Ensuring remote folder exists at $RemotePath"
	& $script:SshExe `
		-i $KeyPath `
		-o BatchMode=yes `
		-o StrictHostKeyChecking=accept-new `
		"$User@$Host" `
		"mkdir -p $(Convert-ToPosixSingleQuotedString $RemotePath)"

	if ($LASTEXITCODE -ne 0) {
		throw "Remote directory creation failed with exit code $LASTEXITCODE."
	}

	$remoteDestination = "${User}@${Host}:${RemotePath}"
	Write-Step "Pushing staged project into $remoteDestination"

	& $script:ScpExe `
		-r `
		-i $KeyPath `
		-o BatchMode=yes `
		-o StrictHostKeyChecking=accept-new `
		"$script:PushStage\." `
		$remoteDestination

	if ($LASTEXITCODE -ne 0) {
		throw "scp push failed with exit code $LASTEXITCODE."
	}

	Write-Step "Push complete."
}

switch ($Mode) {
	"install-key" {
		Install-Key
		Write-Step "SSH key install complete."
	}
	"push" {
		Push-LocalProject
	}
	default {
		Pull-RemoteProject
	}
}
