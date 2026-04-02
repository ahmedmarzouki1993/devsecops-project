#!/usr/bin/env bash
# audit-rbac.sh — Phase 8 RBAC hardening check
#
# Checks for cluster-admin bindings that are NOT system accounts.
# Run before any release to verify no accidental privilege escalation.
#
# Expected output: only kube-system service accounts and built-in groups.
# Any user-created binding here is a CRITICAL finding.

set -euo pipefail

echo "=== ClusterRoleBindings to cluster-admin ==="
kubectl get clusterrolebindings \
  -o json \
  | jq -r '
    .items[]
    | select(.roleRef.name == "cluster-admin")
    | {
        name: .metadata.name,
        subjects: [.subjects[]? | {kind, name, namespace}]
      }
    | @json
  ' \
  | jq .

echo ""
echo "=== Namespaced RoleBindings granting cluster-admin in devsecops-project ==="
kubectl get rolebindings -n devsecops-project \
  -o json \
  | jq -r '
    .items[]
    | select(.roleRef.name == "cluster-admin")
    | {name: .metadata.name, subjects: [.subjects[]?]}
    | @json
  ' \
  | jq .

echo ""
echo "=== ServiceAccounts with cluster-scope roles in devsecops-project ==="
kubectl get clusterrolebindings \
  -o json \
  | jq -r --arg ns "devsecops-project" '
    .items[]
    | select(.subjects[]? | .namespace == $ns)
    | {binding: .metadata.name, role: .roleRef.name, subjects: [.subjects[]]}
    | @json
  ' \
  | jq .

echo ""
echo "Audit complete. Review any non-system subjects above."
echo "Acceptable system subjects: system:masters, system:bootstrappers, system:nodes,"
echo "  kube-system service accounts, cloud-provider managed identities."
