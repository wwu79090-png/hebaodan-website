param(
    [string]$ProjectName = "hebaodan-official",
    [string]$Domain = "eggfly.ee.cd",
    [string]$Branch = "main",
    [string]$AccountId = "",
    [string]$ZoneId = "",
    [switch]$AddDomain = $true,
    [switch]$CreateDnsRecord = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "开始部署荷包蛋官网到 Cloudflare Pages..."

if (-not (Test-Path -Path ".\index.html")) {
    throw "当前目录找不到 index.html，请在项目根目录执行此脚本。"
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "未检测到 node，请先安装 Node.js。"
}

if (-not $env:CLOUDFLARE_API_TOKEN) {
    throw "环境变量 CLOUDFLARE_API_TOKEN 未设置。请先设置 API Token 后再执行。"
}

if (-not $AccountId) { $AccountId = $env:CLOUDFLARE_ACCOUNT_ID }
if (-not $ZoneId) { $ZoneId = $env:CLOUDFLARE_ZONE_ID }

$wranglerCmd = Get-Command npx -ErrorAction SilentlyContinue
if (-not $wranglerCmd) {
    throw "未检测到 npx，请先安装 npm(Node.js 工具链)。"
}

& npx --yes wrangler@latest pages deploy . --project-name $ProjectName --branch $Branch
if ($LASTEXITCODE -ne 0) { throw "Cloudflare Pages 部署失败。请查看上方错误信息。"}

$projectInfo = & npx --yes wrangler@latest pages project list --json | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "读取项目列表失败，部署中断。"
}

$deploymentDomain = "无法自动读取"
try {
    $json = $projectInfo | ConvertFrom-Json
    $project = $json | Where-Object { $_.name -eq $ProjectName }
    if ($project -and $project.subdomain) {
        $deploymentDomain = "https://$($project.subdomain).pages.dev"
    }
} catch {
    Write-Warning "读取项目列表 JSON 失败，跳过自动提取 pages.dev 地址。"
}

Write-Host "部署完成。Pages 地址：" $deploymentDomain

if ($AddDomain -and $AccountId) {
    $payload = @{ name = $Domain } | ConvertTo-Json -Compress
    $addDomainUrl = "https://api.cloudflare.com/client/v4/accounts/$AccountId/pages/projects/$ProjectName/domains"
    try {
        $domainResult = Invoke-RestMethod -Method Post -Uri $addDomainUrl `
            -Headers @{
                Authorization = "Bearer $env:CLOUDFLARE_API_TOKEN"
                "Content-Type" = "application/json"
            } `
            -Body $payload
        Write-Host "已提交域名绑定：$Domain"
        Write-Host "域名状态：" $domainResult.result.status
        if ($domainResult.result.validation_data.method -eq "txt" -and $domainResult.result.validation_data.txt_name) {
            Write-Host "需要 DNS 校验记录："
            Write-Host ("名称: " + $domainResult.result.validation_data.txt_name)
            Write-Host ("值  : " + $domainResult.result.validation_data.txt_value)
            Write-Host "请到你的 DNS 平台添加 TXT 记录。"
        }
    } catch {
        Write-Warning "Cloudflare API 绑定域名失败：$($_.Exception.Message)"
        Write-Host "请确认 token 权限包含：Cloudflare Pages + 区域/Account 读写。"
    }
} else {
    Write-Host "未设置 AccountId，跳过 API 绑定域名。请在 Cloudflare Pages 后台手动设置 eggfly.ee.cd 的绑定。"
}

if ($CreateDnsRecord -and $ZoneId -and $deploymentDomain -ne "无法自动读取" -and $deploymentDomain -match "https://(?<sub>[^/]+\.pages\.dev)") {
    $subdomain = $Matches["sub"]
    $dnsPayload = @{
        type    = "CNAME"
        name    = $Domain
        content = $subdomain
        ttl     = 3600
        proxied = $false
    } | ConvertTo-Json -Depth 5
    $zoneRecordUrl = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records"

    try {
        # 先检查是否已有记录
        $existing = Invoke-RestMethod -Method Get -Uri "$zoneRecordUrl?type=CNAME&name=$Domain" `
            -Headers @{ Authorization = "Bearer $env:CLOUDFLARE_API_TOKEN"; "Content-Type" = "application/json" }
        if ($existing.success -and $existing.result.Count -gt 0) {
            Write-Host "DNS 已存在 CNAME，不再重复创建：$Domain"
        } else {
            Invoke-RestMethod -Method Post -Uri $zoneRecordUrl `
                -Headers @{ Authorization = "Bearer $env:CLOUDFLARE_API_TOKEN"; "Content-Type" = "application/json" } `
                -Body $dnsPayload | Out-Null
            Write-Host "已在 Cloudflare DNS 创建 CNAME 记录：$Domain -> $subdomain"
        }
    } catch {
        Write-Warning "DNS 记录创建失败：$($_.Exception.Message)"
    }
}

Write-Host "操作完成。若域名未即时生效，请等待 5-30 分钟后访问 https://$Domain"
