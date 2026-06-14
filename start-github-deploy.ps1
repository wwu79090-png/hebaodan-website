param(
    [string]$RepoName = "hebaodan-website",
    [string]$Domain = "eggfly.ee.cd",
    [string]$Owner = "",
    [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "荷包蛋官网一键部署启动器"

if (-not $env:GITHUB_TOKEN) {
    $env:GITHUB_TOKEN = Read-Host "请输入 GitHub 个人访问令牌 (PAT)"
}

powershell -ExecutionPolicy Bypass -File (Join-Path -Path $PSScriptRoot -ChildPath "deploy-github.ps1") `
    -RepoName $RepoName `
    -Owner $Owner `
    -Branch $Branch `
    -Domain $Domain `
    -Token $env:GITHUB_TOKEN
