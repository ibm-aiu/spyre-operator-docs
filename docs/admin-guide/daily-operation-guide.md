# Daily Operation Guide

## Table of Contents <!-- omit in toc -->

- [Confirm device list](#confirm-device-list)
- [Confirm allocation status](#confirm-allocation-status)

## Confirm device list

The SpyreNodeState must contain

- a list of available physical devices and virtual devices if supported
- PCI topology in JSON-encoded string format

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreNodeState
metadata:
  name: worker-1
  ...
spec:
  spyreInterfaces:
  - health: healthy
    numVfs: 2
    pciAddress: 0000:ac:00.0
    vfs:
    - 0000:ac:00.1
    - 0000:ac:00.2
  ...
  pcitopo: <topology encoded string>
  ...
```

## Confirm allocation status

Try deploying the following simple pod.

```shell
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: single-spyre-job
  namespace: default
spec:
  schedulerName: spyre-scheduler
  containers:
    - name: app
      image: registry.access.redhat.com/ubi9/ubi:latest
      command: ["tail", "-f", "/dev/null"]
      resources:
        limits:
          ibm.com/spyre_pf: "1"
EOF
```

The allocation result should be shown in the SpyreNodeState's status of the scheduled node.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreNodeState
...
status:
  allocation:
  - devices:
    - 0000:ac:00.0
    pod:
      name: single-spyre-job
      namespace: default
```

> [!NOTE]
> If the devices are reconfigured after the device plugin generates the SpyreNodeState (e.g., plugging in/out devices, reconfigure virtual functions), the device plugin pod requires restart to rediscover the devices.<br/>
> To restart all device plugin pods, run the following command:<br/>
> `oc delete pods -n spyre-operator -l app=spyre-device-plugin`
