# Operator Simple Setup Instruction

This document describes simple steps to setup IBM AIU Spyre Operator using Red Hat Certified Operator Catalog in OpenShift 4.21.

## 1. BIOS/Linux Setup

> [!IMPORTANT]
> The SELinux policy MachineConfig must be applied before installing the Spyre Operator. It configures SELinux policies and directory permissions needed for the device plugin to run as a non-root user.

1. enable SR-IOV and IOMMU in BIOS (UEFI) setting

2. apply `MachineConfig`
   - For amd64:

      ```bash
      WORK_DIR=$(mktemp -d)
      git clone --depth=1 https://github.com/ibm-aiu/spyre-operator.git "$WORK_DIR"
      oc apply -f "$WORK_DIR/config/machineconfig/amd64/"
      ```

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
