# Falco — Runtime Security

## Installation

Falco is installed via Helm with Falcosidekick routing alerts to Slack #alerts.

```bash
helm install falco falcosecurity/falco \
  --namespace falco \
  --set driver.kind=modern_ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl="$SLACK_WEBHOOK_ALERTS" \
  --set falcosidekick.config.slack.minimumpriority=warning \
  --set "falco.http_output.enabled=true" \
  --set "falco.http_output.url=http://falco-falcosidekick:2801" \
  --set "falco.json_output=true"
```

## How it works

Falco uses eBPF (modern_ebpf driver) to intercept Linux syscalls on the node.
When a syscall matches a rule condition, Falco fires an alert.
Falcosidekick receives the alert via HTTP and forwards it to Slack.

## Known noisy rules (expected alerts)

| Rule | Source | Action |
|------|--------|--------|
| Contact K8S API Server From Container | ArgoCD, kyverno, system pods | Ignore — these are legitimate |

## To tune (Phase 8)

Add a `falco_rules.local.yaml` that overrides specific rules to reduce noise:
- Allowlist ArgoCD, Kyverno, ingress-nginx from the K8s API rule
- ~~Raise minimum priority to `warning` for production~~ ✅ Done
