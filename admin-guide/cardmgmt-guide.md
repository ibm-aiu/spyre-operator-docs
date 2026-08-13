# Cluster Admin Guide for Spyre Card-Management

this documentation describes how to use VF (`spyre_vf`) devices using Spyre Card-Management.

## Table of Contents <!-- omit in toc -->

- [Cluster Admin Guide for Spyre Card-Management](#cluster-admin-guide-for-spyre-card-management)
  - [1. Enable VF devices using Spyre Card-Management](#1-enable-vf-devices-using-spyre-card-management)
    - [1.1 Configure Node](#11-configure-node)
    - [1.2 Configure Image Pull Secret](#12-configure-image-pull-secret)
    - [1.3 Configure SpyreClusterPolicy](#13-configure-spyreclusterpolicy)
  - [2. Troubleshooting Guide for VF enablement](#2-troubleshooting-guide-for-vf-enablement)
    - [2.1 `spyre-card-management-xxx` Pod does not start on a target node](#21-spyre-card-management-xxx-pod-does-not-start-on-a-target-node)
    - [2.2 `spyre-card-management-xxx` Pod remains `Pending`](#22-spyre-card-management-xxx-pod-remains-pending)
    - [2.3 `spyre-card-management-xxx` Pod goes into `Error` state](#23-spyre-card-management-xxx-pod-goes-into-error-state)

## 1. Enable VF devices using Spyre Card-Management

### 1.1 Configure Node

We assume you have already setup an OpenShift cluster. To configure Linux (CoreOS) worker nodes in OpenShift, using Machine Config Operator (MCO) is an only pathway to configure the node.
The following MachineConfigs are required to apply in order to customize the worker nodes to run Spyre workloads.
If you are not familiar with MachineConfig and MachineConfigPool, please check out [the official guide](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/machine_configuration/machine-config-index) first.

The following MachineConfigs must be applied before installing the Spyre Operator:

> [!IMPORTANT]
> The SELinux policy MachineConfig must be applied before installing the Spyre Operator. It configures SELinux policies and directory permissions needed for the device plugin to run as a non-root user.

1. **SELinux Policy** (required for all architectures): Apply https://github.com/ibm-aiu/spyre-operator/blob/main/config/machineconfig/amd64/50-spyre-device-plugin-selinux-minimal.yaml to enable the device plugin to run as a non-root user.

   ```bash
   oc apply -f config/machineconfig/50-spyre-device-plugin-selinux-minimal.yaml
   ```

2. **Architecture-specific MachineConfigs**: For amd64 (x86_64) architecture, the following MachineConfigs are stored in https://github.com/ibm-aiu/spyre-operator/tree/main/config/machineconfig/amd64 directory:

```yaml
config/machineconfig/amd64
├── 05-aiu-kernel-commandline.yaml
├── 08-pciacs-v1.yaml
├── 09-vfstart.yaml
└── mcp-vf.yaml
```

This is a summary table for each file.

| file name                                   | type              | description                                                                        | mcp target | required          |
| ------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------- | ---------- | ----------------- |
| 50-spyre-device-plugin-selinux-minimal.yaml | MachineConfig     | configure SELinux policy and permissions for device plugin to run as non-root user | worker     | PF mode / VF mode |
| 05-aiu-kernel-commandline.yaml              | MachineConfig     | add vfio-pci config and iommu enablement kernel parameter                          | worker     | PF mode / VF mode |
| 08-pciacs-v1.yaml                           | MachineConfig     | configure PCI ACS (Access Control Service) for Spyre                               | worker     | PF mode / VF mode |
| 09-vfstart.yaml                             | MachineConfig     | add two Virtual Function (VF) to every cards                                       | vf         | VF mode           |
| mcp-vf.yaml                                 | MachineConfigPool | create another mcp to separate vf worker nodes                                     | -          | VF mode           |

`50-spyre-device-plugin-selinux-minimal.yaml`, `aiu-kernel-commandline`, and `pciacs` are all required in any mode (PF mode and VF mode), so you need to apply these three machine configs in any cases.
`vf-start` is needed when cluster admin wants to enable VF to some worker nodes. `mcp-vf.yaml` is an optional MachineConfigPool if we want to manage PF-only workers and VF-enabled workers separately.

For example, cluster admin may want to create VFs in worker-1 only, at the same time, they want to keep worker-2 and worker-3 as PF-only.
In this case, you need to follow these steps.

- apply 09-vfstart.yaml to add a new machineConfig
- apply mcp-vf.yaml to create a new machineConfigPool
- add `vf` role label to the worker-1 by `oc label node worker-1 node-role.kubernetes.io/vf=`


If everything works fine, your worker node and mcp status looks like that;

```yaml
$ oc get nodes
NAME           STATUS   ROLES                         AGE   VERSION
controller-1   Ready    control-plane,master,worker   1d    v1.29.9+5865c5b
controller-2   Ready    control-plane,master,worker   1d    v1.29.9+5865c5b
controller-3   Ready    control-plane,master,worker   1d    v1.29.9+5865c5b
worker-1       Ready    vf,worker                     1d    v1.29.9+5865c5b
worker-2       Ready    worker                        1d    v1.29.9+5865c5b
worker-3       Ready    worker                        1d    v1.29.9+5865c5b
```

```yaml
$ oc get mcp
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-f4763e47054f8338ffbb2faa7b3dc9d4   True      False      False      3              3                   3                     0                      1d
vf       rendered-vf-dd420b3782950fb2a5d4ce9c626352d5       True      False      False      1              1                   1                     0                      1d
worker   rendered-worker-37e8ad024f77be936e01bda003b8b3d6   True      False      False      2              2                   2                     0                      1d
```

After that, all Spyre cards in the worker-1 will have two VFs for each.

> [!NOTE]
> This operation is a first step to make VF devices allocatable in the OpenShift.
> To run VF workloads with VF devices, we need to also configure the runtime & driver parameter and
> initialize the Spyre card for being VF mode through other components like card mgmt.

### 1.2 Configure Image Pull Secret

Spyre Card-Management v1.2.3 or later requires a `Secret` resource containing image pull policy for its PF/VF Runner containers.

```shell
REGISTRY=icr.io
REGISTRY_USERNAME=iamapikey
REGISTRY_TOKEN=rjXspkpXXXXXXXXX  # <-- specify your IAM API key.
oc registry login --registry="$REGISTRY" --auth-basic="$REGISTRY_USERNAME:$REGISTRY_TOKEN" --to=/tmp/auth.json
oc -n spyre-operator create secret generic registry-dockerconfig-secret --from-file=.dockerconfigjson=/tmp/auth.json --type=kubernetes.io/dockerconfigjson
```

### 1.3 Configure SpyreClusterPolicy

There are three important configurations in `SpyreClusterPolicy`.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
spec:
  experimentalMode:
    - perDeviceAllocation
    - topologyAwareAllocation
    - externalDeviceReservation
  cardManagement:
    enabled: true
    repository: icr.io/ibmaiu_internal/1.0/x86_64/release
    image: aiucardmgmt
    version: v1.2.5
    config:
      spyreFilter: .
      pfRunnerImage: icr.io/ibmaiu_internal/1.0/x86_64/spyredriver:v1.2.0
      vfRunnerImage: icr.io/ibmaiu_internal/1.0/x86_64/spyredriver:v1.2.0
  scheduler:
    image: spyre-scheduler
    repository: quay.io/ibm-aiu
    version: 1.3.0
```

1. enable required experimental modes: `perDeviceAllocation`, `topologyAwareAllocation`, `externalDeviceReservation`
2. configure `cardManagement` element
3. enable `scheduler`

## 2. Troubleshooting Guide for VF enablement

### 2.1 `spyre-card-management-xxx` Pod does not start on a target node

- run `oc get node node_name -o yaml` and check the number of `spyre_vf` under `allocatable` and `capacity` elements
  - if either of the numbers is `0`, then restart the device plugin Pod on the node by `oc delete pod spyre-device-plugin-xxx`
- run `oc logs spyre-operator-xxx` and check error message regarding card-management
  - if you find a node-not-found error (e.g., `failed to label node worker-50: failed to get node worker-50: Node \"worker-50\" not found`), restart the operator Pod (`oc delete pod spyre-operator-xxx`)
- run `oc get spyrepol spyreclusterpolicy -o yaml | yq '.spec.cardManagement.spyreFilter`
  - check the filter appropriately specifies target node (if you reuse `SpyreClusterPolicy`, `spyreFilter` may contain non-existent nodes)

### 2.2 `spyre-card-management-xxx` Pod remains `Pending`

- run `oc describe pod spyre-card-management-xxx`
  - if image pull error happens, check image pull secret - you may need to create a `Secret` as described in [Configure Image Pull Secret section](#13-configure-image-pull-secret)
- run `oc -n openshift-secondary-scheduler-operator get pod`
  - if no secondary scheduler Pod is running, check scheduler configuration by `oc get spyrepol spyreclusterpolicy -o yaml`
- run `oc logs spyre-operator-xxx`
  - if there is some `ERROR` log message, check `SpyreClusterPolicy` by `oc get spyrepol spyreclusterpolicy -o yaml`
- run `oc version` and run `oc -n openshift-secondary-scheduler-operator logs secondary-scheduler-xxx`
  - if OpenShift server is 4.20 or before, and the secondary scheduler log contains error about `resource.k8s.io` API, then change the version of scheduler to `1.2.0` in `SpyreClusterPolicy`

    ```yaml
      scheduler:
        image: spyre-scheduler
        repository: quay.io/ibm-aiu
        version: 1.2.0  # <--- change the version
    ```

### 2.3 `spyre-card-management-xxx` Pod goes into `Error` state

- run `oc logs spyre-card-management-xxx`
  - if log contains some error, check `pfRunnerImage` and `vfRunnerImage` are valid by `oc get spyrepol spyreclusterpolicy`
  - also, please consider restarting a node (`oc debug node/node_name` and then `chroot /host` and `shutdown -r now` inside of the node)
