# DRA Driver Guide

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Enable the DRA driver](#enable-the-dra-driver)
- [DeviceClasses and ValidatingAdmissionPolicy](#deviceclasses-and-validatingadmissionpolicy)
- [Provide runtime image for topology generation](#provide-runtime-image-for-topology-generation)
- [DeviceClasses and device attributes](#deviceclasses-and-device-attributes)
  - [Topology tier groups](#topology-tier-groups)
- [Metrics folder](#metrics-folder)
- [Compatibility with other components](#compatibility-with-other-components)

## Overview

From version `1.3.0`, the Spyre Operator supports the **Dynamic Resource Allocation (DRA)** driver (`dra-driver-spyre`) as an alternative to the standard device plugin.

The DRA driver leverages the Kubernetes DRA API to manage Spyre device allocation and provides finer-grained control over device lifecycle and resource claims compared to the legacy device plugin approach.

> [!NOTE]
> Starting from version `1.5.0`, the DRA driver is selected with `mode: dra` under `.spec.devicePlugin` (with `mode: classic` being the default). In version `1.4.0`, this was configured using the `draDriver: true` boolean flag. The operator and webhook validator maintain backward compatibility with `draDriver: true`.

## Prerequisites

- Kubernetes / OpenShift version that supports the DRA API.
- The `dra-driver-spyre` image must be accessible from the cluster (pull secret may be required for `ghcr.io/ibm-aiu`).
- IOMMU must be enabled on the nodes (see the warning below).

> [!WARNING]
> From version `1.5.0`, the DRA driver does not advertise devices that are in a `vfio-noiommu` group (typically seen when IOMMU is disabled or the node is a VM without a virtual IOMMU), because such devices bypass IOMMU DMA isolation.
> The driver logs `skipping device <address>: ... vfio-noiommu IOMMU group ...` for each skipped device, and those devices do not appear as allocatable resources.
> Enable IOMMU (see [Operator Simple Setup Instruction](simple-instruction.md)) to make the devices available.

## Enable the DRA driver

To switch from the standard device plugin to the DRA driver, configure `.spec.devicePlugin` to use `dra-driver-spyre`.

### Version 1.5.0 and later

Set `mode: dra` under `.spec.devicePlugin`:

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  devicePlugin:
    mode: dra
    repository: "quay.io/ibm-aiu"
    image: "dra-driver-spyre"
    version: "1.5.0"
    configPath: /etc/aiu
    configName: senlib_config.json
```

A development example is available at [`spyreclusterpolicy/dev-dra.yaml`](spyreclusterpolicy/dev-dra.yaml).

### Version 1.4.0 and earlier

Set `draDriver: true` under `.spec.devicePlugin`:

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  devicePlugin:
    repository: "quay.io/ibm-aiu"
    image: "dra-driver-spyre"
    mode: dra
    version: "1.4.0"
    configPath: /etc/aiu
    configName: senlib_config.json
```

A ready-to-use example is available at [`spyreclusterpolicy/dra.yaml`](spyreclusterpolicy/dra.yaml).

> [!IMPORTANT]
> From version `1.5.0`, the boolean field `.spec.devicePlugin.draDriver` is replaced by `.spec.devicePlugin.mode` (`classic` | `dra`), and `draDriver` is no longer accepted as a value of `.spec.skipUpdateComponents`. Use `devicePlugin` to skip the synchronization of the active driver.
> Replace `draDriver: true` in your existing `SpyreClusterPolicy` with `mode: dra`.
> When `mode` is not set, the webhook validator still reads a legacy `draDriver: true` for its validation, but the operator deploys the DRA driver only when `mode: dra` is set.

> [!WARNING]
> The DRA driver is **mutually exclusive** with the secondary scheduler (`externalDeviceReservation` experimental mode).
> Do not add `externalDeviceReservation` to `.spec.experimentalMode` when DRA mode is enabled — the secondary scheduler will not be deployed and device reservation is handled natively by the Kubernetes DRA API.
>
> From version `1.5.0`, when the webhook validator is enabled, it rejects a `SpyreClusterPolicy` that sets both.

## DeviceClasses and ValidatingAdmissionPolicy

When the DRA driver is deployed, the operator creates four `DeviceClass` resources:

| DeviceClass | Description | Access |
| --- | --- | --- |
| `spyre-pf` | Physical Function (PF) devices (`productId: "06a7"`) that are healthy (`deviceState: ONLINE`) and not managed by card management. | All namespaces |
| `spyre-vf` | Virtual Function (VF) devices (`productId: "06a8"`) that are healthy (`deviceState: ONLINE`) and not managed by card management. | All namespaces |
| `spyre-managed-pf` | Physical Function (PF) devices designated for card management. | Restricted |
| `spyre-managed-vf` | Virtual Function (VF) devices designated for card management. | Restricted |

To prevent non-admin workloads from claiming devices reserved for card management, the operator deploys a `ValidatingAdmissionPolicy` (`block-restricted-device-classes`) and a `ValidatingAdmissionPolicyBinding` that deny creation and update of `ResourceClaim` and `ResourceClaimTemplate` objects requesting `spyre-managed-pf` or `spyre-managed-vf` outside the operator namespace.

## Provide runtime image for topology generation

When running against **physical devices**, the init container used by the DRA driver also requires a runtime image to interact with the hardware and generate the topology (`topo.json`), same as the standard device plugin.

> [!IMPORTANT]
> From version `1.4.0`, the runtime image must be provided via `.spec.devicePlugin.initContainer.runtime`.
> Without it, physical device discovery and topology generation will be skipped or incomplete.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  devicePlugin:
    repository: "quay.io/ibm-aiu"
    image: "dra-driver-spyre"
    mode: dra
    version: "1.4.0"
    configPath: /etc/aiu
    configName: senlib_config.json
    initContainer:
      repository: "quay.io/ibm-aiu"
      image: "spyre-device-plugin-init"
      version: "1.4.0"
      executePolicy: IfNotPresent
      runtime:
        repository: "quay.io/ibm-aiu"
        image: "spyre-runtime-ctk"
        version: "v1.3.0"
```

## DeviceClasses and device attributes

When the DRA driver is enabled (`.spec.devicePlugin.mode: dra`), the operator creates the following `DeviceClass` resources (from version `1.5.0`).

| DeviceClass | Selects | Intended users |
| ----------- | ------- | -------------- |
| `spyre-pf` | Physical functions (`productId` `06a7`) that are `ONLINE` and not managed by card management | General users |
| `spyre-vf` | Virtual functions (`productId` `06a8`) that are `ONLINE` and not managed by card management | General users |
| `spyre-managed-pf` | Physical functions managed by card management (`managed == true`) | Card management only |
| `spyre-managed-vf` | Privileged virtual functions managed by card management (`managed == true`) | Card management only |

The DRA driver publishes the following attributes on each device in the `ResourceSlice` (driver `spyre.ibm.com`) that these classes (and user `selectors`) rely on:

| Attribute | Description |
| --------- | ----------- |
| `deviceState` | Device health state reported by the Spyre health checker (e.g., `ONLINE`, `IN_ERROR`). It defaults to `ONLINE`, and only `ONLINE` devices are allocatable through `spyre-pf` / `spyre-vf`. |
| `managed` | `true` on PFs and on privileged VFs (PCI function index `1`) when card management is enabled (`.spec.cardManagement.enabled: true`). The attribute is absent otherwise. |
| `tier0Group`, `tier1Group`, `tier2Group` | Topology group IDs used for topology-aware allocation (see [Topology tier groups](#topology-tier-groups)). Present only when the topology (`topo.json`) is available. |

When card management is enabled in DRA mode, the card management Pod requests all managed PFs and managed VFs of its node through the `spyre-card-management` `ResourceClaimTemplate` (one claim with a `spyre-managed-pf` request and a `spyre-managed-vf` request, both `allocationMode: All`) instead of the `ibm.com/spyre_pf` extended resource. The default scheduler is used for it.

To prevent general users from taking the devices of card management, the operator also creates a `ValidatingAdmissionPolicy` `block-restricted-device-classes` and its binding `block-restricted-device-classes-binding`. They reject (`Deny`) the creation and update of `ResourceClaim` and `ResourceClaimTemplate` objects that request `spyre-managed-pf` or `spyre-managed-vf` in every namespace **except the operator namespace**. The error message is `The requested DeviceClass is restricted and cannot be used in this namespace.`

> [!NOTE]
> The `deviceState` attribute is updated by the health checker (`.spec.healthChecker.enabled: true`). The DRA driver connects to it through the health socket `SPYRE_HEALTH_SOCK` (`/usr/local/etc/dra-driver-spyre/spyre-sockets/health-checker.sock`) and uses the TLS certificate of the `spyre-cert` secret (mounted at `/etc/dra-driver/certs`). Without the health checker, `deviceState` stays `ONLINE`.

### Topology tier groups

The tier group attributes are the DRA equivalent of the `ibm.com/spyre_pf_tier0`, `_tier1`, and `_tier2` resources of the device plugin (`topologyAwareAllocation`). Users request devices of the same group with `matchAttribute: spyre.ibm.com/tier<N>Group` in a `ResourceClaimTemplate` (see [User Guide](../user-guide/user-guide.md#topology-aware-allocation-with-dra)).

| Attribute | Devices that share the same value |
| --------- | --------------------------------- |
| `tier0Group` | Connected through the same PCI switch (`peers_0`) |
| `tier1Group` | Reachable within one additional PCI hop (`peers_0` ∪ `peers_1`) |
| `tier2Group` | Reachable within two additional PCI hops (`peers_0` ∪ `peers_1` ∪ `peers_2`) |

- The driver computes the groups from the peer information in the topology file (`topo.json`) as connected components of the peer graph, and the value is the lowest PCI address in the group. It handles both PFs and VFs (VF groups are computed from the VF peers).
- The groups are published only when the topology is available. If no topology is provided or generated, the three attributes are absent and a claim using `matchAttribute` on them cannot be satisfied. Provide the topology as described in [Provide runtime image for topology generation](#provide-runtime-image-for-topology-generation) (or see [`dra-with-topology.yaml`](spyreclusterpolicy/dra-with-topology.yaml)).
- These attributes do not require the secondary scheduler or the `topologyAwareAllocation` experimental mode, which are not used with the DRA driver.

To check the groups published on a node:

```shell
kubectl get resourceslices -o yaml | grep -E "tier[012]Group" -A1
```

## Metrics folder

The DRA driver mounts the same metrics folder as the device plugin. See [Metrics folder mount](metrics-exporter-guide.md#metrics-folder-mount).

## Compatibility with other components

The table below summarises which Spyre Operator components are compatible with the DRA driver and from which version.

| Component | Status | Since |
| --------- | ------ | ----- |
| PF allocation, NUMA alignment, specific device selection | ✅ Supported | `1.3.0` |
| Tier allocation | ✅ Supported | `1.5.0` |
| VF with operator-controlled device class | ✅ Supported | `1.4.0` |
| Admission Webhook (`spyre-webhook-validator`) | ✅ Supported | `1.4.0` |
| Metrics Exporter (`spyre-metrics-exporter`) | ✅ Supported | `1.5.0` |
| Health Checker (`spyre-health-checker`) | ✅ Supported (`deviceState` attribute) | `1.5.0` |
| Card Management (`spyre-card-management`) | ✅ Supported (managed device classes) | `1.5.0` |

> [!NOTE]
> Features listed without a "Since" version were available from the initial DRA driver release.
