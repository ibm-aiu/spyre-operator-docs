# Operator Simple Setup Instruction

This document describes simple steps to setup IBM AIU Spyre Operator using Red Hat Certified Operator Catalog in OpenShift 4.21.

## 1. BIOS/Linux Setup

> [!IMPORTANT]
> The SELinux policy MachineConfig must be applied before installing the Spyre Operator. It configures SELinux policies and directory permissions needed for the device plugin to run as a non-root user.

1. enable SR-IOV and IOMMU in BIOS (UEFI) setting

2. apply `MachineConfig` (see [Machine Configuration Files](https://github.com/ibm-aiu/spyre-operator/tree/main/config/machineconfig) and [Red Hat Machine Configuration Overview](
https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/machine_configuration/machine-config-index) for details)
)
   - For amd64:

      ```bash
      WORK_DIR=$(mktemp -d)
      git clone --depth=1 https://github.com/ibm-aiu/spyre-operator.git "$WORK_DIR"
      oc apply -f "$WORK_DIR/config/machineconfig/amd64/"
      ```

> [!IMPORTANT]
> The SELinux policy MachineConfig must be applied before installing the Spyre Operator. It configures SELinux policies and directory permissions needed for the device plugin to run as a non-root user.

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

## 2. Dependent Operators Setup

Setup required Operators - they can be installed through the left-hand side menu of OpenShift web console.

- OpenShift 4.20 or later: `Ecosystem > Software Catalog`
- OpenShift 4.19 or earlier: `Operators > OperatorHub`

In this menu, please follow the steps below.

 1. install openshift-cert-manager-operator
 2. install openshift-nfd-operator
 3. create `NodeFeatureDiscovery` resource at `Ecosystem > Installed Operators > Node Feature Discovery Operator`
 4. install openshift-secondary-scheduler-operator

## 3. Spyre Operator Setup

1. Move to  `Ecosystem > Software Catalog` or `Operators > OperatorHub`,
2. Click `Project: xxx` or  `Installed Namespace` pull-down menu and select `Create Project` in the pull-down menu
3. Type `spyre-operator` in `Name` box and push `Create` button
4. Search Spyre Operator at and click `IBM Spyre Operator` and click it
5. Push `Install` button to move `Install Operator` dialog, and then push `Install` button again in the bottom of the dialog
6. Wait for `Operator installed successfully` or  `ready for use` dialog and click `View Operator` button
7. Click `Spyre Cluster Policy` tab, and then click `Create SpyreClusterPolicy` button at the right-most position of the tab contents with default values
8. Scroll down and click `Create` button **without altering default resource name** `spyreclusterpolicy`.
9. Confirm the creation of `SpyreClusterPolicy` resource

If the SpyreClusterPolicy is deployed correctly, the core and enabled optional controlled components should be deployed and `SpyreNodeState` resource should be created for each node.

```shell
$ oc -n spyre-operator get pod
NAME                                   READY   STATUS             RESTARTS   AGE
spyre-card-management-58484758f7-xqhj9   1/1     Running            0
spyre-device-plugin-cww7d                1/1     Running            0
spyre-device-plugin-zt7v6                1/1     Running            0
spyre-operator-dd45f4cb-lgglt            2/2     Running            0
```

```shell
$ oc get spyrenodestate
NAME           AGE
controller-1
controller-2
controller-3
worker-1
worker-2
```
