# Troubleshooting for Admins

## Table of Contents <!-- omit in toc -->

- [Known Issues](#known-issues)
  - [_ERROR   client-go   Failed to update lock: resource name may not be empty_](#error---client-go---failed-to-update-lock-resource-name-may-not-be-empty)
    - [Recommended Actions](#recommended-actions)
  - [Spyre usage metrics are not exported to Prometheus](#spyre-usage-metrics-are-not-exported-to-prometheus)
  - [There is no file in the metrics path](#there-is-no-file-in-the-metrics-path)
  - [There is POD\_NAME file but no sentientmap\_\* file in the metrics path](#there-is-pod_name-file-but-no-sentientmap_-file-in-the-metrics-path)

## Known Issues

### _ERROR   client-go   Failed to update lock: resource name may not be empty_

When "`ERROR   client-go   Failed to update lock: resource name may not be empty`" is present in the operator log file and is followed by an operator restart indicates that the operator (manager) process could not properly connect to the kubernetes API server.

The operator log file can be viewed using your choice of tools. The `oc` that can be used in this case is: `oc logs spyre-operator-XXX` -- substitute the XXX token for  the pod hash code.

#### Recommended Actions

This is an expected behavior for any operator that is implemented using the operator runtime and its an indicator of network issues, communications between the node and the API server is interrupted. If the error is sporadic and the same error is present in the log of other operators, it can safely be ignored.

If the error is persistent, please validate the network connection between the node executing the operator pod and the API server is there and there are no other underlying issues.

If you have enough resources in the cluster consider increasing the operator deployment replica count to attenuate any service disruptions.

### Spyre usage metrics are not exported to Prometheus

Please check the metrics path inside your container. The default path is `/data` for version < `1.2.0` and `/tmp/spyre-metrics` from version `1.2.0`.
This path can be override in `.spec.metricsExporter.metricsPath` in `SpyreClusterPolicy`.

### There is no file in the metrics path

The metrics folder must be reserved for a metrics exporter to read users' pod metrics. This folder is also automatically mounted by the device plugin on pod creation.  The pod must not manually contain this volume mount in its spec.

### There is POD_NAME file but no sentientmap_* file in the metrics path

Please check the following common causes:

- The `METRICS.general.path` in senlib_config.json may be overriden by the other user configuration such as in `~/.senlib.json`. Please confirm the user-defined senlib_config.
- After version `1.1.0`, we change from root user requirement to non-root user Pod with UID=`1001` to allow it to write the sentientmap in the metrics folder. Please confirm the Pod UID setup in security context.

   ```yaml
   securityContext:
      capabilities:
        drop:
        - ALL
      runAsUser: 1001
      runAsNonRoot: true
      allowPrivilegeEscalation: false
   ```
