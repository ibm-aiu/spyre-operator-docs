# SpyreClusterPolicy Customization Guide

## Table of Contents <!-- omit in toc -->

- [Overview](#overview)
- [Enable/Disable optional components](#enabledisable-optional-components)
- [Configure image](#configure-image)
- [Configure other deployment condition](#configure-other-deployment-condition)
- [Configure experimental modes](#configure-experimental-modes)
- [Manual component configuration](#manual-component-configuration)
- [Configure Log Level](#configure-log-level)

## Overview

After operator installation, we will need to create `SpyreClusterPolicy` to complete the whole setup.

SpyreClusterPolicy is a custom resource where an Admin can define cluster-wide configuration of the Spyre Operator and its controlled component such as device plugin, scheduler, card management, metrics exporter, and webhook validator.

| Controlled Component | Config API              | Optional     | Functionality                                                                                                                                                                                                                                                                                            |
| -------------------- | ----------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Device Plugin        | `.spec.devicePlugin`    | No           | - Discover devices and update SpyreNodeState<br/>- Generate topology file (/etc/aiu/topo.json) if not provided<br/>- Generate config for allocated devices (/etc/aiu/senlib_config.json)<br/>- Prepare Pod's config (/etc/aiu) and metrics folder (/data)<br/>- Generate pod information in /data folder |
| Secondary Scheduler  | `.spec.scheduler`       | :warning:Yes | - Schedule node to a pod considering also `perDeviceAllocation` and `topologyAwareAllocation` (check [experimental modes](#configure-experimental-modes) for more details)                                                                                                                               |
| Card Management      | `.spec.cardManagement`  | :warning:Yes | - Enable **VF** for DD2 architecture                                                                                                                                                                                                                                                                     |
| Metrics Exporter     | `.spec.metricsExporter` | Yes          | - Export device data, device allocation status, and sentientmap metrics to Prometheus                                                                                                                                                                                                                    |
| Webhook Validator    | `.spec.podValidator`    | Yes          | - Validate user pod creation and SpyreClusterPolicy creation to prevent incorrect functionality of operator.                                                                                                                                                                                             |

> :warning:
>
> - **Secondary Scheduler** is required if any of `perDeviceAllocation` or `topologyAwareAllocation` experimental modes is enabled.
> - **Card Management** is required for using virtual functions.

A sample of SpyreClusterPolicy is on the dashboard as below. For optional components, the sample SpyreClusterPolicy has only webhook validator and secondary scheduler enabled with per-device allocation and topology-aware allocation experimental modes.

> [!IMPORTANT]
> To use virtual functions in DD2 architecture, the card management component must be also enabled. Please check [enable/disable optional components](#enabledisable-optional-components) and [configure card management](#configure-card-management) for more details.

> [!NOTE]
> Admin can configure log level, controlled components, and experimental modes via the SpyreClusterPolicy as elaborated below.

To customize behavior of each component, please check per-component documentation to customeize component behavior.

- [Device Plugin](device-plugin-guide.md)
- [Metrics Exporter](metrics-exporter-guide.md)

The rest of this documentation describes how to customize operator-wide behavior.

## Enable/Disable optional components

**Secondary Scheduler**, **Card Management**, **Metrics Exporter**, and **Webhook Validator** are disabled by default.

To enable **Secondary Scheduler**, `externalDeviceReservation` must be added to `.spec.experimentalMode`. Please find more detail in [experimental modes](#configure-experimental-modes).

To enable or disable **Card Management**, **Metrics Exporter**, and **Webhook Validator**, use `enabled` field of that component.

It is recommended to enable the webhook validator to prevent incorrect functionality of the operator.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
spec:
  cardManagement:
    enabled: true|false
  ...
  metricsExporter:
    enabled: true|false
  ...
  podValidator:
    enabled: true|false
```

>[!IMPORTANT]
> Please review the below section for [Component-specific Prerequisites](#component-specific-prerequisites) before enabling the component.

## Configure image

All controlled components can configure `repository`, `image`, and `version`.

```yaml
spec:
  [component]:
    repository:
    image:
    version:
```

`image` is required value. The composed image name is `repository/image:version` if specified.

## Configure other deployment condition

All deployment except scheduler allow the configuration of `imagePullPolicy`, `imagePullSecrets`, `env`, `args`, `resources`, and `nodeSelector`.

## Configure experimental modes

"Experimental Mode" can be configured in the `SpyreClusterPolicy` resource. The following mode can be specified.

- `perDeviceAllocation`: enable per-device allocation mode. In a plain mode, the Spyre Device Plugin allocates an arbitrary card to a Pod. If this mode is enabled, users can specify certain Spyre card by its PCI address. Please see [Deploy your Pod with a specific Spyre card](../) section for details.
- `pseudoDevice`: enable pseudo device mode for testing the operator without physical Spyre devices. This mode will be propagated to the device plugin components to simulate a pseudo device topology which contains 8 pseudo physical devices on every nodes in the cluster. Each pseudo physical devices will contain 2s pseudo virtual functions (VFs).
- `topologyAwareAllocation`: enable topology-aware allocation mode. In this mode, user can specify `ibm.com/spyre_pf_tier0` to tell the Spyre device plugin to assign tier-0 Spyre cards so that application containers can use RDMA.
- `externalDeviceReservation`: enable external device reservation to improve the robustness of device allocation and de-allocation.
- `disableVirtualFunction`: do not create resource pools for virtual functions (VFs) regardless of its availability (i.e., no spyre_vf available).

To configure the experimental mode, add the mode key (e.g., `perDeviceAllocation`) to `.spec.experimentalMode`.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
spec:
  experimentalMode:
  - perDeviceAllocation
  - pseudoDevice
  ...
```

## Manual component configuration

All operator-owned components will be synchronized based on SpyreClusterPolicy by default. All changes made to the resource such as DaemonSet, Deployment are going to be reverted automatically. However, admin can skip the synchronization at own risk by adding the target component in the "skipUpdateComponents" field.

Available components are `commonInit`, `devicePlugin`, `cardManagement`, `metricsExporter`, `scheduler`, `podValidator`, `healthChecker`.

For example,

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
spec:
  skipUpdateComponents:
  - cardManagement
```

With the above configuration, Admin can edit any objects in the card management component which is owned by the operator. Please note that, any configuration made to `.spec.cardManagement` would also not reflect after this change.

## Configure Log Level

Default loglevel is `info`. Available levels are `debug`, `info`, and `error`.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
spec:
  loglevel: debug
```
