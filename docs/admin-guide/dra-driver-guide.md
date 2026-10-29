# DRA Driver Guide

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Enable the DRA driver](#enable-the-dra-driver)
- [DeviceClasses and ValidatingAdmissionPolicy](#deviceclasses-and-validatingadmissionpolicy)
- [Provide runtime image for topology generation](#provide-runtime-image-for-topology-generation)
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
    draDriver: true
    version: "1.4.0"
    configPath: /etc/aiu
    configName: senlib_config.json
```

A ready-to-use example is available at [`spyreclusterpolicy/dra.yaml`](spyreclusterpolicy/dra.yaml).

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
    draDriver: true
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

## Compatibility with other components

The table below summarises which Spyre Operator components are compatible with the DRA driver and from which version.

| Component | Status | Since |
| --------- | ------ | ----- |
| PF allocation, NUMA alignment, specific device selection | ✅ Supported | `1.3.0` |
| VF with operator-controlled device class | ✅ Supported | `1.4.0` |
| Admission Webhook (`spyre-webhook-validator`) | ✅ Supported | `1.4.0` |
| Metrics Exporter (`spyre-metrics-exporter`) | ✅ Compatible | `1.3.0` |
| Health Checker (`spyre-health-checker`) | ✅ Supported | `1.5.0` |
| Card Management (`spyre-card-management`) | ✅ Supported | `1.5.0` |

> [!NOTE]
> Features listed without a "Since" version were available from the initial DRA driver release.
