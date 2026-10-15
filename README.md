# IBM AIU Spyre Operator Documentation

[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://ibm-aiu.github.io/spyre-operator-docs/)

Documentation portal for the [IBM AIU Spyre Operator](https://github.com/ibm-aiu/spyre-operator) on Red Hat OpenShift and Kubernetes.

📖 **Published Documentation:** [https://ibm-aiu.github.io/spyre-operator-docs/](https://ibm-aiu.github.io/spyre-operator-docs/)

---

## 📋 Release Notes

- [v1.4.0](docs/release-notes/v1.4.0.md)

## 📕 Cluster Admin Guide

- [Operator Simple Setup Instruction](docs/admin-guide/simple-instruction.md)
- [SpyreClusterPolicy Customization Guide](docs/admin-guide/cluster-policy-customization-guide.md)
- [Daily Operation Guide](docs/admin-guide/daily-operation-guide.md)
- [Troubleshooting for Admins](docs/admin-guide/troubleshooting.md)
- Detailed Configuration for Sub Components:
  - [Device Plugin](docs/admin-guide/device-plugin-guide.md)
  - [DRA Driver](docs/admin-guide/dra-driver-guide.md)
  - [Metrics Exporter](docs/admin-guide/metrics-exporter-guide.md)
  - [Card Management](docs/admin-guide/cardmgmt-guide.md)

## 📗 User Guide

- [User Guide](docs/user-guide/user-guide.md)
- [Troubleshooting for Users](docs/user-guide/troubleshooting.md)

## 📘 Maintainer Guide

- [Release Guide](docs/maintainer-guide/release.md)
- [Markdown Edit Settings](docs/maintainer-guide/markdown-edit-settings.md)
- [Go Runtime and Vulnerability Fix Guide](docs/maintainer-guide/go-runtime-and-vuln-fix.md)

---

## 💻 Local Development

This documentation site is built using [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).

### Prerequisites

- Python 3.11+

### Quick Start

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Start the local development server:
   ```bash
   mkdocs serve
   ```
   Open [http://127.0.0.1:8000](http://127.0.0.1:8000) in your browser. Changes are reloaded automatically.

3. Build the static site:
   ```bash
   mkdocs build --strict
   ```
   The built HTML files are output to the `site/` directory.

---

## ✏️ Reporting Issues

Please create [an issue in spyre-operator repo](https://github.com/ibm-aiu/spyre-operator/issues/new/choose) with the following information:

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
