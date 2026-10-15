# IBM AIU Spyre Operator Documentation

Welcome to the documentation for the **IBM AIU Spyre Operator**. The Spyre Operator automates the management, configuration, and monitoring of IBM AIU Spyre accelerator cards on Red Hat OpenShift and Kubernetes clusters.

---

## 🚀 Navigation Overview

<div class="grid cards" markdown>

-   :material-newspaper:{ .lg .middle } __Release Notes__

    ---

    Read about latest updates, changes, and release highlights.

    [:octicons-arrow-right-24: Release Notes](release-notes/v1.4.0.md)

-   :material-server-security:{ .lg .middle } __Cluster Admin Guide__

    ---

    Setup instructions, cluster policy customizations, and sub-component guides.

    [:octicons-arrow-right-24: Admin Guide](admin-guide/simple-instruction.md)

-   :material-account-cog:{ .lg .middle } __User Guide__

    ---

    Workload deployment, resource request formats, and user troubleshooting.

    [:octicons-arrow-right-24: User Guide](user-guide/user-guide.md)

-   :material-tools:{ .lg .middle } __Maintainer Guide__

    ---

    Release processes, markdown standards, and vulnerability maintenance.

    [:octicons-arrow-right-24: Maintainer Guide](maintainer-guide/release.md)

</div>

---

## 📋 Quick Links

### Release Notes
- [v1.4.0](release-notes/v1.4.0.md)

### Cluster Admin Guide
- [Operator Simple Setup Instruction](admin-guide/simple-instruction.md)
- [SpyreClusterPolicy Customization Guide](admin-guide/cluster-policy-customization-guide.md)
- [Daily Operation Guide](admin-guide/daily-operation-guide.md)
- [Troubleshooting for Admins](admin-guide/troubleshooting.md)
- **Detailed Configuration for Sub-Components:**
    - [Device Plugin](admin-guide/device-plugin-guide.md)
    - [DRA Driver](admin-guide/dra-driver-guide.md)
    - [Metrics Exporter](admin-guide/metrics-exporter-guide.md)
    - [Card Management](admin-guide/cardmgmt-guide.md)

### User Guide
- [User Guide](user-guide/user-guide.md)
- [Troubleshooting](user-guide/troubleshooting.md)

### Maintainer Guide
- [Release Guide](maintainer-guide/release.md)
- [Markdown Edit Settings](maintainer-guide/markdown-edit-settings.md)
- [Go Runtime and Vulnerability Fix Guide](maintainer-guide/go-runtime-and-vuln-fix.md)

---

## ✏️ Reporting Issues

Please create [an issue in the spyre-operator repo](https://github.com/ibm-aiu/spyre-operator/issues/new/choose) with the following information:

- User workload YAML and log (`oc get -n <namespace> -o yaml <pod-name>` and `oc logs -n <namespace> <pod-name>`)
- SpyreClusterPolicy (`oc get spyrepol spyreclusterpolicy -o yaml`)
    - If you specify `.skipUpdateComponent` in the policy, please also add customized configuration (e.g., ConfigMap)
- Operator log (`oc get -n spyre-operator logs spyre-operator-xxx-xxx`)
- Deployment data:
    - `oc get -n spyre-operator get pod -o yaml`
    - `oc get -n spyre-operator get deploy -o yaml`
    - `oc get -n spyre-operator get daemonset -o yaml`
- Device plugin log and cardmgmt log of the node with the malfunctioning card:
    - `oc get -n spyre-operator logs spyre-device-plugin-xxx-xxx`
    - `oc get -n spyre-operator logs spyre-cardmgmt-xxx-xxx`
