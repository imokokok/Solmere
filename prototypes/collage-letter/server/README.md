# 漂流瓶联机服务

这是可独立部署的共享信件服务。客户端连向同一个地址即可读到相同历史记录。所有信件、回复关系和待回信义务由 SQLite 保存；服务端事务检查发信资格，客户端按钮禁用只是辅助提示。

## 本机

从项目根目录双击 `Start-Game.cmd`，源码启动器会检查 8787 端口，并在需要时启动本机服务。数据在 `%LOCALAPPDATA%\CollageLetterServer`。服务默认只监听 `127.0.0.1`，不改动防火墙或系统设置。

手动启动：

```powershell
python .\server\app.py --host 127.0.0.1 --port 8787
```

## 局域网

一台作为服务器的电脑运行 `Start-LAN-Server.cmd`，监听 `0.0.0.0:8788`。客户端在“邮局设置”中填 `http://服务器局域网IP:8788`。使用 8788 是为了与本机启动器的 8787 分开。

连接仍受所在网络和电脑防火墙设置影响。本项目不会自动更改这些设置。本机和局域网服务默认使用同一个 SQLite 数据文件，因此同一台服务器上的记录一致；请避免复制数据库后把副本当成同一个邮局继续使用。

## Linux 公网服务器

需要已有服务器及域名。本版本没有代用户购买或开通公共服务器。

将 `server` 目录复制到服务器，执行：

```sh
docker compose up -d --build
```

提供的 Compose 将容器 8787 端口绑定到主机回环地址，并用持久卷保存 SQLite。桌面、局域网与容器统一使用随源码附带的 Waitress 3.0.2；限制 8 个工作线程、128 个连接、30 秒闲置连接超时与 18 MB 请求体，无需联网安装依赖。反向代理也需同步更新请求体限制，见 `Caddyfile.example`。

将 `Caddyfile.example` 中的 `letters.example.com` 换成实际域名，再配置 Caddy 反向代理到 `127.0.0.1:8787`。客户端邮局地址填 `https://实际域名`，也可以在分发前修改项目 `network.cfg` 的默认地址。

Docker 配置已提供，尚未在本机启动 Docker 验证。数据库目录必须可写。实例扩容应共享一个可靠服务端数据库设计，本版针对单机 SQLite，不支持跨主机复制写入。

## 身份与协议

匿名设备身份首次连接时创建。服务返回随机 bearer token，数据库只存 token 哈希。以后重启客户端仍使用本地保存的 token；不同邮局分别保留凭据。

| 方法与路径 | 用途 |
| --- | --- |
| `GET /health` | 健康检查 |
| `POST /v1/players` | 建立匿名身份，body: `name` |
| `GET /v1/me` | 读取身份及 `reply_required` |
| `GET /v1/letters?view=ocean` | 其他人的信，最新在前 |
| `GET /v1/letters?view=mine` | 自己发出的信 |
| `GET /v1/letters?view=inbox` | 别人回复自己的信 |
| `GET /v1/letters/{id}` | 原作品、回信目标、最新 100 条回复链接 |
| `POST /v1/letters` | 发布原创信或回信 |

列表每页 12 封，通过返回的 `next_before` 作为下一次查询的 `before` 参数访问更早历史；所有记录持续保存。详情页最新 100 条回复之外的旧回复仍可通过历史列表和 ID 访问。

除健康检查与建立身份外，均需 `Authorization: Bearer TOKEN`。

寄信 body：

```json
{
  "request_id": "每次寄信唯一的随机流水号",
  "parent_id": null,
  "title": "给海边的人",
  "caption": "可选的简短文字",
  "art_png": "可选的第一页 PNG base64（兼容旧客户端）",
  "art_pages": ["第一页 PNG base64", "第二页 PNG base64"]
}
```

`parent_id` 为 `null` 是原创漂流瓶；为现有信件 ID 是回信。标题最多 40 字，文字最多 12000 字；每页 PNG 最多 750 KB，声明尺寸不超过 1536 × 1536。`art_pages` 按原作品顺序保存，最多 64 页，解码后总计最多 12 MB；若同时提供 `art_png`，它必须与第一页相同。客户端发送所有成品页，不上传本地身份文件或其他私人文件。详情返回 `art_pages`，列表不包含图片数据；寄信响应的 `page_count` 确认保存的页数。

协议版本 3 的 `/health` 返回 `capabilities: ["art_pages"]`。升级服务会自动添加数据库字段，保留已有信件及单页重试流水号；旧单页 `art_png` 在详情中也作为一页返回。新版客户端遇到旧邮局会保留多页草稿并提示更新，不会只上传第一页。客户端和所连接的邮局服务均需更新，才能使用完整多页收发。

同一身份、相同流水号和相同内容重试，返回原信 ID，不重复插入。相同流水号改动内容返回 409。收到网络错误后应使用原流水号与原内容重试。

服务使用 `BEGIN IMMEDIATE` 将资格检查、写信、更新义务放入同一事务。自己回复自己、不存在的原信、再次回复同一个目标都会被拒绝。发原创信置 `reply_required=true`，成功回信清除；不累积提前回复次数。响应中提供最新身份状态。

这是匿名身份的功能原型，未实现防多账号、内容审核、账号找回或管理后台。面向开放公众运营前需补足相应产品能力；更改本地身份凭据相当于更换匿名身份，不等同于登录同一账号。

## 数据备份

`COLLAGE_DB` 环境变量可指定数据库文件。容器默认 `/data/letters.sqlite3`，桌面默认 `%LOCALAPPDATA%\CollageLetterServer\letters.sqlite3`。

运行时采用 WAL；备份可使用 SQLite backup API，或停止服务后复制数据库及关联 WAL 文件。不要只复制仍在写入中的主数据库文件。

## 测试

从项目根目录：

```powershell
python .\server\test_service.py
godot --path . -- --smoke-test
```

Godot 联网集成测试应使用独立测试数据库和测试端口，避免把测试信写进玩家邮局：

```powershell
$env:COLLAGE_DB = "$PWD\test-data\letters.sqlite3"
python .\server\app.py --port 8789
```

保持服务运行，在另一个终端：

```powershell
$env:COLLAGE_TEST_URL = "http://127.0.0.1:8789"
godot --path . -- --network-test
```

Godot 测试需要图形显示环境，不能加 `--headless`。测试客户端使用专用临时草稿/身份，不覆盖玩家存档；服务端测试库中会保留测试信。

## 自动重试与依赖许可

客户端读取请求与带同一 request_id 的寄信请求遇到暂时断线或 502/503/504 时，最多自动重试两次，并保留同一地址、身份和请求内容。权限错误、回信义务冲突、建立新身份不自动重试。

Waitress 原样附带于 vendor/；来源版本和下载 SHA-256 在 vendor/SOURCE.json。允许商用；随源码保留 ZPL-2.1 许可与作者版权说明，无游戏画面署名要求。SQLite 为公有领域。

故障注入测试：设置 GODOT_BIN 后执行 `python server/test_client_retry.py`。它启动临时 Waitress 数据库，模拟已入库但响应失败，验证客户端重试仍只有一封信。

多页端到端回归：设置 `GODOT_BIN` 后执行 `python server/test_multipage_client.py`（需要图形显示环境）。它使用临时数据库，验证编辑/成品排版一致、三页保存恢复、全部页面 HTTP 收发、丢失响应后的幂等重试、翻页、中英文按钮和旧邮局兼容。`COLLAGE_TEST_OUTPUT` 可指定截图目录；测试启动器使用独立项目名隔离玩家设置、存档和身份。
