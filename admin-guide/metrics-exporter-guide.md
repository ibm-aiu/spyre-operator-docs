# Metrics Exporter Guide

## Table of Contents <!-- omit in toc -->

- [Change data file location](#change-data-file-location)
- [Change metrics exporter server port](#change-metrics-exporter-server-port)

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
