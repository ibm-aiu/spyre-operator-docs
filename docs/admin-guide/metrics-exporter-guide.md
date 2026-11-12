# Metrics Exporter Guide

## Table of Contents <!-- omit in toc -->

- [Change data file location](#change-data-file-location)
- [Change metrics exporter server port](#change-metrics-exporter-server-port)
- [Provide runtime image to parse PF card metrics](#provide-runtime-image-to-parse-pf-card-metrics)
- [Metrics folder mount](#metrics-folder-mount)

## Change data file location

By default, Spyre Device Plugin automatically mounts `/data` to user pod for sharing metrics file generated inside the user pod to the metrics exporter. This location can be customized as below.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  metricsExporter:
    ...
    metricsPath: /tmp/data # instead of /data
...
```

## Change metrics exporter server port

`port` in metrics exporter is the metrics exporter server port. Default port is `8082`.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  metricsExporter:
    port: 8080
```

> [!WARNING]
> After version `1.1.0`, we change from root user requirement to non-root user Pod with UID=`1001` to allow it to write the sentientmap in the metrics folder. Admin must inform user to set UID of their containers to `1001`.

## Provide runtime image to parse PF card metrics

> [!IMPORTANT]
> From version `1.4.0`, `spyre-metrics-exporter` requires a runtime image to parse PF card metrics from physical devices.
> The runtime image must be provided via `.spec.metricsExporter.runtime`.
> Without it, the metrics exporter will not be able to read or expose hardware-level metrics for PF cards.

```yaml
apiVersion: spyre.ibm.com/v1alpha1
kind: SpyreClusterPolicy
metadata:
  name: spyreclusterpolicy
spec:
  ...
  metricsExporter:
    ...
    runtime:
      repository: "quay.io/ibm-aiu"
      image: "spyre-runtime-ctk"
      version: "v1.3.0"
```

## Metrics folder mount

The node agent (the device plugin, or the DRA driver when `.spec.devicePlugin.mode: dra`, see [DRA Driver Guide](dra-driver-guide.md)) mounts a writable metrics folder from the host into each container that is allocated Spyre devices, so that the metrics exporter can read the metrics written by the container. The mount path is common to both:

- The node agent creates one folder per allocation under the host path and mounts it at the container path.
- It sets `METRICS.general.path` in the generated `senlib_config.json` to `<container path>/metrics.%BUSID` (default container path: `/tmp/spyre-metrics`) when `METRICS.general.enable` is `true` in the senlib config template, otherwise to `metrics.%BUSID`.

The following environment variables of the node agent container (set through `.spec.devicePlugin.env`) override the paths:

| Environment variable | Description | Default (device plugin) | Default (DRA driver) |
| -------------------- | ----------- | ----------------------- | -------------------- |
| `SPYRE_METRIC_HOSTPATH` | Host folder under which a metrics folder is created per allocation | `/usr/local/etc/device-plugins/spyre-metrics` | `/usr/local/etc/dra-driver-spyre/spyre-metrics` |
| `SPYRE_METRIC_FILEPATH` | Container path where the metrics folder is mounted | `/tmp/spyre-metrics` | `/tmp/spyre-metrics` |

When `.spec.metricsExporter.metricsPath` is set (see [Change data file location](#change-data-file-location)), the operator sets `SPYRE_METRIC_FILEPATH` to that value on the node agent and on the metrics exporter, so both sides stay consistent. Do not set a different `SPYRE_METRIC_FILEPATH` in `.spec.devicePlugin.env` at the same time.

> [!IMPORTANT]
> In the DRA driver, from version `1.5.0`, `SPYRE_METRIC_HOSTPATH` and `SPYRE_METRIC_FILEPATH` replace `SENTIENT_MAP_HOSTPATH` and `SENTIENT_MAP_FILEPATH`; the old names are no longer read. The default container path changed from `/data` to `/tmp/spyre-metrics`, and the driver no longer sets `GENERAL.multi_aiu_config_path`.
