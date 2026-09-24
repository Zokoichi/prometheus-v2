param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("put", "head", "get", "delete")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateSet("production", "test")]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$ObjectKey,

    [string]$LocalFile,

    [string]$DestinationFile,

    [string]$ContentType
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-EnvValue {
    param([string]$Name)

    $line = Get-Content (Join-Path $Root ".env") |
        Where-Object {
            $_ -match "^\s*$([regex]::Escape($Name))\s*="
        } |
        Select-Object -First 1

    if (-not $line) {
        throw "Variable $Name absente de .env"
    }

    return ($line -replace "^\s*$([regex]::Escape($Name))\s*=", "").Trim()
}

$AccessKey = Get-EnvValue "SEAWEEDFS_ACCESS_KEY"
$SecretKey = Get-EnvValue "SEAWEEDFS_SECRET_KEY"

if ([string]::IsNullOrWhiteSpace($AccessKey)) {
    throw "SEAWEEDFS_ACCESS_KEY vide."
}

if ([string]::IsNullOrWhiteSpace($SecretKey)) {
    throw "SEAWEEDFS_SECRET_KEY vide."
}

$Network  = "prometheus-v2-network"
$Endpoint = "http://prometheus-v2-seaweedfs:8333"
$AwsImage = "public.ecr.aws/aws-cli/aws-cli:2.36.42"

if ($Environment -eq "production") {
    $Bucket = "prometheus-v2-artifacts"
}
else {
    $Bucket = "prometheus-v2-test"
}

function Invoke-AwsCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $dockerArgs = @(
        "run",
        "--rm",
        "--network", $Network,
        "-e", "AWS_ACCESS_KEY_ID=$AccessKey",
        "-e", "AWS_SECRET_ACCESS_KEY=$SecretKey",
        $AwsImage
    ) + $Arguments

    & docker @dockerArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI operation failed. exit=$LASTEXITCODE"
    }
}

switch ($Operation) {

    "put" {

        if ([string]::IsNullOrWhiteSpace($LocalFile)) {
            throw "put nécessite -LocalFile"
        }

        if (-not (Test-Path -LiteralPath $LocalFile -PathType Leaf)) {
            throw "Fichier introuvable: $LocalFile"
        }

        $Resolved = (Resolve-Path -LiteralPath $LocalFile).Path
        $Workspace = Split-Path -Parent $Resolved
        $FileName = Split-Path -Leaf $Resolved

        $ContainerFile = "/workspace/$FileName"

        $Args = @(
            "s3", "cp",
            $ContainerFile,
            "s3://$Bucket/$ObjectKey",
            "--endpoint-url", $Endpoint
        )

        if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
            $Args += @("--content-type", $ContentType)
        }

        Invoke-AwsCli -Arguments @(
            "-v", "${Workspace}:/workspace:ro"
        ) + $Args

        $Hash = (Get-FileHash -LiteralPath $Resolved -Algorithm SHA256).Hash
        $Size = (Get-Item -LiteralPath $Resolved).Length

        [ordered]@{
            operation   = "put"
            success     = $true
            environment = $Environment
            bucket      = $Bucket
            object_key  = $ObjectKey
            size_bytes  = [int64]$Size
            sha256      = $Hash
        } | ConvertTo-Json -Compress
    }

    "head" {

        Invoke-AwsCli -Arguments @(
            "s3api", "head-object",
            "--bucket", $Bucket,
            "--key", $ObjectKey,
            "--endpoint-url", $Endpoint
        )

        [ordered]@{
            operation   = "head"
            success     = $true
            environment = $Environment
            bucket      = $Bucket
            object_key  = $ObjectKey
        } | ConvertTo-Json -Compress
    }

    "get" {

        if ([string]::IsNullOrWhiteSpace($DestinationFile)) {
            throw "get nécessite -DestinationFile"
        }

        $Destination = [IO.Path]::GetFullPath($DestinationFile)
        $DestinationDir = Split-Path -Parent $Destination
        $DestinationName = Split-Path -Leaf $Destination

        New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null

        $Workspace = $DestinationDir

        Invoke-AwsCli -Arguments @(
            "-v", "${Workspace}:/workspace",
            "s3", "cp",
            "s3://$Bucket/$ObjectKey",
            "/workspace/$DestinationName",
            "--endpoint-url", $Endpoint
        )

        $Hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        $Size = (Get-Item -LiteralPath $Destination).Length

        [ordered]@{
            operation   = "get"
            success     = $true
            environment = $Environment
            bucket      = $Bucket
            object_key  = $ObjectKey
            local_file  = $Destination
            size_bytes  = [int64]$Size
            sha256      = $Hash
        } | ConvertTo-Json -Compress
    }

    "delete" {

        Invoke-AwsCli -Arguments @(
            "s3api", "delete-object",
            "--bucket", $Bucket,
            "--key", $ObjectKey,
            "--endpoint-url", $Endpoint
        )

        [ordered]@{
            operation   = "delete"
            success     = $true
            environment = $Environment
            bucket      = $Bucket
            object_key  = $ObjectKey
        } | ConvertTo-Json -Compress
    }
}
