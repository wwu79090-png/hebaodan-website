param(
    [string]$RepoName = "hebaodan-website",
    [string]$Owner = "",
    [string]$Branch = "main",
    [string]$Description = "荷包蛋官网单页站点",
    [string]$Token = "",
    [string]$Domain = "eggfly.ee.cd"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ThrowIfNotFound([string]$Path, [string]$Message) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw $Message
    }
}

ThrowIfNotFound -Path ".\index.html" -Message "当前目录缺少 index.html，无法部署。请在包含 index.html 的目录执行。"

$token = $env:GITHUB_TOKEN
if (-not $token) {
    $token = $Token
}
if (-not $token) {
    throw "未检测到环境变量 GITHUB_TOKEN，且未传入 -Token。请先设置 token（至少 repo + pages + administration 写权限）。"
}

$headers = @{
    Authorization = "Bearer $token"
    "User-Agent"  = "Codex-Deploy"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

if (-not $Owner) {
    try {
        $user = Invoke-RestMethod -Method Get -Uri "https://api.github.com/user" -Headers $headers
        $Owner = $user.login
    } catch {
        throw "读取用户信息失败：请确认 GITHUB_TOKEN 有效且未过期。"
    }
}

Write-Host "当前登录用户: $Owner"

function Invoke-GitHubRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        [string]$BodyJson = ""
    )
    if ($BodyJson) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -Body $BodyJson -ContentType "application/json"
    } else {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers
    }
}

$repoApi = "https://api.github.com/repos/$Owner/$RepoName"
$repoExists = $false
try {
    Invoke-RestMethod -Method Get -Uri $repoApi -Headers $headers | Out-Null
    $repoExists = $true
    Write-Host "仓库已存在：$Owner/$RepoName"
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -ne 404) {
        throw "检查仓库状态失败：$($_.Exception.Message)"
    }
}

if (-not $repoExists) {
    $createBody = @{
        name        = $RepoName
        description = $Description
        private     = $false
        has_issues  = $true
        has_projects= $false
        has_wiki    = $false
        auto_init   = $false
    } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" -Headers $headers -Body $createBody | Out-Null
        Write-Host "已创建仓库：$Owner/$RepoName"
    } catch {
        throw "创建仓库失败：$($_.Exception.Message)"
    }
}

if (-not (Test-Path ".\.git")) {
    git init | Out-Null
    Write-Host "已初始化 Git 仓库"
}

git config user.name "Hebaodan Auto"
git config user.email "no-reply@hebaodan.local"

git checkout -B $Branch | Out-Null
git add .
$status = git status --porcelain
if ($status) {
    git commit -m "feat: add 荷包蛋官网单页" | Out-Null
    Write-Host "已提交最新文件到本地 $Branch"
} else {
    Write-Host "本地无新变更，跳过提交"
}

$originUrl = "https://x-access-token:{0}@github.com/{1}/{2}.git" -f $token, $Owner, $RepoName
try {
    $originRemote = git remote get-url origin 2>$null
} catch {
    $originRemote = $null
}
if ($originRemote) {
    git remote set-url origin $originUrl
} else {
    git remote add origin $originUrl
}
git push -u origin $Branch
Write-Host "已推送到 https://github.com/$Owner/$RepoName"

if ($Domain) {
    $cnamePath = Join-Path -Path (Get-Location) -ChildPath "CNAME"
    $needsCnameCommit = $true
    if (Test-Path $cnamePath -PathType Leaf) {
        $existing = Get-Content -Path $cnamePath -Raw
        if ($existing.Trim() -eq $Domain) {
            $needsCnameCommit = $false
        }
    }
    if ($needsCnameCommit) {
        Set-Content -Path $cnamePath -Value $Domain -NoNewline
        git add CNAME
        git commit -m "chore: add GitHub Pages custom domain" | Out-Null
        git push -u origin $Branch
        Write-Host "已创建/更新 CNAME 文件：$Domain"
    }

    try {
        $pagesPayload = @{
            source = @{
                branch = $Branch
                path = "/"
            }
            cname = $Domain
            https_enforced = $true
        } | ConvertTo-Json -Depth 10
        $pagesUrl = "https://api.github.com/repos/$Owner/$RepoName/pages"
        try {
            Invoke-GitHubRequest -Method "PUT" -Uri $pagesUrl -Headers $headers -BodyJson $pagesPayload | Out-Null
            Write-Host "GitHub Pages 配置已更新：已设置自定义域名 $Domain"
        } catch {
            # 未配置时先尝试创建
            $createPayload = @{
                source = @{
                    branch = $Branch
                    path = "/"
                }
            } | ConvertTo-Json -Depth 10
            Invoke-GitHubRequest -Method "POST" -Uri $pagesUrl -Headers $headers -BodyJson $createPayload | Out-Null
            Start-Sleep -Seconds 2
            Invoke-GitHubRequest -Method "PUT" -Uri $pagesUrl -Headers $headers -BodyJson $pagesPayload | Out-Null
            Write-Host "GitHub Pages 已创建并设置自定义域名 $Domain"
        }
    } catch {
        Write-Warning "GitHub Pages API 配置失败：$($_.Exception.Message)"
        Write-Host "你可先手动完成："
        Write-Host "1) 打开 https://github.com/$Owner/$RepoName/settings/pages"
        Write-Host "2) Source 选择 Branch=$Branch, 根目录 /"
        Write-Host "3) 在自定义域名处填入 $Domain"
    }
}

Write-Host "仓库地址： https://github.com/$Owner/$RepoName"
Write-Host "网站访问地址（DNS 生效后）： https://$Domain"
