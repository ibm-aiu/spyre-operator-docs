# Troubleshooting for Users

## Table of Contents <!-- omit in toc -->

- [Known Issues](#known-issues)
  - [Missing `/etc/aiu/senlib_config.json` error](#missing-etcaiusenlib_configjson-error)
  - [Pod becomes `Pending` state](#pod-becomes-pending-state)
  - [Pod becomes `ContainerStatusUnknown` state](#pod-becomes-containerstatusunknown-state)
  - [Webhook validation errors](#webhook-validation-errors)

## Known Issues

### Missing `/etc/aiu/senlib_config.json` error

- Please make sure there is no pre-defined volume mounted to path `/etc/aiu`. This folder is reserved for volumed mounted by the Spyre device plugin only.

    For example, the following volume mount must be removed.

    ```yaml
    volumeMounts:
    - mountPath: /etc/aiu
    name: config
    ```

### Pod becomes `Pending` state

- Check requested resource name especially for the experimental per-device allocation. Ask cluster administrator to check [available resource names](./advanced_user_guide.md#available-resource-names).

- Confirm status of SpyreNodeState and node capacity/allocatable.

### Pod becomes `ContainerStatusUnknown` state

- This state could happen when the Spyre resource is in a race condition between multiple resource pools such as default pool and experimental mode's per-device allocation pool. Restarting the pod in this status manually should put it back into a pending state until the device is released.

- A pod must not use `.spec.nodeName` as it will bypass scheduler allocation logic and can cause an error of device not available; use '.spec.nodeSelector' instead.

  The following node name specification may not be used.

  ```yaml
  spec:
    nodeName: worker-1
  ```

  Instead, nodeSelector as below can be defined.

  ```yaml
  spec:
    nodeSelector:
      kubernetes.io/hostname: worker-1
  ```

### Webhook validation errors

If the pod validator webhook is enabled, you may encounter the following error during creation, which is intended to prevent incorrect functionality of the operator.

- A pod cannot request or limit Spyre from more than one resource pool

  A pod cannot request or limit more than one resource name.

  For example, the below request is invalid. `ibm.com/spyre_pf_0000_1a_00.0` and `ibm.com/spyre_pf_0000_3d_00.0` cannot be requested at the same time.

  ```yaml
  spec:
    containers:
    - name: app
      image: registry.access.redhat.com/ubi9/ubi:latest
      imagePullPolicy: IfNotPresent
      command: ["tail", "-f", "/dev/null"]
      resources:
        limits:
          ibm.com/spyre_pf_0000_1a_00.0: "1"
          ibm.com/spyre_pf_0000_3d_00.0: "1"
  ```

- A pod manifest must specify `schedulerName: spyre-scheduler` if the `externalDeviceReservation` mode is enabled.

  ```yaml
  spec:
    schedulerName: spyre-scheduler
  ```
