# DRA Driver Guide

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Enable the DRA driver](#enable-the-dra-driver)
- [Provide runtime image for topology generation](#provide-runtime-image-for-topology-generation)
- [Compatibility with other components](#compatibility-with-other-components)

## Overview

From version `1.3.0`, the Spyre Operator supports the **Dynamic Resource Allocation (DRA)** driver (`dra-driver-spyre`) as an alternative to the standard device plugin.

The DRA driver leverages the Kubernetes DRA API to manage Spyre device allocation and provides finer-grained control over device lifecycle and resource claims compared to the legacy device plugin approach.

> [!NOTE]
> The DRA driver is configured through the same `.spec.devicePlugin` section of `SpyreClusterPolicy` as the standard device plugin, with the addition of the `draDriver: true` flag.

## Prerequisites

- Kubernetes / OpenShift version that supports the DRA API.
- The `dra-driver-spyre` image must be accessible from the cluster (pull secret may be required for `ghcr.io/ibm-aiu`).

## Enable the DRA driver

To switch from the standard device plugin to the DRA driver, set `draDriver: true` under `.spec.devicePlugin` and point the `image` field to `dra-driver-spyre`.

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
> Do not add `externalDeviceReservation` to `.spec.experimentalMode` when `draDriver: true` is set — the secondary scheduler will not be deployed and device reservation is handled natively by the Kubernetes DRA API.

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
| Health Checker (`spyre-health-checker`) | 🗓 Planned | `1.5.0` |

> [!NOTE]
> Features listed without a "Since" version were available from the initial DRA driver release.
