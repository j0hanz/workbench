---
description: 'Set up automated release & publishing for a TypeScript MCP server to npm, MCP Registry, Docker (GHCR), and GitHub Releases — all from a single workflow_dispatch trigger'
---

# Release MCP Server — Setup & Reuse Guide

One-click release workflow for TypeScript MCP servers. A single `workflow_dispatch` trigger bumps versions, validates, tags, creates a GitHub Release, and publishes to **npm** (Trusted Publishing/OIDC), **MCP Registry**, and **Docker** (GHCR) — no manual version edits needed.

## Prerequisites

- GitHub repository under `j0hanz/`
- npm account (`j0hanz`) with access to `@j0hanz` scope
- Package uses `@modelcontextprotocol/sdk` and stdio transport
- Node.js >= 24, TypeScript 5.9+

---

## 1. Package Configuration

### package.json

Required fields — replace `<package-name>` and `<description>` throughout:

```jsonc
{
  "name": "@j0hanz/<package-name>",
  "version": "1.0.0",
  "mcpName": "io.github.j0hanz/<package-name>",
  "description": "<description>",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "default": "./dist/index.js",
    },
    "./package.json": "./package.json",
  },
  "bin": {
    "<package-name>": "dist/index.js",
  },
  "files": ["dist", "README.md"],
  "repository": {
    "type": "git",
    "url": "https://github.com/j0hanz/<package-name>.git",
  },
  "homepage": "https://github.com/j0hanz/<package-name>#readme",
  "scripts": {
    "prepare": "npm run build",
    "prepublishOnly": "npm run lint && npm run type-check && npm run build",
  },
  "engines": {
    "node": ">=24",
  },
}
```

> **`prepare` script note:** The `prepare` script runs `npm run build` on `npm ci`. This is fine locally but breaks Docker builds where source files aren't yet copied. See Section 5 (Docker Setup) for the fix.

### server.json

Required for MCP Registry publishing. Place at repository root:

```jsonc
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "io.github.j0hanz/<package-name>",
  "title": "<Human-Readable Title>",
  "description": "<description>",
  "repository": {
    "url": "https://github.com/j0hanz/<package-name>",
    "source": "github",
  },
  "websiteUrl": "https://github.com/j0hanz/<package-name>#readme",
  "version": "1.0.0",
  "packages": [
    {
      "registryType": "npm",
      "identifier": "@j0hanz/<package-name>",
      "version": "1.0.0",
      "transport": { "type": "stdio" },
      "packageArguments": [
        // Define CLI positional/flag arguments here
      ],
    },
  ],
}
```

> **Important:** Only `"registryType": "npm"` is supported by the MCP Registry. Do NOT add `"registryType": "docker"` — it will cause a publish error (`unsupported registry type: docker`).

> Version fields in `server.json` are synced automatically by the release workflow via `jq` — no manual updates needed after initial setup.

### src/index.ts

The entrypoint **must** start with a shebang (no blank lines or BOM before it):

```ts
#!/usr/bin/env node
```

---

## 2. First-Time npm Publish (Manual)

**Trusted Publishing requires the package to already exist on npm.** For a brand-new scoped package, do a one-time manual publish:

```bash
# Log in to npm (opens browser for auth)
npm login

# Build first
npm run build

# Publish with public access (required for scoped packages)
npm publish --access public

# Verify
npm view @j0hanz/<package-name> dist-tags
```

---

## 3. Configure npm Trusted Publishing

After the package exists on npm:

1. Go to `https://www.npmjs.com/package/@j0hanz/<package-name>/access`
2. Under **Trusted Publisher** → click **Configure**
3. Fill in:

| Field                | Value              |
| -------------------- | ------------------ |
| Publisher            | **GitHub Actions** |
| Organization or user | `j0hanz`           |
| Repository           | `<package-name>`   |
| Workflow filename    | `release.yml`      |
| Environment name     | _(leave empty)_    |

4. Click **Set up connection**
5. Under **Publishing access**, select: **Require two-factor authentication or a granular access token with bypass 2fa enabled**
6. Click **Update Package Settings**

> This eliminates the need for any `NPM_TOKEN` secret in GitHub. OIDC handles authentication automatically.
>
> **Critical:** The workflow filename must match exactly — `release.yml` (not `publish.yml`).

---

## 4. GitHub Actions Workflow

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      bump:
        description: 'Version bump type'
        required: true
        type: choice
        default: patch
        options:
          - patch
          - minor
          - major
      custom_version:
        description: 'Custom version (overrides bump, e.g. 2.0.0-beta.1)'
        required: false
        type: string

permissions:
  contents: write
  id-token: write
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # ──────────────────────────────────────────────
  # 1. Bump versions, validate, tag & release
  # ──────────────────────────────────────────────
  release:
    name: Release
    runs-on: ubuntu-latest
    timeout-minutes: 15
    outputs:
      version: ${{ steps.ver.outputs.version }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'

      - name: Update npm
        run: npm install -g npm@latest

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

      - name: Determine version
        id: ver
        run: |
          CURRENT=$(node -p "require('./package.json').version")
          if [ -n "${{ inputs.custom_version }}" ]; then
            NEW="${{ inputs.custom_version }}"
          else
            IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
            case "${{ inputs.bump }}" in
              major) NEW="$((MAJOR + 1)).0.0" ;;
              minor) NEW="$MAJOR.$((MINOR + 1)).0" ;;
              patch) NEW="$MAJOR.$MINOR.$((PATCH + 1))" ;;
            esac
          fi
          echo "version=$NEW" >> "$GITHUB_OUTPUT"
          echo "### Version: $CURRENT → $NEW" >> "$GITHUB_STEP_SUMMARY"

      - name: Bump package.json & server.json
        env:
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          npm version "$VERSION" --no-git-tag-version --allow-same-version
          jq --arg v "$VERSION" '.version = $v | .packages[].version = $v' \
            server.json > tmp.json && mv tmp.json server.json
          npm install --package-lock-only --ignore-scripts

      - name: Install & validate
        run: |
          npm ci
          npm run lint
          npm run type-check
          npm run test
          npm run build

      - name: Commit, tag & push
        env:
          VERSION: ${{ steps.ver.outputs.version }}
        run: |
          git add package.json package-lock.json server.json
          git commit -m "release: v$VERSION"
          git tag -a "v$VERSION" -m "v$VERSION"
          git push origin main --follow-tags

      - name: Create GitHub release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VERSION: ${{ steps.ver.outputs.version }}
        run: gh release create "v$VERSION" --title "v$VERSION" --generate-notes

  # ──────────────────────────────────────────────
  # 2. Publish to npm (runs in parallel with Docker)
  # ──────────────────────────────────────────────
  publish-npm:
    name: npm
    needs: release
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      VERSION: ${{ needs.release.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: v${{ needs.release.outputs.version }}

      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          registry-url: 'https://registry.npmjs.org'

      - name: Update npm
        run: npm install -g npm@latest

      - name: Install & build
        run: npm ci && npm run build

      # Trusted Publishing: No NODE_AUTH_TOKEN needed — OIDC handles auth
      - name: Publish
        run: |
          npm publish --access public --provenance || {
            if npm view "@j0hanz/<package-name>@$VERSION" version 2>/dev/null; then
              echo "::notice::v$VERSION already on npm — skipped"
            else
              exit 1
            fi
          }

      - name: Summary
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" <<EOF
          ## 📦 Published to npm
          | | |
          |---|---|
          | **Package** | [\`@j0hanz/<package-name>@$VERSION\`](https://www.npmjs.com/package/@j0hanz/<package-name>) |
          | **Auth** | Trusted Publishing (OIDC) |
          | **Provenance** | ✅ |
          EOF

  # ──────────────────────────────────────────────
  # 3. Publish to MCP Registry (after npm, needs package available)
  # ──────────────────────────────────────────────
  publish-mcp:
    name: MCP Registry
    needs: [release, publish-npm]
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      VERSION: ${{ needs.release.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: v${{ needs.release.outputs.version }}

      - name: Publish
        run: |
          OS=$(uname -s | tr '[:upper:]' '[:lower:]')
          ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
          curl -fsSL "https://github.com/modelcontextprotocol/registry/releases/latest/download/mcp-publisher_${OS}_${ARCH}.tar.gz" \
            | tar xz mcp-publisher
          chmod +x mcp-publisher
          ./mcp-publisher login github-oidc
          ./mcp-publisher publish || echo "::notice::MCP Registry publish failed (may be duplicate) — continuing"

      - name: Summary
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" <<EOF
          ## 📡 Published to MCP Registry
          | | |
          |---|---|
          | **Server** | \`io.github.j0hanz/<package-name>@$VERSION\` |
          | **Registry** | [registry.modelcontextprotocol.io](https://registry.modelcontextprotocol.io) |
          EOF

  # ──────────────────────────────────────────────
  # 4. Build & push Docker image (runs in parallel with npm)
  # ──────────────────────────────────────────────
  publish-docker:
    name: Docker
    needs: release
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
        with:
          ref: v${{ needs.release.outputs.version }}

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}},value=v${{ needs.release.outputs.version }}
            type=semver,pattern={{major}}.{{minor}},value=v${{ needs.release.outputs.version }}
            type=semver,pattern={{major}},value=v${{ needs.release.outputs.version }}
            type=raw,value=latest

      - name: Build & push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          platforms: linux/amd64,linux/arm64
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Summary
        env:
          VERSION: ${{ needs.release.outputs.version }}
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" <<EOF
          ## 🐳 Docker Image Published
          | | |
          |---|---|
          | **Image** | \`${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:$VERSION\` |
          | **Platforms** | linux/amd64, linux/arm64 |
          EOF
```

### Workflow architecture

```text
workflow_dispatch (patch/minor/major)
    │
    ▼
  release ── bump versions → validate → commit → tag → GitHub Release
    │
    ├──► publish-npm ──► publish-mcp  (sequential: MCP Registry needs npm package)
    │
    └──► publish-docker              (parallel with npm)
```

### Key design decisions

- **Single workflow:** `GITHUB_TOKEN` events cannot trigger other workflows, so release + publish must be in one workflow. A separate `publish.yml` triggered by `on: release` would never fire.
- **`workflow_dispatch` trigger:** No manual version edits — pick `patch`/`minor`/`major` (or enter a custom version like `2.0.0-beta.1`) and the workflow handles everything.
- **Version sync:** `package.json`, `package-lock.json`, and `server.json` are all updated atomically via `npm version` + `jq` before committing.
- **Validation gate:** Lint, type-check, test, and build all run before any publishing. If validation fails, nothing is published.
- **Idempotent publishing:** npm tolerates already-published versions. MCP Registry tolerates duplicate versions. Safe to re-run.
- **Tagged checkout:** All publish jobs check out the exact tagged commit (`ref: v$VERSION`) to ensure consistency.
- **Provenance:** `--provenance` generates signed SLSA build attestations linked to the GitHub commit.
- **No secrets needed:** npm uses OIDC Trusted Publishing, MCP Registry uses GitHub OIDC, Docker uses `GITHUB_TOKEN` (built-in).

---

## 5. Docker Setup (Optional)

If the MCP server should also be published as a Docker image to GHCR, add these files.

### Dockerfile

Multi-stage build optimized for MCP servers with native modules:

```dockerfile
# ---- Builder Stage ----
FROM node:24-alpine AS builder

# Install build tools required for native modules (e.g. re2)
RUN apk add --no-cache python3 make g++

WORKDIR /app

# Install dependencies first (layer caching)
# --ignore-scripts avoids triggering `prepare` (build) before source is copied
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts && npm rebuild

# Copy source and build
COPY src/ ./src/
COPY tsconfig.json tsconfig.build.json ./
COPY scripts/ ./scripts/
COPY assets/ ./assets/
RUN npm run build

# Remove dev dependencies (keep pre-compiled native modules)
RUN npm prune --production

# ---- Release Stage ----
FROM node:24-alpine

ENV NODE_ENV=production

# Labels for Docker / MCP Catalog
LABEL org.opencontainers.image.title="<Human-Readable Title>" \
      org.opencontainers.image.description="<description>" \
      org.opencontainers.image.source="https://github.com/j0hanz/<package-name>" \
      org.opencontainers.image.licenses="MIT" \
      io.modelcontextprotocol.server.name="io.github.j0hanz/<package-name>"

# Create non-root user
RUN adduser -D mcp

WORKDIR /app

# Copy built artifacts and pre-compiled dependencies from builder
COPY --from=builder /app/dist ./dist/
COPY --from=builder /app/node_modules ./node_modules/
COPY --from=builder /app/package.json ./
COPY --from=builder /app/assets ./assets/

USER mcp

ENTRYPOINT ["node", "dist/index.js"]
```

> **`--ignore-scripts && npm rebuild` pattern:** The `prepare` script in `package.json` runs `npm run build`, which fails during `npm ci` because source files haven't been copied yet. Using `--ignore-scripts` skips all lifecycle scripts, then `npm rebuild` compiles only native addons (like `re2`) without triggering `prepare`.

### .dockerignore

```text
# Dependencies
node_modules

# Build output
dist
*.tsbuildinfo

# Version control
.git
.gitignore

# CI/CD & Editor
.github
.vscode
.cursor

# Tests
src/__tests__
node-tests
coverage

# Development
.env
.env.*
.ts-trace

# Docker (avoid recursive context)
Dockerfile
docker-compose.yml
.dockerignore

# Documentation (not needed in image)
*.md
!README.md
LICENSE
CONTRIBUTING.md

# Tooling configs
eslint.config.mjs
knip.json
.prettierrc*
```

### docker-compose.yml (local testing)

```yaml
services:
  <package-name>:
    build: .
    stdin_open: true
    volumes:
      - ./:/projects/workspace:ro
    command: ['/projects/workspace']
```

> If no Docker image is needed, remove the `publish-docker` job from `release.yml` and the `packages: write` permission.

---

## 6. Creating a Release

### Option A: GitHub UI (recommended)

1. Go to **Actions** → **Release** → **Run workflow**
2. Select bump type: `patch` / `minor` / `major` (or enter a custom version)
3. Click **Run workflow**

The workflow automatically: bumps versions → validates → commits → tags → creates GitHub Release → publishes to npm + MCP Registry + Docker.

### Option B: GitHub CLI

```bash
gh workflow run release.yml -f bump=patch
```

### Re-triggering a failed release

If publishing fails but the release was created:

```bash
# Delete the release and tag
gh release delete v1.0.1 --repo j0hanz/<package-name> --yes --cleanup-tag
git tag -d v1.0.1
git push origin :refs/tags/v1.0.1

# Revert the version commit
git revert HEAD --no-edit
git push origin main

# Re-run the workflow
gh workflow run release.yml -f bump=patch
```

---

## 7. Verification

After the workflow completes:

```bash
# npm
npm view @j0hanz/<package-name> dist-tags
npm view @j0hanz/<package-name> versions --json

# Test installation
npx -y @j0hanz/<package-name>@latest --help

# Docker (if applicable)
docker pull ghcr.io/j0hanz/<package-name>:latest
docker run --rm -i ghcr.io/j0hanz/<package-name>:latest /some/path

# MCP protocol handshake test (stdin JSON-RPC)
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  | npx -y @j0hanz/<package-name>@latest . 2>/dev/null \
  | head -1 | jq .result.serverInfo
```

---

## 8. Troubleshooting

| Error                                            | Cause                                                     | Fix                                                                    |
| ------------------------------------------------ | --------------------------------------------------------- | ---------------------------------------------------------------------- |
| `E404 Not Found` on first publish                | Package doesn't exist on npm yet                          | Do a manual `npm publish --access public` first (Section 2)            |
| `EOTP` / `Access token expired`                  | Trusted Publishing not configured                         | Set up Trusted Publishing (Section 3)                                  |
| `E403 Forbidden` on npm publish                  | OIDC token not authorized                                 | Verify workflow filename in Trusted Publishing config is `release.yml` |
| Version already published                        | Same version re-triggered                                 | Safe to ignore — the fallback check handles this                       |
| MCP Registry login fails                         | Missing `id-token: write` permission                      | Ensure `permissions: id-token: write` in workflow                      |
| MCP Registry `duplicate version`                 | Already published on earlier attempt                      | Safe to ignore — `publish-mcp` job tolerates this                      |
| MCP Registry `unsupported registry type: docker` | `server.json` has a docker package entry                  | Remove docker entry — only `"registryType": "npm"` is supported        |
| Docker build fails on `prepare` script           | `npm ci` triggers `npm run build` before source is copied | Use `npm ci --ignore-scripts && npm rebuild` in Dockerfile             |
| `GITHUB_TOKEN` can't trigger other workflows     | Events from `GITHUB_TOKEN` don't trigger `on: release`    | Use a single unified workflow (don't split release + publish)          |
| `always-auth` warning                            | Deprecated npm config in CI                               | Harmless warning, can be ignored                                       |

---

## 9. Adapting for a New MCP Server

To reuse this setup for a new `j0hanz/` MCP server repository:

1. **Find & replace** `<package-name>` with the actual package name in all files
2. **Copy these files** from an existing MCP server repo:
   - `.github/workflows/release.yml` — update the npm package identifier in the publish fallback check
   - `Dockerfile` — adjust `COPY` commands for your project's file structure
   - `.dockerignore` — adjust as needed
   - `docker-compose.yml` — update service name
3. **Create** `server.json` at repo root with correct MCP server metadata
4. **Verify** `package.json` has all required fields (name, bin, files, exports, repository, engines)
5. **Verify** `src/index.ts` starts with `#!/usr/bin/env node`
6. **Manual first publish** to npm: `npm publish --access public`
7. **Configure Trusted Publishing** on npmjs.com (workflow filename: `release.yml`)
8. **First automated release:** `gh workflow run release.yml -f bump=patch`

---

## 10. Checklist

- [ ] `package.json` has `name`, `mcpName`, `bin`, `files`, `exports`, `repository`, `engines`
- [ ] `server.json` at repo root — only `"registryType": "npm"` in packages (no docker)
- [ ] `src/index.ts` starts with `#!/usr/bin/env node` (shebang, first line)
- [ ] `.github/workflows/release.yml` exists with correct package name
- [ ] First version published manually via `npm publish --access public`
- [ ] Trusted Publishing configured on npmjs.com (workflow filename: `release.yml`)
- [ ] Publishing access set to require 2FA or granular tokens with bypass
- [ ] Dockerfile uses `npm ci --ignore-scripts && npm rebuild` (if Docker is enabled)
- [ ] `.dockerignore` excludes unnecessary files from build context
- [ ] Test release: `gh workflow run release.yml -f bump=patch`
- [ ] All 4 jobs pass: release → npm + Docker (parallel) → MCP Registry
- [ ] `npm view @j0hanz/<package-name> dist-tags` shows correct `latest`
