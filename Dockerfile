# Stage 1 - package.json skeleton (keeps the yarn install layer cacheable)
FROM node:22-bookworm-slim AS packages
WORKDIR /app
COPY backstage.json package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
COPY packages packages
COPY plugins plugins
RUN find packages plugins \! -name "package.json" -mindepth 2 -maxdepth 2 -exec rm -rf {} \+

# Stage 2 - install all deps and build
FROM node:22-bookworm-slim AS build
ENV PYTHON=/usr/bin/python3
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*
USER node
WORKDIR /app
COPY --from=packages --chown=node:node /app .
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --immutable
COPY --chown=node:node . .
RUN yarn tsc
RUN yarn --cwd packages/backend build
RUN mkdir packages/backend/dist/skeleton packages/backend/dist/bundle \
    && tar xzf packages/backend/dist/skeleton.tar.gz -C packages/backend/dist/skeleton \
    && tar xzf packages/backend/dist/bundle.tar.gz -C packages/backend/dist/bundle

# Stage 3 - runtime
FROM node:22-bookworm-slim
ENV PYTHON=/usr/bin/python3
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv g++ build-essential libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# TechDocs: mkdocs for builder=local, generator.runIn=local
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN pip install --no-cache-dir mkdocs-techdocs-core

USER node
WORKDIR /app
COPY --from=build --chown=node:node /app/.yarn ./.yarn
COPY --from=build --chown=node:node /app/.yarnrc.yml /app/backstage.json ./
COPY --from=build --chown=node:node /app/yarn.lock /app/package.json /app/packages/backend/dist/skeleton/ ./
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"
COPY --from=build --chown=node:node /app/packages/backend/dist/bundle/ ./
COPY --chown=node:node app-config*.yaml ./

ENV NODE_ENV=production
ENV NODE_OPTIONS="--no-node-snapshot"
EXPOSE 7007
CMD ["node", "packages/backend", "--config", "app-config.yaml"]