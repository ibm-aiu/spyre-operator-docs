# Device Plugin Guide

## Table of Contents <!-- omit in toc -->

- [Inject custom topology data](#inject-custom-topology-data)
- [Change configuration file location](#change-configuration-file-location)
- [Use external toolbox image to generate metadata file via init container](#use-external-toolbox-image-to-generate-metadata-file-via-init-container)

## Inject custom topology data

By default, Spyre Device Plugin employs the Spyre card topology data (`topo.json`) created from PCI bus info, and it registers the data to `SpyreNodeState.spec.pcitopo`. In some cases, this automated mechanism may introduce inappropriate device allocation (e.g., Spyres are located under virtual PCI switch).

To mitigate the issue, you can inject custom topology data as follows.

1. prepare topology file (see #417 for its format and generation methods) for each node, and store them in a directory (say, `cluster1-custom-topology`)
2. create a `ConfigMap` (say, `custom-topology`) from the directory containing the topology files

   ```text
   oc -n spyre-operator create configmap spyre-node-topology --from-file=path/to/cluster1-custom-topology
   ```

3. add `topologyConfigMap` to `SpyreClusterPolicy.spec.devicePlugin`

   ```yaml
    apiVersion: spyre.ibm.com/v1alpha1
    kind: SpyreClusterPolicy
    metadata:
      name: spyreclusterpolicy
    spec:
      ...
      devicePlugin:
        ...
        topologyConfigMap: custom-topology
   ```

To confirm the topology data injection, use `oc exec` to login a device plugin Pod and show the mounted topology file.

1. select device plugin Pod running on the focused node

    ```text
    oc -n spyre-operator get pod -l app=spyre-device-plugin-daemonset -o wide
    NAME                                READY   STATUS    RESTARTS   AGE     IP             NODE       NOMINATED NODE   READINESS GATES
    spyre-device-plugin-daemonset-slqj2   1/1     Running   0          4d20h   10.130.1.166   worker-2   <none>           <none>
    spyre-device-plugin-daemonset-vk27w   1/1     Running   5          8d      10.128.2.8     worker-3   <none>           <none>
    ```

2. login the device plugin Pod and show topology file

    ```text
    oc -n spyre-operator exec -it   spyre-device-plugin-daemonset-slqj2 -- /bin/bash
    [root@spyre-device-plugin-daemonset-slqj2 /]# cd /etc/spyre
    [root@spyre-device-plugin-daemonset-slqj2 spyre]# ls topology/
    worker-2
    ```

## Change configuration file location

By default, Spyre Device Plugin automatically attaches Spyre configuration file to an Spyre Pod. The default config file location is `/etc/aiu/senlib_config.json`, but user can customize it by adding `configPath` and `configName` to SpyreClusterPolicy.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  devicePlugin:
    ...
    configPath: /etc/ibm/spyre # instead of /etc/aiu
    configName: config.json    # instead of senlib_config.json
...
```

## Use external toolbox image to generate metadata file via init container

To extract some card information such as peer-to-peer verified topology and metadata, the external tool must be used for acquiring and processing the physical devices.

The expected output is a generated `topo.json` file in the mounted host path `/usr/local/etc/device-plugins/metadata`.

Spyre operator allows user to define the toolbox image via init container as below.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  devicePlugin:
    initContainer:
      executePolicy: IfNotPresent
      repository: "icr.io/ibmaiu_internal"
      image: "spyre-device-plugin-init"
      version: "0.1.0-dev"
```

> [!NOTE]
> If the devices are reconfigured after topo.json has been generated (e.g., plugging in/out devices),
> the following steps are required to execute the topology discovery and regenerate the topo.json.<br/><br/>
> To regenerate topo.json on a specific node,<br/>
>
> 1. Taint the node and ensure that no other pods are currently using or acquiring the devices.<br/>
> 2. Manually delete the complete flag file (`/usr/local/etc/device-plugins/complete`) from the host.<br/>
> 3. Restart a specific device plugin pod or using the following command to restart all device plugin pods: `oc delete pods -n spyre-operator -l app=spyre-device-plugin`<br/>
>
> To regenerate topo.json on all nodes at once,<br/>
>
> 1. Ensure that no user pod can be allocated.<br/>
> 2. Change `.spec.devicePlugin.initContainer.executePolicy` to `Always` and wait until all device plugin restarted.<br/>
> 3. Change `.spec.devicePlugin.initContainer.executePolicy` back to `IfNotPresent` to prevent potential conflict when the device plugin is unexpectedly restarted.
>
>
> This operation must be carefully taken.
> The init container requires the card to be available and can cause a conflict with running Pods.
> Before operating this, admin must ensure that there is no card being used.

> [!TIP]
> To regenerate the topology only on a specific node,
> admin can access into the node and manually remove the complete file
> `/usr/local/etc/device-plugins/complete` then restart the device plugin in Pod running on that node
> This will not affect the running Pods on the other nodes.
