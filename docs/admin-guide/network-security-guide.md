# Network Security Guide

This document describes how to secure intra-cluster communication for the Spyre Operator and its managed components using Kubernetes `NetworkPolicy` resources. It lists every port exposed by each component, explains the purpose of each port, and provides ready-to-use `NetworkPolicy` manifests together with the RBAC and CRD prerequisites required to apply them.

## Table of Contents <!-- omit in toc -->

- [Prerequisites](#prerequisites)
  - [Required Packages](#required-packages)
  - [CRD — NetworkPolicy](#crd--networkpolicy)
  - [RBAC — Cluster Admin Permission](#rbac--cluster-admin-permission)
- [Open Ports Reference](#open-ports-reference)
- [Network Policies per Component](#network-policies-per-component)
  - [Card Management Plugin](#card-management-plugin)
  - [Metrics Exporter](#metrics-exporter)
  - [Health Checker](#health-checker)
  - [Webhook Validator](#webhook-validator)
  - [Device Plugin / DRA Driver](#device-plugin--dra-driver)
  - [Spyre Operator](#spyre-operator)
- [NetworkPolicy Example Files](#networkpolicy-example-files)
- [Verify the Policies](#verify-the-policies)

---

## Prerequisites

### Required Packages

The following cluster capabilities must be in place before you apply any `NetworkPolicy`:

| Requirement | Notes |
| --- | --- |
| A CNI plugin that enforces `NetworkPolicy` | OpenShift's default OVN-Kubernetes and SDN plugins both enforce `NetworkPolicy`. Confirm with `oc get clusternetwork`. |
| `cert-manager` | Required by the Spyre Operator for mutual TLS between components. Install from OperatorHub (`cert-manager` or `openshift-cert-manager-operator`). |
| Spyre Operator installed | The `NetworkPolicy` resources reference pod labels created by the operator. The operator must be installed in the `spyre-operator` namespace before applying these policies. |

### CRD — NetworkPolicy

`NetworkPolicy` is a core Kubernetes API resource in group `networking.k8s.io/v1`. No additional CRD installation is needed. The API is available in every Kubernetes 1.7+ and OpenShift 4.x cluster.

Confirm availability:

```shell
oc api-resources --api-group=networking.k8s.io | grep networkpolicies
```

Expected output:

```text
networkpolicies    netpol    networking.k8s.io/v1    true    NetworkPolicy
```

### RBAC — Cluster Admin Permission

Applying `NetworkPolicy` resources requires the `create`, `update`, and `patch` verbs on the `networkpolicies` resource. On OpenShift, the built-in `cluster-admin` role already includes these verbs.

If you want to delegate `NetworkPolicy` management to a dedicated service account, create the following `Role` and `RoleBinding` in the `spyre-operator` namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spyre-netpol-manager
  namespace: spyre-operator
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spyre-netpol-manager
  namespace: spyre-operator
subjects:
- kind: ServiceAccount
  name: spyre-netpol-admin   # replace with your service account name
  namespace: spyre-operator
roleRef:
  kind: Role
  name: spyre-netpol-manager
  apiGroup: rbac.authorization.k8s.io
```

---

## Open Ports Reference

The table below lists every TCP port that Spyre Operator components listen on. Unix-domain sockets (used for kubelet device-plugin registration and the health-checker socket) are local to the node and are not affected by `NetworkPolicy`.

| Component | Pod label | Port | Protocol | Purpose | Consumers |
| --- | --- | --- | --- | --- | --- |
| `spyre-operator` | `app=spyre-operator` | `8443` | HTTPS | Operator metrics and leader-election webhook | kube-apiserver (Kubernetes internal) |
| `spyre-webhook-validator` | `app=spyre-webhook-validator` | `9443` | HTTPS (TLS) | Admission webhook (ValidatingWebhookConfiguration) | kube-apiserver |
| `spyre-health-checker` | `app=spyre-health-checker` | `8080` | HTTP | Liveness `/healthz` and readiness `/readyz` probes | kubelet (node-local) |
| `spyre-health-checker` | `app=spyre-health-checker` | `8081` | HTTP | Prometheus metrics (`/metrics`) | Prometheus / `ServiceMonitor` |
| `spyre-metrics-exporter` | `app=spyre-metrics-exporter` | `8082` | HTTP | Prometheus metrics (`/metrics`). Configurable via `.spec.metricsExporter.port`. | Prometheus / `ServiceMonitor` |
| `spyre-card-management` | `app=cardmgmt` | _(unix socket)_ | — | Internal gRPC between card management and runner containers | Node-local only; not exposed over the network |
| `spyre-device-plugin` | `app=spyre-device-plugin` | _(unix socket)_ | — | Kubelet device-plugin API | Node-local only; not exposed over the network |

> [!NOTE]
> The metrics exporter default port is `8082`. If you have changed it via `.spec.metricsExporter.port` in your `SpyreClusterPolicy`, substitute your custom port in the policies below.

---

## Network Policies per Component

The namespace used throughout this guide is `spyre-operator`. Adjust if you installed the operator in a different namespace.

> [!IMPORTANT]
> By default, Kubernetes does not restrict pod-to-pod traffic. The policies below use a **default-deny** ingress posture per component and then explicitly allow only the necessary sources. Apply them incrementally and verify each component remains healthy after each policy is in place.

### Card Management Plugin

The card management plugin (`spyre-card-management`) communicates with runner containers through a Unix-domain socket on the node. It does **not** expose any TCP port to the cluster network. No ingress from any other pod or external endpoint should be allowed.

See [`networkpolicy/card-management-policy.yaml`](networkpolicy/card-management-policy.yaml) for the ready-to-use file.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: card-management-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: cardmgmt
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

> [!NOTE]
> `podSelector: {}` selects all pods **within the same namespace** (`spyre-operator`). Because card management exposes no TCP ports to the network, the effective result is that ingress is limited to same-namespace pods only — which still matches no real traffic since there is no TCP listener. This prevents any pod outside `spyre-operator` from initiating connections.
>
> If you want a stricter policy that blocks **all** ingress (including from same-namespace pods), remove the `ingress` section entirely and keep only `policyTypes: [Ingress]`:
>
> ```yaml
> spec:
>   podSelector:
>     matchLabels:
>       app: cardmgmt
>   policyTypes:
>   - Ingress
>   # no ingress rules — all ingress is denied
> ```

Apply:

```shell
oc apply -f networkpolicy/card-management-policy.yaml
```

---

### Metrics Exporter

The metrics exporter exposes port `8082` (default) for Prometheus scraping. Only the Prometheus pods (typically in `openshift-monitoring` or your custom monitoring namespace) need to reach this port.

See [`networkpolicy/metrics-exporter-policy.yaml`](networkpolicy/metrics-exporter-policy.yaml) for the ready-to-use file.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: metrics-exporter-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: spyre-metrics-exporter
  policyTypes:
  - Ingress
  ingress:
  # Allow Prometheus scraping from the monitoring namespace
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-monitoring
    ports:
    - protocol: TCP
      port: 8082
  # Allow scraping from a custom monitoring namespace (optional)
  # - from:
  #   - namespaceSelector:
  #       matchLabels:
  #         kubernetes.io/metadata.name: <your-monitoring-namespace>
  #   ports:
  #   - protocol: TCP
  #     port: 8082
```

> [!NOTE]
> Replace `8082` with your custom port if you changed `.spec.metricsExporter.port`.

Apply:

```shell
oc apply -f networkpolicy/metrics-exporter-policy.yaml
```

---

### Health Checker

The health checker exposes two TCP ports:

| Port | Purpose | Consumers |
| --- | --- | --- |
| `8080` | Health probes (`/healthz`, `/readyz`) | kubelet (automatically; probes originate from the node's host network) |
| `8081` | Prometheus metrics (`/metrics`) | Prometheus / `ServiceMonitor` |

See [`networkpolicy/health-checker-policy.yaml`](networkpolicy/health-checker-policy.yaml) for the ready-to-use file.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: health-checker-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: spyre-health-checker
  policyTypes:
  - Ingress
  ingress:
  # Allow kubelet probes (from the node host network)
  - from:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: []
    ports:
    - protocol: TCP
      port: 8080
  # Allow Prometheus scraping from the monitoring namespace
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-monitoring
    ports:
    - protocol: TCP
      port: 8081
```

> [!TIP]
> If you know the exact CIDR of your node IPs, replace `0.0.0.0/0` with the node subnet (e.g., `192.168.0.0/24`) to further restrict who can probe the health port.

Apply:

```shell
oc apply -f networkpolicy/health-checker-policy.yaml
```

---

### Webhook Validator

The admission webhook validator (`spyre-webhook-validator`) must accept connections from the Kubernetes API server only. The API server originates from the host network of a control-plane node, so the policy must allow the API server's source CIDR.

See [`networkpolicy/webhook-validator-policy.yaml`](networkpolicy/webhook-validator-policy.yaml) for the ready-to-use file.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: webhook-validator-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: spyre-webhook-validator
  policyTypes:
  - Ingress
  ingress:
  # Allow the Kubernetes API server to reach the admission webhook
  - from:
    - ipBlock:
        cidr: 0.0.0.0/0  # narrow this to your control-plane node CIDR
    ports:
    - protocol: TCP
      port: 9443
```

> [!IMPORTANT]
> The Kubernetes API server runs on the host network of control-plane nodes. Its source IP as seen by pods depends on your CNI plugin. On OpenShift with OVN-Kubernetes, the API server reaches pods via the node IP. Set the `cidr` field to the CIDR of your control-plane nodes to tighten this policy. Use `oc get nodes -l node-role.kubernetes.io/master -o wide` to find the node IPs.

Apply:

```shell
oc apply -f networkpolicy/webhook-validator-policy.yaml
```

---

### Device Plugin / DRA Driver

The device plugin (`spyre-device-plugin`) and DRA driver (`dra-driver-spyre`) communicate with the kubelet exclusively through Unix-domain sockets on the host node filesystem. They do not listen on any TCP port. A deny-all ingress policy is appropriate.

See [`networkpolicy/device-plugin-policy.yaml`](networkpolicy/device-plugin-policy.yaml) and [`networkpolicy/dra-driver-policy.yaml`](networkpolicy/dra-driver-policy.yaml) for the ready-to-use files.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: device-plugin-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: spyre-device-plugin-daemonset
  policyTypes:
  - Ingress
  # No ingress rules — all TCP ingress is denied
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dra-driver-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: dra-driver-spyre
  policyTypes:
  - Ingress
  # No ingress rules — all TCP ingress is denied
```

Apply (choose the file that matches your driver mode):

```shell
# Device Plugin mode (default)
oc apply -f networkpolicy/device-plugin-policy.yaml

# DRA Driver mode (.spec.devicePlugin.mode: dra)
oc apply -f networkpolicy/dra-driver-policy.yaml
```

---

### Spyre Operator

The operator controller-manager pod (`spyre-operator`) exposes port `8443` for its metrics endpoint and leader-election mechanism, accessed only by the Kubernetes API server.

See [`networkpolicy/spyre-operator-policy.yaml`](networkpolicy/spyre-operator-policy.yaml) for the ready-to-use file.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: spyre-operator-policy
  namespace: spyre-operator
spec:
  podSelector:
    matchLabels:
      app: spyre-operator
  policyTypes:
  - Ingress
  ingress:
  # Allow the Kubernetes API server
  - from:
    - ipBlock:
        cidr: 0.0.0.0/0  # narrow this to your control-plane node CIDR
    ports:
    - protocol: TCP
      port: 8443
```

Apply:

```shell
oc apply -f networkpolicy/spyre-operator-policy.yaml
```

---

## NetworkPolicy Example Files

The [`admin-guide/networkpolicy/`](networkpolicy/) directory contains ready-to-use `NetworkPolicy` manifests. Each file targets a single component; the combined file applies all policies at once.

| File | Target component | Description |
| ---- | ---------------- | ----------- |
| [`card-management-policy.yaml`](networkpolicy/card-management-policy.yaml) | `spyre-card-management` | Allows ingress only from same-namespace pods; no TCP port is exposed. |
| [`metrics-exporter-policy.yaml`](networkpolicy/metrics-exporter-policy.yaml) | `spyre-metrics-exporter` | Allows Prometheus scraping on port `8082` from `openshift-monitoring` only. |
| [`health-checker-policy.yaml`](networkpolicy/health-checker-policy.yaml) | `spyre-health-checker` | Allows kubelet probes on `8080` and Prometheus scraping on `8081`. |
| [`webhook-validator-policy.yaml`](networkpolicy/webhook-validator-policy.yaml) | `spyre-webhook-validator` | Allows the Kubernetes API server to reach the admission webhook on port `9443`. |
| [`device-plugin-policy.yaml`](networkpolicy/device-plugin-policy.yaml) | `spyre-device-plugin` | Denies all ingress (device plugin uses Unix sockets only). |
| [`dra-driver-policy.yaml`](networkpolicy/dra-driver-policy.yaml) | `dra-driver-spyre` | Denies all ingress (DRA driver uses Unix sockets only). Use instead of `device-plugin-policy.yaml` when `mode: dra`. |
| [`spyre-operator-policy.yaml`](networkpolicy/spyre-operator-policy.yaml) | `spyre-operator` | Allows the Kubernetes API server to reach the operator metrics port `8443`. |
| [`spyre-network-policies.yaml`](networkpolicy/spyre-network-policies.yaml) | All components | Combined file — all policies above in a single manifest. |

Apply all policies at once:

```shell
oc apply -f networkpolicy/spyre-network-policies.yaml
```

> [!IMPORTANT]
> Review the `ipBlock` CIDRs in `spyre-operator-policy.yaml` and `webhook-validator-policy.yaml` before applying. The default `0.0.0.0/0` allows any source IP to reach those ports. Narrow each `cidr` to your control-plane node CIDR for a tighter policy. Run `oc get nodes -l node-role.kubernetes.io/master -o wide` to find the control-plane node IPs.

---

## Verify the Policies

After applying the policies, confirm that all Spyre components remain healthy.

1. **Check that all pods are still running:**

    ```shell
    oc get pods -n spyre-operator
    ```

    All pods should be in `Running` state with no unexpected restarts.

2. **Check the policies are in place:**

    ```shell
    oc get networkpolicies -n spyre-operator
    ```

    Expected output:

    ```text
    NAME                       POD-SELECTOR                      AGE
    card-management-policy     app=cardmgmt                      1m
    device-plugin-policy       app=spyre-device-plugin-daemonset 1m
    dra-driver-policy          app=dra-driver-spyre              1m
    health-checker-policy      app=spyre-health-checker          1m
    metrics-exporter-policy    app=spyre-metrics-exporter        1m
    spyre-operator-policy      app=spyre-operator                1m
    webhook-validator-policy   app=spyre-webhook-validator       1m
    ```

3. **Verify SpyreClusterPolicy is still ready:**

    ```shell
    oc get spyreclusterpolicy spyreclusterpolicy -o jsonpath='{.status.state}{"\n"}'
    ```

    The state should be `ready`. If it regresses to `not ready`, check pod logs for connection errors and inspect the policy that covers the failing component.

4. **Verify that the admission webhook still works** (if the webhook validator is enabled):

    ```shell
    oc apply -f - <<EOF
    apiVersion: spyre.ibm.com/v1alpha1
    kind: SpyreClusterPolicy
    metadata:
      name: spyreclusterpolicy-test
    spec: {}
    EOF
    ```

    The webhook validator should reject or accept the resource as expected. If it times out, the webhook policy is too restrictive for the API server source IP — tighten or widen the `ipBlock` CIDR in `webhook-validator-policy.yaml`.

5. **Check health checker metrics are reachable from Prometheus** (if health checker is enabled):

    ```shell
    oc exec -n openshift-monitoring -c prometheus prometheus-k8s-0 -- \
      curl -s http://spyre-health-checker.spyre-operator.svc.cluster.local:8081/metrics | head -5
    ```
