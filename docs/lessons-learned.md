# Lessons Learned

Things that bit me while building this. Hopefully saves someone else the debugging time.

---

## 1. Kind port mappings only work on control-plane nodes

Spent way too long wondering why ingress wasn't reachable from localhost. Turns out kind only maps ports on the control-plane node — workers don't get Docker port mappings at all.

Fix: put `extraPortMappings` on the control-plane in the kind config, and make sure the ingress controller schedules there (`nodeSelector: ingress-ready=true`).

Should've read the kind ingress docs first instead of assuming it works like a real cluster.

---

## 2. ArgoCD self-heal without prune = orphaned resources everywhere

Enabled `selfHeal: true` thinking that was enough. Nope. It only reverts *modifications* to existing resources. If you delete something from git, it stays in the cluster forever unless you also have `prune: true`.

Ended up with a bunch of zombie resources that I had to clean up manually. Just enable both from day one.

---

## 3. Trivy will fail your CI on unfixable CVEs

Base images (especially Python) have CVEs in system libraries that nobody has patched yet. Trivy reports them all by default, so your pipeline is red permanently.

Fix: `--ignore-unfixed` and only fail on CRITICAL. Still reports everything else as warnings so you're aware, but doesn't block deployments for things you can't actually fix.

---

## 4. ReadOnlyRootFilesystem breaks Python apps

Turned on `readOnlyRootFilesystem: true` (as you should), and everything crashed. Python writes .pyc files, uvicorn needs socket files, etc.

Fix: mount an emptyDir at `/tmp` with a size limit. Gives the app scratch space without compromising the read-only root.

Every language has its own quirks here. Test this per-app, don't just blanket apply it.

---

## 5. HPA and GitOps replica counts fight each other

ArgoCD sees the deployment has 4 replicas (because HPA scaled it) but git says 2. So it shows "OutOfSync" forever and keeps trying to scale back down.

Fix: add `ignoreDifferences` for `/spec/replicas` in the ArgoCD Application. Also wrap the replicas field in the Helm template with `{{- if not .Values.autoscaling.enabled }}` so it's only set when HPA is off.

This one's well-documented but easy to forget when you're setting things up.

---

## 6. Default-deny NetworkPolicy breaks DNS

Applied a default-deny policy and suddenly nothing works. Pods can't resolve service names because DNS queries to kube-dns are blocked.

Fix: always pair default-deny with an explicit DNS egress allow (UDP+TCP port 53 to kube-system). I put them in the same file now so I never forget.

---

## 7. Prometheus can't find your rules without the right labels

Created PrometheusRules, conditions were met, no alerts fired. Turns out kube-prometheus-stack configures Prometheus to only discover rules with `release: prometheus` label. Without it, your rules are invisible.

Fix: add the label. Or set `ruleSelectorNilUsesHelmValues: false` in the Prometheus spec to discover everything.

The CRD docs don't mention this. You have to look at the Helm chart's default values.

---

## 8. Liveness probes that check dependencies = cascading failures

Had the liveness probe hitting `/ready` which checked the database. DB went down for 30 seconds, Kubernetes killed all the pods, now the app is down too even though it could've served cached responses.

Fix: liveness = "is the process alive?" (just return 200). Readiness = "can it serve traffic?" (check deps). If readiness fails, pod gets removed from the Service but stays alive to recover.

This is k8s 101 but I still got it wrong the first time.

---

## 9. No PDB = all pods evicted at once during drain

Simulated a node drain and got a full outage. Both replicas were on the same node, both got evicted simultaneously.

Fix: PodDisruptionBudget with `minAvailable: 1` + pod anti-affinity to spread across nodes. Now drains respect the budget.

PDB is like 5 lines of YAML. No excuse not to have it.

---

## 10. Deploy pipeline commits trigger infinite CI loops

Deploy pipeline updates helm values and commits to main. That triggers CI. CI triggers deploy. Deploy commits again. Loop forever.

Fix: commit message includes `[skip ci]`. Also added a path filter so CI ignores changes to `helm/app/values.yaml` when the author is `github-actions[bot]`.

Felt dumb when I figured this out but apparently it's a common gotcha.
