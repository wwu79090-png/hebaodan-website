# 荷包蛋官网 · Cloudflare 全自动部署说明

当前目录已包含成品 `index.html`，以及 `deploy-cloudflare.ps1` 一键脚本。

## 1) 先准备

请在环境变量里设置你的 Cloudflare API Token：

- `CLOUDFLARE_API_TOKEN`

Token 需要具备：

- Zone：Read/Write（用于 DNS，可选）
- Cloudflare Pages：Edit

如果你愿意自动提交自定义域名绑定，还需要：

- `AccountId`（在命令中传入）

## 2) 一键部署到 Cloudflare Pages

在项目根目录执行：

```powershell
.\deploy-cloudflare.ps1 -ProjectName "hebaodan-official" -Domain "eggfly.ee.cd" -Branch "main"
```

默认会执行：

- 上传当前目录到 `hebaodan-official` Pages 项目（不存在则自动创建）
- 绑定自定义域名 `eggfly.ee.cd`（如提供 `AccountId`）

## 3) 若你的域名也在 Cloudflare 托管

可顺便自动创建 CNAME（可选）：

```powershell
.\deploy-cloudflare.ps1 -ProjectName "hebaodan-official" -Domain "eggfly.ee.cd" -AccountId "你的 AccountId" -ZoneId "你的 ZoneId" -CreateDnsRecord
```

脚本会把：

- `eggfly.ee.cd -> <project>.pages.dev`

写入到 `ZoneId` 对应的 DNS。

## 4) 常见失败点（很快处理）

- 提示未配置 API Token：先设置 `CLOUDFLARE_API_TOKEN`
- 提示 token 权限不足：补充 Pages Edit、Zone Edit
- 页面访问 522/DNS 未解析：检查 CNAME 是否写对，等待 DNS 生效

## 5) 成品入口

我已将官网的购买与卡网路径统一到：

- `https://egg.uidp.cn/shop/egg`

并保留你配置的站点信息（QQ 群、客服群、公告文案、动态动画、下载按钮提示、免责声明）。
