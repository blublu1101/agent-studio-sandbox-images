# agent-studio-sandbox-images

Agent Studio 沙箱基础镜像的源码。镜像由 OpenSandbox（Docker + gVisor）用来创建 Thread 沙箱，Agent 的 `execute` 命令在其中运行。设计依据见 Agent Studio 仓库的 ADR 0013 与《OpenSandbox 沙箱节点部署手册》。

## 镜像内容

| 项 | 内容 |
| --- | --- |
| 基础 | `python:3.13-slim-trixie`（Debian 13），按摘要固定 |
| Python | 3.13，预装 `numpy`、`pandas`（版本与哈希锁定在 `requirements.txt`） |
| Node.js | 22 LTS 与 npm，来自 `node:22-trixie-slim` |
| 命令行工具 | `bash`、`git`、`curl`、`jq`、`unzip`、`zip`、`xz`、`file`、`tree`、`less`、`ps`、`timeout` |
| 用户 | 默认以 `sandbox`（uid/gid `1000`）运行，`HOME=/home/sandbox` |
| 工作区 | `/workspace`，归 `1000:1000` 所有，是默认工作目录 |

约束：

- 镜像不含任何密钥、令牌或 Studio 代码，也不在构建时写入凭证。
- 沙箱网络由 Studio 按 Agent 配置（`none` 或 `allowlist`），默认断网，不要假设运行时可以 `pip install` 或 `npm install`。
- 只有 `/workspace` 在沙箱休眠与恢复之间保留（它是每代沙箱的 Docker 具名卷）。`HOME` 与其他目录中的改动在休眠后丢失。
- 新具名卷首次挂载到 `/workspace` 时，Docker 会复制镜像中该目录的属主，因此不要更改 `/workspace` 的属主或默认用户的 uid。

## 发布与使用

推送到 `main` 或推送 `v*` 标签时，GitHub Actions 会先构建镜像并运行 `tests/smoke.sh` 冒烟测试，通过后发布到：

```text
ghcr.io/blublu1101/agent-studio-sandbox-base
```

标签包括 `sha-<提交>`、`main`、`latest` 和语义化版本（如 `1.0.0`）。标签只用于查找；部署时一律按摘要引用。工作流摘要页会给出 `ref@digest`：

1. 在沙箱节点预拉取：`docker pull ghcr.io/blublu1101/agent-studio-sandbox-base@sha256:<digest>`。
2. 把同一 `ref@digest` 写入 Studio 的 `STUDIO_SANDBOX_ALLOWED_IMAGES`（API 与 Worker）。
3. 按部署手册在沙箱节点上用新镜像创建一次沙箱进行验证，再在 Agent 中引用新摘要。

已发布的 Agent 版本快照冻结了当时的镜像摘要，旧摘要在仍有 Agent 版本引用期间应保留在白名单和节点上。

拉取请求只构建和测试，不发布镜像。

## 本地构建与测试

```bash
docker buildx build --platform linux/amd64 --load -t sandbox-base:local .
tests/smoke.sh sandbox-base:local
```

## 更新依赖

- 基础镜像、GitHub Actions 与 Python 包由 Dependabot 每周检查，更新以拉取请求提交。
- 手动调整 Python 包时修改 `requirements.in`，再重新生成带哈希的锁文件：

  ```bash
  uv pip compile requirements.in --generate-hashes --python-version 3.13 \
    --python-platform x86_64-manylinux_2_28 --only-binary :all: --no-header -o requirements.txt
  ```

- 新增软件包前确认它确实是 Agent 常用的运行环境，避免把镜像变成通用开发机。

## 平台

目前只构建 `linux/amd64`，与沙箱节点一致。需要 `arm64` 时，在工作流的 `PLATFORMS` 中追加 `linux/arm64`；`requirements.txt` 已包含各平台发行包的哈希。
