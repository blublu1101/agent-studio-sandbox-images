# syntax=docker/dockerfile:1
# Agent Studio 沙箱基础镜像：供 OpenSandbox（Docker + gVisor）创建 Thread 沙箱使用。
# 镜像只提供运行环境，不包含任何密钥或 Studio 代码。

FROM node:25-trixie-slim@sha256:aabbe39553d15ede8a97cc60c9e1a97034ff772afcf696ea42b94e7f5f2ec71b AS node

FROM python:3.13-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f

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
