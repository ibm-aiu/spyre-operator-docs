# Health Checker Guide

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Verify the installation](#verify-the-installation)
- [Configure](#configure)
  - [Choose reporters](#choose-reporters)
  - [Change the check interval](#change-the-check-interval)
  - [Restrict the RAS watcher to trusted namespaces](#restrict-the-ras-watcher-to-trusted-namespaces)
  - [Schedule on specific nodes and set resources](#schedule-on-specific-nodes-and-set-resources)
- [Use the health checker](#use-the-health-checker)
  - [Device states](#device-states)
  - [Check device health from the cluster](#check-device-health-from-the-cluster)
  - [Query Prometheus metrics](#query-prometheus-metrics)
  - [Recover a device in error](#recover-a-device-in-error)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

## Overview

The Spyre Health Checker (`spyre-health-checker`) runs as a DaemonSet on every node that has Spyre cards.
It periodically checks the health of each Spyre device and reports changes to the Spyre Device Plugin, which then tells Kubernetes which devices are healthy or unhealthy.
Unhealthy devices are no longer offered to new pods.

Each check combines the results of several *reporters*:

| Reporter | Enabled by | What it checks |
| --- | --- | --- |
| `lspci` | `enabledReporters` (default) | PCI state of each Spyre device, as seen by `lspci` on the node. |
| `cardmgmt` | `enabledReporters` (default) | Health reported by the card management health API sidecar (`spec.cardManagement.healthApi`). |
| RAS watcher | Always on | Hardware (RAS) errors found in the logs of failed or crash-looping Spyre workload pods on the node. |

After the reporters run, the health checker also verifies that each device is still bound to its kernel driver. A device that has lost its driver binding is reported as in error.

> [!NOTE]
> Once any check marks a device as in error, the device stays in error until the health checker pod on that node restarts. See [Recover a device in error](#recover-a-device-in-error).

## Prerequisites

- A cluster with Spyre cards and the Spyre Operator installed (see [Simple Setup Instruction](simple-instruction.md)).
- A `SpyreClusterPolicy` that deploys the Spyre Device Plugin. The common init resources the operator creates, including the `spyre-cert` secret the health checker uses for mutual TLS, are issued through cert-manager, so cert-manager must be installed.
- To use the `cardmgmt` reporter (the default), card management must be enabled with the health API sidecar. See [Enable the cardmgmt reporter](#choose-reporters).
- Optional: the Prometheus Operator, to scrape health checker metrics through the `ServiceMonitor` the operator creates.

The health checker pods run only on nodes labeled `ibm.com/spyre.present=true` and tolerate the `ibm.com/spyre:NoSchedule` taint.

## Install

The health checker is installed by the operator. It is disabled by default. To install it, set `spec.healthChecker.enabled` to `true` in your `SpyreClusterPolicy`.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  healthChecker:
    enabled: true
    repository: "quay.io/ibm-aiu"
    image: "spyre-health-checker"
    version: 1.4.0
```

Apply the change:

```shell
oc apply -f spyreclusterpolicy.yaml
```

The sample policies [`full-spyre-pf.yaml`](spyreclusterpolicy/full-spyre-pf.yaml) and [`full-spyre-vf.yaml`](spyreclusterpolicy/full-spyre-vf.yaml) already enable the health checker.
See [SpyreClusterPolicy Customization](cluster-policy-customization-guide.md) for details.

The operator creates the following resources in its namespace:

| Resource | Name | Purpose |
| --- | --- | --- |
| `DaemonSet` | `spyre-health-checker` | One health checker pod per Spyre node. |
| `ServiceAccount`, `ClusterRole`, `ClusterRoleBinding` | `spyre-health-checker` | Lets the RAS watcher read pods and pod logs on its node. |
| `Service` | `spyre-health-checker` | Exposes the Prometheus metrics port (`8081`). |
| `ServiceMonitor` | `spyre-health-checker` | Tells the Prometheus Operator to scrape the metrics every 30 seconds. |

When the health checker is enabled, the Spyre Device Plugin connects to it automatically through a socket shared on the node. No extra configuration is needed. If the health checker is disabled or unreachable, the device plugin falls back to its own PCI-based health monitoring.

## Verify the installation

1. Confirm that the DaemonSet is ready on every Spyre node. Replace `<operator-namespace>` with the namespace where the Spyre Operator runs.

    ```shell
    oc get daemonset spyre-health-checker -n <operator-namespace>
    ```

    `DESIRED`, `READY`, and `AVAILABLE` should all match the number of Spyre nodes.

2. Check the logs of one pod.

    ```shell
    oc logs -n <operator-namespace> -l app=spyre-health-checker --tail=50
    ```

3. Confirm that the pod is serving its probes. Each pod listens on port `8080` for `/healthz` and `/readyz`.

    ```shell
    oc get pods -n <operator-namespace> -l app=spyre-health-checker
    ```

4. Confirm that the device plugin sees your devices as healthy. See [Check device health from the cluster](#check-device-health-from-the-cluster).

## Configure

All settings are in `spec.healthChecker` of the `SpyreClusterPolicy`. The operator rolls out the change to the DaemonSet after you apply the policy.

### Choose reporters

`enabledReporters` is a comma-separated list. The default is `lspci,cardmgmt`.

| Value | Behavior |
| --- | --- |
| `lspci,cardmgmt` | **Default.** Uses both reporters. Requires the card management health API sidecar. |
| `lspci` | Uses PCI checks only. Use this when card management is not deployed. |

The RAS watcher is always on and does not need to be listed.

To use `cardmgmt`, enable the health API sidecar in card management:

```yaml
spec:
  cardManagement:
    enabled: true
    healthApi:
      enabled: true
      repository: "quay.io/ibm-aiu"
      image: "spyre-cardmgmt-health-api"
      version: "1.4.0"
  healthChecker:
    enabled: true
    enabledReporters: "lspci,cardmgmt"
```

To turn the `cardmgmt` reporter off:

```yaml
spec:
  healthChecker:
    enabled: true
    enabledReporters: "lspci"
```

> [!WARNING]
> If `cardmgmt` is listed in `enabledReporters` but the card management health API sidecar is not running, the `cardmgmt` reporter cannot reach it. The `lspci` reporter and the RAS watcher keep working, but you will not get card management health information. Either enable the sidecar or set `enabledReporters: "lspci"`.

### Change the check interval

The health checker runs a check every `30s` by default. Change it with the `CHECK_INTERVAL` environment variable. The value uses duration format, such as `10s` or `5m`.

```yaml
spec:
  healthChecker:
    enabled: true
    env:
    - name: CHECK_INTERVAL
      value: "1m"
```

### Restrict the RAS watcher to trusted namespaces

By default, the RAS watcher looks at Spyre workload pods in every namespace. In a multi-tenant cluster, a user in any namespace could print log lines that look like a RAS error and cause a healthy device on the node to be marked as in error.

To prevent this, limit the RAS watcher to the namespaces where trusted Spyre workloads run, with `--ras-watcher-limit-namespaces`.

> [!IMPORTANT]
> Setting `spec.healthChecker.args` **replaces** the whole argument list of the health checker container, including the arguments the operator sets by default. When you set `args`, include every argument you need: `--timer`, `--socket`, and `--enabled-reporters`. Use the same values the DaemonSet uses today. Check them first with `oc get daemonset spyre-health-checker -n <operator-namespace> -o jsonpath='{.spec.template.spec.containers[0].args}'`.

```yaml
spec:
  healthChecker:
    enabled: true
    args:
    - --timer
    - $(CHECK_INTERVAL)
    - --socket
    - $(SPYRE_HEALTH_SOCK)
    - --enabled-reporters
    - lspci,cardmgmt
    - --ras-watcher-limit-namespaces
    - team-a-spyre,team-b-spyre
```

### Schedule on specific nodes and set resources

The health checker accepts the standard deployment settings shared by other Spyre components:

```yaml
spec:
  healthChecker:
    enabled: true
    nodeSelector:
      ibm.com/spyre.present: "true"
    imagePullPolicy: IfNotPresent
    imagePullSecrets:
    - my-registry-secret
    resources:
      requests:
        cpu: 100m
        memory: 32Mi
      limits:
        cpu: 500m
        memory: 500Mi
```

By default, each pod requests `100m` CPU and `10Mi` memory, with limits of `500m` CPU and `500Mi` memory.

## Use the health checker

Once installed, the health checker works without further action. You use it to find out which devices are healthy and why a device was removed from scheduling.

### Device states

| State | Meaning |
| --- | --- |
| `ONLINE` | The device passed all checks. |
| `IN_ERROR` | At least one check failed. The device is reported as unhealthy and is not given to new pods. |

A device is reported as `IN_ERROR` when any of the following is true:

- `lspci` reports a revision of `ff` for the device.
- The card management health API reports the device as unhealthy.
- A Spyre workload pod that used the device failed or is crash-looping, and its logs contain a RAS error.
- The device is visible on the PCI bus but is no longer bound to its kernel driver.

### Check device health from the cluster

The `SpyreNodeState` resource for each node lists every Spyre device with its health. See also [Daily Operation Guide](daily-operation-guide.md).

```shell
oc get spyrenodestate <node-name> -o yaml
```

```yaml
spec:
  spyreInterfaces:
  - health: healthy
    pciAddress: 0000:ac:00.0
  - health: unhealthy
    pciAddress: 0000:ad:00.0
```

An unhealthy device is also removed from the node's allocatable Spyre resources. Check with:

```shell
oc describe node <node-name> | grep -i spyre
```

### Query Prometheus metrics

The health checker exposes the metric `spyre_device_state` on port `8081`. There is one series for each device, with value `1` for the device's current state.

| Label | Description |
| --- | --- |
| `node` | Node name. |
| `pci_address` | PCI address of the device. |
| `devicetype` | `PF` or `VF`. |
| `state` | Device state, for example `ONLINE` or `IN_ERROR`. |
| `source` | The reporter that decided the state. Use this to see why a device is in error. |

Useful queries:

```promql
# All devices currently in error
spyre_device_state{state="IN_ERROR"} == 1

# Device counts per node and state
sum by (node, state, devicetype) (spyre_device_state)
```

On OpenShift, the Spyre dashboard has a **Spyre Device State** row that shows these counts per node.

If your Prometheus does not use the Prometheus Operator, scrape the `spyre-health-checker` Service on port `8081` (`/metrics`) directly.

### Recover a device in error

The health checker never clears an error automatically. This is on purpose: a hardware error should be looked at before the device is used again.

1. Find the failed device and the reporter that flagged it, using the `source` label of `spyre_device_state` or the health checker logs.

    ```shell
    oc logs -n <operator-namespace> <health-checker-pod-name>
    ```

2. Investigate and fix the cause. For a RAS error, look at the logs of the failed workload pod. For a driver or card management problem, check the node and the [card management](cardmgmt-guide.md) pod.

3. Remove the failed workload pod that triggered the error, if it still exists. The RAS watcher reads its logs again after a restart and would mark the device in error again.

    ```shell
    oc delete pod <failed-pod> -n <workload-namespace>
    ```

4. Restart the health checker pod on that node to clear the error state.

    ```shell
    oc delete pod <health-checker-pod-name> -n <operator-namespace>
    ```

    The DaemonSet recreates the pod and the device is checked again from a clean state. If the problem remains, the device is reported in error again.

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| No `spyre-health-checker` pods | `spec.healthChecker.enabled` is `false`, or the node is missing the `ibm.com/spyre.present=true` label. | Enable the health checker. Check node labels with `oc get nodes -l ibm.com/spyre.present=true`. |
| Pod is not ready or restarts | The TLS secret `spyre-cert` is missing or cert-manager is not issuing it. | `oc get secret spyre-cert -n <operator-namespace>` and check cert-manager. The health checker cannot start without valid certificates. |
| Log shows `failed to load TLS credentials` | Certificate files cannot be read. | Same as above. Make sure the secret holds `tls.crt`, `tls.key`, and `ca.crt`. |
| Clients get `Unauthenticated` errors | The client certificate has an empty Organization (`O=`) field. | Re-issue the certificate with a non-empty Organization. Certificates issued by the operator already satisfy this. |
| `cardmgmt` reporter errors in the log, such as `cardhealth: ...` or `Unavailable` | The card management health API sidecar is not running, or its certificate does not match. | Enable `spec.cardManagement.healthApi`, or set `enabledReporters: "lspci"`. |
| Log warns that the RAS watcher is disabled, with a `403 Forbidden` | The `spyre-health-checker` ClusterRole or ClusterRoleBinding is missing. | Check `oc get clusterrole,clusterrolebinding spyre-health-checker`. The operator recreates these when it reconciles. |
| Healthy device suddenly shows `IN_ERROR` | A failed or crash-looping workload pod logged a RAS error, or the driver binding was lost. | Check the `source` label of the metric and the logs. See [Recover a device in error](#recover-a-device-in-error). |
| Device stays `IN_ERROR` after the problem is fixed | Errors are not cleared automatically. | Restart the health checker pod on that node. |
| Devices of tenant workloads flagged as in error without a real fault | The RAS watcher trusts logs from every namespace. | Restrict it with `--ras-watcher-limit-namespaces`. See [above](#restrict-the-ras-watcher-to-trusted-namespaces). |
| No metrics in Prometheus | The Prometheus Operator is not installed or does not select the `ServiceMonitor`. | Check that `servicemonitor spyre-health-checker` exists and matches your Prometheus selector. |

## Reference

- [SpyreClusterPolicy Customization](cluster-policy-customization-guide.md)
- [Card Management](cardmgmt-guide.md)
- [Device Plugin](device-plugin-guide.md)
- [Daily Operation Guide](daily-operation-guide.md)
- [v1.4.0 release notes](../release-notes/v1.4.0.md), which introduce the reporter framework
- Source repository: `spyre-health-checker`, including its `docs/` (reporters, TLS, configuration) for developer-level detail
