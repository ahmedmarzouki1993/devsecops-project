#!/bin/bash
# ============================================================================
# MCP Server Setup for Claude Code — devsecops-project
# ============================================================================
# Run this ONCE after cloning the repo and installing Claude Code.
# These MCP servers give Claude Code direct access to your tools.
#
# What is MCP? Model Context Protocol — an open standard that lets Claude Code
# connect to external tools. Instead of YOU running kubectl and pasting output,
# Claude Code runs it directly. Same for GitLab, Slack, etc.
# ============================================================================

set -e
echo "=========================================="
echo "  MCP Server Setup for devsecops-project"
echo "=========================================="
echo ""

# -----------------------------------------------
# 1. Sequential Thinking (helps with complex tasks)
# -----------------------------------------------
# WHY: When Claude needs to plan multi-step operations (like debugging a
# failed pipeline), this MCP helps it think step-by-step instead of
# jumping to conclusions.
echo "[1/4] Adding Sequential Thinking MCP..."
claude mcp add sequential-thinking \
  --scope local \
  -- npx -y mcp-sequentialthinking-tools
echo "  ✅ Sequential Thinking ready"
echo ""

# -----------------------------------------------
# 2. Kubernetes MCP (direct cluster access)
# -----------------------------------------------
# WHY: Claude Code can run kubectl commands, inspect pods, read logs,
# and debug deployments directly. No more copy-pasting kubectl output.
# It uses your local kubeconfig (~/.kube/config), so it has the same
# access level as your terminal.
echo "[2/4] Adding Kubernetes MCP..."
claude mcp add kubernetes \
  --scope local \
  -- npx -y @modelcontextprotocol/server-kubernetes
echo "  ✅ Kubernetes MCP ready (uses your kubeconfig)"
echo ""

# -----------------------------------------------
# 3. GitLab MCP (optional — requires personal access token)
# -----------------------------------------------
# WHY: Claude Code can create issues, read pipelines, check MR status,
# and interact with your GitLab project directly.
# SETUP: Create a GitLab PAT at gitlab.com/-/user_settings/personal_access_tokens
#        Scopes needed: api, read_repository, write_repository
echo "[3/4] GitLab MCP..."
if [ -z "$GITLAB_TOKEN" ]; then
  echo "  ⚠️  GITLAB_TOKEN not set. Skipping GitLab MCP."
  echo "  To add later:"
  echo "    export GITLAB_TOKEN=glpat-xxxxx"
  echo "    claude mcp add gitlab --scope local -e GITLAB_TOKEN=\$GITLAB_TOKEN -- npx -y @modelcontextprotocol/server-gitlab"
else
  claude mcp add gitlab \
    --scope local \
    -e GITLAB_TOKEN="$GITLAB_TOKEN" \
    -- npx -y @modelcontextprotocol/server-gitlab
  echo "  ✅ GitLab MCP ready"
fi
echo ""

# -----------------------------------------------
# 4. Context7 (up-to-date documentation lookup)
# -----------------------------------------------
# WHY: Claude's training data has a cutoff. Context7 lets it fetch
# CURRENT documentation for Terraform, Kubernetes, FastAPI, ArgoCD, etc.
# This means Claude gives you answers based on the latest docs, not
# potentially outdated training data.
echo "[4/4] Adding Context7 (live documentation)..."
claude mcp add context7 \
  --scope local \
  -- npx -y @upstash/context7-mcp@latest
echo "  ✅ Context7 ready"
echo ""

# -----------------------------------------------
# Verify all MCPs
# -----------------------------------------------
echo "=========================================="
echo "  Verifying MCP servers..."
echo "=========================================="
claude mcp list
echo ""
echo "✅ MCP setup complete! Restart Claude Code to activate."
echo ""
echo "TIP: Run '/mcp' inside Claude Code to check server status."
