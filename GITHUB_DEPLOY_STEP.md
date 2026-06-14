# 一键建仓并推送（GitHub）

你说的“鸡蛋（GitHub）有了，我帮你直接建”对应的本地执行版本是：

```powershell
$env:GITHUB_TOKEN = "你的个人访问令牌"
.\deploy-github.ps1 -RepoName "hebaodan-website" -Branch "main"
```

说明：
- 脚本会自动读取当前目录 `index.html`，创建仓库（若不存在）。
- 自动提交并推送到 `main` 分支。
- 输出仓库地址，接着继续手动在 GitHub 后台开启 Pages（脚本末尾已给出入口）。

你已经在用的域名是：
- `https://eggfly.ee.cd`

在 GitHub Pages 页面设置完域名后，最后再去 DNS 加一条 CNAME：
- 记录名：`eggfly`
- 目标：`你的 GitHub Pages 根域名（类似 yourname.github.io）`

