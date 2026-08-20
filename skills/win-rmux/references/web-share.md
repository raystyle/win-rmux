# rmux Web Share（浏览器远程共享）

rmux v0.10.0 的远程共享入口是 `web-share`：把某个 pane 或整个 session 暴露给浏览器，
终端执行仍在本地 daemon，走端到端加密 WebSocket（hybrid post-quantum E2E）。

> 注意：rmux 没有独立的 `ssh` / `remote` 命令。需要「SSH 远程」语义时，用标准 `ssh`
> 进宿主机后再 `rmux attach`；或用下面 `--tunnel-provider` 的 SSH 反向隧道方案
> （srv-us / serveo / localhost-run 等）。

## 基本用法

```bash
rmux web-share                  # 默认 mint operator + spectator 两个 URL
rmux web-share -t work          # 共享名为 work 的 session
rmux web-share -t work:0.0      # 共享单个 pane
rmux web-share list             # 等价 -l，列出活动 share
rmux web-share lookup ID
rmux web-share stop ID          # 撤销 share（等价 disconnect ID）
rmux web-share off
rmux web-share --config         # 查看本地监听/前端配置
```

实测 mint（`--no-pin --spectator-only --ttl 60`）：

```text
spectator https://share.rmux.io/#t=A9TG...
share expires at 2026-08-20T03:49:46+00:00
```

`list` 输出格式：`<share-id> <target> <url>`。

## 角色与安全

- operator：可控制目标；session 共享时可从浏览器发 rmux 前缀命令。operator URL 等价于本地
  已 attach 的客户端，持有者被信任可控制目标会话。
- spectator：只读。
- 默认 mint 一个 operator 私有 URL + 一个 spectator URL；`--operator-only` / `--spectator-only` 限定。
- 默认要求 6 位配对 PIN；`--no-pin` 关闭；`--pin-operator PIN` / `--pin-spectator PIN` 自定义。

## 生命周期

- 默认不自动过期；`--ttl SECONDS` 或 `--expires-at RFC3339` 设定过期。
- `--kill-session-on-expire`（仅 session share）到期销毁目标会话。
- `stop` / `disconnect` 撤销单个 share 并断开浏览器客户端，但不停 daemon、不停 web 监听。
- `--max-spectators N` / `--max-operators N` 限制并发。

## 网络模式

- 默认 loopback：`https://share.rmux.io/` 前端连接 `ws://127.0.0.1:<port>/share`。
- `--tunnel-provider NAME`：`localhost-run` / `sandhole` / `serveo` / `srv-us` /
  `tailscale-funnel` / `tailscale-serve`。
- `--tunnel-url URL`：自备公网端点。
- `--frontend-url URL`：自托管前端。
- `start-server --web-port PORT --frontend-url URL`：配置本地监听（port 0 会被拒绝）。
- Chromium 可能因 Local Network Access 拦截 loopback WS；需允许 share.rmux.io 的本地网络访问。

## 界面开关

- `--no-navbar` / `--no-disclaimer`：极简 spectator URL。
- `--hide-viewers`：隐藏在线人数。
- `--theme user|light|dark`。

## 远程 SSH 结论

0.10.0 不提供 `rmux ssh` / `rmux remote`。远程访问 = web-share（浏览器）或隧道 provider
（其中 srv-us / serveo / localhost-run 底层是 SSH 反向隧道）；纯 SSH 终端需求需自行
`ssh` + `rmux attach`。

## 开源与自建

share.rmux.io 的前端与加密层都是开源的：

- 主程序：`Helvesec/rmux`（public，仓库含 LICENSE-APACHE / LICENSE-MIT，双授权），
  内有 `crates/rmux-web-crypto`（E2EE 核心 + 浏览器 WASM 绑定）。
- 前端：`Helvesec/rmux-web-share`（public，Astro/TypeScript 静态前端，`wrangler.toml`
  表明部署到 Cloudflare），WASM 产物路径 `src/scripts/share/wasm`。
- WASM：主仓库 `scripts/build-web-crypto-wasm.sh` 从源码编译出
  `rmux_web_crypto_wasm_bg.wasm` + `.js`（wasm-bindgen / wasm-pack），承载
  X25519 + ML-KEM-768 + ChaCha20-Poly1305 的浏览器侧加密边界。

自建 = fork `Helvesec/rmux-web-share` 自托管静态站点，再
`rmux web-share --frontend-url https://你的域名` 或 `start-server --frontend-url ...`
指向它；需要完全掌控供应链时，用上述脚本自行编译 WASM。
