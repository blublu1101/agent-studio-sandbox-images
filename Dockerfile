# syntax=docker/dockerfile:1
# Agent Studio 沙箱基础镜像：供 OpenSandbox（Docker + gVisor）创建 Thread 沙箱使用。
# 镜像只提供运行环境，不包含任何密钥或 Studio 代码。

FROM node:22-trixie-slim@sha256:154ba2f4d6fec323d28e4f4bb86bba4677f1223391a1979cf521304e03a98dfa AS node

FROM python:3.14-slim-trixie@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170

ARG SANDBOX_UID=1000
ARG SANDBOX_GID=1000

ENV LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        file \
        git \
        jq \
        less \
        procps \
        tree \
        tzdata \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

COPY requirements.txt /tmp/requirements.txt
RUN pip install --require-hashes --only-binary=:all: -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# 新具名卷首次挂载到 /workspace 时，Docker 会复制镜像中该目录的属主与内容，
# 因此这里决定了沙箱工作区默认归固定的非 root 用户所有。
RUN groupadd --gid "${SANDBOX_GID}" sandbox \
    && useradd --uid "${SANDBOX_UID}" --gid "${SANDBOX_GID}" --create-home --home-dir /home/sandbox --shell /bin/bash sandbox \
    && mkdir -p /workspace \
    && chown "${SANDBOX_UID}:${SANDBOX_GID}" /workspace \
    && chmod 0755 /workspace

ENV HOME=/home/sandbox
WORKDIR /workspace
USER ${SANDBOX_UID}:${SANDBOX_GID}

CMD ["sleep", "infinity"]
