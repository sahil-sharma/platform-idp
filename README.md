# Platform IDP (Backstage Architecture & Container Build)

This repository contains the source code, custom plugins, backend integrations, and container deployment scripts for our enterprise **Backstage Internal Developer Portal (IDP)**.

> Note: This repo has GitHub Action workflow that automatically build and push docker image from main branch.

---

## Prerequisites

To work with this repository locally without needing Node.js or Yarn installed on your host system, we leverage a lightweight Docker alias called `nodec`:

```bash
alias nodec='docker run --rm -it -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$HOME/.cache:/tmp/.cache" -v "$PWD":/work -w /work node:22-bookworm'
```

## 1. How to Add New Plugins or Dependencies

When adding backend plugins, frontend plugins, or external node packages, you must always declare them inside the appropriate package.json file and regenerate the lockfile so that CI/CD pipelines (`yarn install --immutable`) pass smoothly.

### Step A: Install the Package via Container

Run the yarn add command scoped to the package you are modifying (e.g., packages/backend or packages/app). For example, to add a backend module:

```bash
nodec yarn --cwd packages/backend add <package-name>
```

### Step B: Validate Prettier and Linting Standards

Backstage enforces strict linting and code formatting. Before committing, run checks locally:

```bash
# Check code formatting
nodec yarn prettier:check

# Auto-fix formatting issues if any warnings appear
nodec npx prettier --write "packages/**/*.{ts,tsx,js,jsx,json,md,html}"

# Run all linters
nodec yarn lint:all
```

## 2. How to Build the Docker Image Locally

### Step 1: Install Dependencies and Compile TypeScript

From the repository root, install dependencies and generate required type definitions:

```bash
nodec yarn install --immutable
nodec yarn tsc
```

### Step 2: Build the Docker Image

With the bundle artifacts prepared in your workspace root, run the Docker build command using the repository root as the build context:

```bash
DOCKER_BUILDKIT=1 docker build \
  -t <dockerhub-username>/<docker-repo>:<image-tag> .

docker push <dockerhub-username>/<docker-repo>:<image-tag>
```
