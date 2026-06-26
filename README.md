# IBM AIU Spyre Operator Documentation

## 📕 Cluster Admin Guide

- [Operator Simple Setup Instruction](admin-guide/simple-instruction.md)
- [SpyreClusterPolicy Customization Guide](admin-guide/cluster-policy-customization-guide.md)
- [Daily Operation Guide](admin-guide/daily-operation-guide.md)
- [Troubleshooting for Admins](admin-guide/troubleshooting.md)
- Detailed Configuration for Sub Components
  - [Device Plugin](admin-guide/device-plugin-guide.md)
  - [Metrics Exporter](admin-guide/metrics-exporter-guide.md)

## 📗 User Guide

- [User Guide](user-guide/user-guide.md)
- [troubleshooting](user-guide/troubleshooting.md)

## 📘 Maintainer Guide

- [Release Guide](maintainer-guide/release.md)
- [Markdown Edit Settings](markdown-edit-settings.md)
- [Go Runtime and Vulnerability Fix Guide](maintainer-guide/go-runtime-and-vuln-fix.md)

## ✏️ Reporting Guide

Please create [an issue in spyre-operator repo](https://github.com/ibm-aiu/spyre-operator/issues/new/choose) with following information.

- user workload YAML and log (`oc get -n <namespace> -o yaml <pod-name>` and `oc logs -n <namespace> <pod-name>`)
- SpyreClusterPolicy (`oc get spyrepol spyreclusterpolicy -o yaml`)
  - If you specify `.skipUpdateComponent` in the policy, please also add customized configuration (e.g., ConfigMap)
- operator log (`oc get -n spyre-operator logs spyre-operator-xxx-xxx`)
- deployment data
  - `oc get -n spyre-operator get pod -o yaml`
  - `oc get -n spyre-operator get deploy -o yaml`
  - `oc get -n spyre-operator get daemonset -o yaml`
- device plugin log and cardmgmt log of the node of malfunctioning card
  - `oc get -n spyre-operator logs spyre-device-plugin-xxx-xxx`
  - `oc get -n spyre-operator logs spyre-cardmgmt-xxx-xxx`
