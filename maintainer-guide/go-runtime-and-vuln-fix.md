# Go Runtime and Vulnerability Fix Guide

## Table of Contents <!-- omit in toc -->

- [TL;DR](#tldr)
- [Why `go-toolset` instead of plain upstream Go](#why-go-toolset-instead-of-plain-upstream-go)
- [How we configure it: `go.mod` and the Dockerfile](#how-we-configure-it-gomod-and-the-dockerfile)
  - [`go.mod`](#gomod)
  - [Dockerfile](#dockerfile)
  - [Where `GOTOOLCHAIN` should be `local` vs `auto`](#where-gotoolchain-should-be-local-vs-auto)
- [Handling vulnerabilities when `go-toolset`'s Go version falls behind](#handling-vulnerabilities-when-go-toolsets-go-version-falls-behind)
  - [Two categories of vulnerability, two different detection paths](#two-categories-of-vulnerability-two-different-detection-paths)
  - [Triage steps when a new Go CVE outpaces our `go-toolset` version](#triage-steps-when-a-new-go-cve-outpaces-our-go-toolset-version)
  - [Tooling coverage at a glance](#tooling-coverage-at-a-glance)
- [Dependabot PR approval and merge policy](#dependabot-pr-approval-and-merge-policy)
  - [Decision matrix](#decision-matrix)
  - [Dependencies that require manual upgrade](#dependencies-that-require-manual-upgrade)
- [Reference](#reference)

## TL;DR

- We use Red Hat's [FIPS 140](https://csrc.nist.gov/pubs/fips/140-3/final)-enabled go-toolset (not upstream Go) because our RHEL/OpenShift deployments require FIPS-compliant cryptography. As a result, the Go toolchain version is a compliance requirement: go.mod and the Dockerfile must stay aligned to the approved go-toolset version.
- Since Red Hat's Go releases typically lag upstream, we may temporarily run on versions with known Go CVEs. We manage that risk through a defined vulnerability review and exception process until a compliant update is available.
- Dependency vulnerabilities are largely automated, but Go toolchain vulnerabilities must be tracked separately using upstream and vendor security advisories.

## Why `go-toolset` instead of plain upstream Go

Our binaries run on RHEL/RHCOS (OpenShift) in environments that require **FIPS 140 compliant cryptography**. Upstream Go's `crypto/*` packages are a pure-Go implementation — even if functionally fine, it is not a FIPS-validated module, so a binary built with stock Go fails compliance review regardless of how it behaves.

Red Hat's `go-toolset` image ships a **patched Go toolchain** (upstream of the patches: `github.com/golang-fips/go`) that, when built with `-tags strictfipsruntime`, changes how `crypto/*` is implemented:

- Instead of using Go's own crypto code, calls are routed via `cgo` + `dlopen` to the system's `libcrypto.so` at runtime.
- `libcrypto.so` on a FIPS-mode RHEL/RHCOS host is the actual FIPS 140 validated module.

This means FIPS compliance is **not a single switch** — it requires both halves to be true at once:

1. **Build-time**: the binary must be compiled with `go-toolset` (so the FIPS-routing code exists in the binary at all) and with `-tags strictfipsruntime`.
2. **Run-time**: the binary must run on a host where FIPS mode is enabled and `libcrypto.so` is present.

`-tags strictfipsruntime` deserves a special note: it is not an optional strictness knob. Without it, if `libcrypto.so` can't be loaded at runtime for any reason, the binary **silently falls back** to Go's non-FIPS crypto and keeps running — i.e., compliance breaks invisibly, with no error. With the tag, the same failure causes a hard panic instead. For us, a loud crash is strictly preferable to a silent compliance gap, so this tag is treated as mandatory in every build.

One consequence worth calling out explicitly: **the `go-toolset` version and the upstream Go version are not interchangeable, even when the version numbers look the same.** `go-toolset:1.25.9` is not "Go 1.25.9 plus a FIPS sticker" — it's a separate, Red Hat–maintained build. Our `go.mod` version must point at a version Red Hat actually ships as `go-toolset`, not at whatever the latest upstream Go release happens to be.

## How we configure it: `go.mod` and the Dockerfile

The rule we follow: **`go.mod` is the single source of truth for the toolchain version, and it must exactly match the `go-toolset` image tag we build with.**

### `go.mod`

```go
go 1.25.9
```

(Replace `1.25.9` with whatever `go-toolset` tag we are currently pinned to)

Both the `go` directive and the explicit `toolchain` directive are set to the same version. This matters because of how `GOTOOLCHAIN` resolution works: if `go.mod` requests a version newer than what's installed and `GOTOOLCHAIN=auto` is in effect, the `go` command will silently download the requested version **from golang.org**. That downloaded toolchain is plain upstream Go — not the `golang-fips` fork — so an "innocent" version bump in `go.mod` alone is enough to quietly break FIPS compliance without touching the Dockerfile at all. Pinning `toolchain` explicitly closes that hole.

### Dockerfile

```dockerfile
FROM registry.access.redhat.com/ubi9/go-toolset:1.25.9
ENV GOTOOLCHAIN=local
# build with: go build -tags strictfipsruntime ...
```

`GOTOOLCHAIN=local` here is intentional and differs from developer-workstation guidance below: inside the container, the base image *is* the toolchain we want, so we never want `go` reaching out anywhere to fetch a different one. `GOTOOLCHAIN=local` makes that explicit instead of relying on the `go.mod` pin alone.

### Where `GOTOOLCHAIN` should be `local` vs `auto`

| Environment                               | Setting                                                                                                                             | Why                                                                                                                                                                                                                   |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Container build (Dockerfile)              | `GOTOOLCHAIN=local`                                                                                                                 | The base image guarantees the exact FIPS-validated Go binary; never let `go` fetch a substitute.                                                                                                                      |
| CI/CD (GitHub Actions)                    | `GOTOOLCHAIN=local`, or rely on `go.mod`'s `toolchain` directive                                                                    | Same reasoning as container builds — CI should build with exactly what we ship, not "whatever's newest."                                                                                                              |
| Developer workstation (`make build`, IDE) | `go.mod`'s `toolchain` directive is the effective pin; `GOTOOLCHAIN=auto` is safe *only because* `go.mod` already fixes the version | A developer building locally should reproduce the same toolchain as CI/containers — not a newer one. If `go.mod` is correctly pinned, `auto` vs `local` makes no practical difference, but it's safer to be explicit. |

The failure mode we specifically guard against: a developer's local build silently using a different (often newer) Go version than the container build. If a bug only reproduces on one specific Go patch version, an unpinned setup means the developer can't even see the bug the CI/production build would hit — or vice versa. Keeping `go.mod` as the single source of truth, and matching the `go-toolset` tag to it, is what prevents that drift.

## Handling vulnerabilities when `go-toolset`'s Go version falls behind

Red Hat does not ship a new `go-toolset` image the moment upstream Go publishes a security release — there's routinely a gap of weeks to months, and an even longer gap before a corresponding RHSA (Red Hat Security Advisory) exists for that specific CVE. During that gap, we are running a Go version with a *known, public* CVE. The question is not "how do we avoid this" (we can't, fully) but "how do we know about it and respond appropriately."

### Two categories of vulnerability, two different detection paths

**1. Vulnerabilities in code paths our binary actually executes** (stdlib functions we call, or third-party/`golang.org/x/*` modules we depend on)

These are detectable by tooling:

- `govulncheck` traces actual reachable call paths in our code against the Go vulnerability database — this is our primary, most trustworthy signal, because it tells us whether a given CVE is even reachable from our binary, not just "present somewhere in the dependency graph."
- Dependabot / Mend / SonarQube catch the same class from a dependency-graph angle and are useful as a second layer, but are noisier (they flag CVEs we may not actually reach).
- If the fix lives in `golang.org/x/*`, we can usually patch that module independently via Go's minimal version selection — this does **not** require bumping `go-toolset` or `client-go`, since it's a regular module dependency, not part of the toolchain itself.
- If the fix lives in the standard library itself (e.g., `net/http`, `crypto/x509`), there is no module to bump — the only real fix is a newer Go toolchain. Until `go-toolset` catches up, we assess and document residual risk (see triage steps below).

**2. Vulnerabilities in the `go` command / toolchain behavior itself** (e.g., a module-checksum-validation bypass, or a compiler bug)

These are **not** detectable by `govulncheck`, Dependabot, or similar tools, because there's no code path in *our* binary to trace — the bug is in how the `go` command behaves at build time, before our code is even compiled. The only way to catch these is manual tracking against primary sources:

- `pkg.go.dev/vuln` (the authoritative Go vulnerability database)
- `nvd.nist.gov` (cross-check version ranges — third-party aggregators have been wrong about affected version boundaries before)
- The `golang-announce` Google Group (security releases are announced here fastest, ahead of NVD reflecting them)
- `github.com/golang/go/issues`

### Triage steps when a new Go CVE outpaces our `go-toolset` version

1. **Confirm the CVE against a primary source**, not a blog post or aggregator summary. Get the exact affected version range and the fixed version.
2. **Check whether the vulnerable code path applies to us at all.** Many Go CVEs are one-sided (e.g., a CVE affecting only `net/http`'s client-side `Transport`/`Client` doesn't matter for a server-only binary; a CVE in a code path only reachable with attacker-controlled `GOPROXY` doesn't matter if we only ever pull from a trusted, pinned proxy). Document this reasoning — it's the difference between "theoretically affected" and "actually exploitable in our deployment."
3. **Check for an existing RHSA** against our `go-toolset` tag. If one exists, the fix may already be available without waiting for a version bump we'd have to request separately.
4. **Apply any interim mitigation that's available short of a toolchain bump**, while being clear about what it does and doesn't cover — e.g., pinning `GOPROXY` to a single trusted proxy reduces (but does not eliminate) exposure to proxy-level attacks; `GOTOOLCHAIN=local` removes the "auto-download an arbitrary toolchain" attack surface. Neither of these is a substitute for the real fix once it's available.
5. **Record the CVE, our assessment, and current status** in our tracked CVE table so it isn't re-investigated from scratch later and so we notice when `go-toolset` finally catches up.
6. **Escalate** if a CVE is both severe and plausibly exploitable in our actual deployment with no available mitigation — don't just wait silently for Red Hat's release cadence.

### Tooling coverage at a glance

| Tool                                                             | Catches dependency CVEs               | Catches stdlib CVEs                   | Catches `go` command/toolchain CVEs    |
| ---------------------------------------------------------------- | ------------------------------------- | ------------------------------------- | -------------------------------------- |
| `govulncheck`                                                    | Yes (reachability-aware)              | Yes (reachability-aware)              | No                                     |
| Dependabot / Mend                                                | Yes (dependency-graph based, noisier) | Partial                               | No                                     |
| Trivy / Grype (image scan)                                       | Partial                               | Partial, depends on RHSA availability | Partial, often lags                    |
| Manual check against `pkg.go.dev/vuln` / NVD / `golang-announce` | —                                     | —                                     | Yes (currently the only reliable path) |

The key takeaway for planning purposes: there is no tool we can simply install and trust to give full coverage. Dependency- and stdlib-level CVEs are well automated; toolchain-level CVEs require a recurring manual check against primary sources, which is why we treat that as a standing process item rather than a one-time setup task.

## Dependabot PR approval and merge policy

Dependabot automatically opens PRs whenever it detects a newer version of a Go module. Not every Dependabot PR warrants the same level of scrutiny. The policy below defines the minimum gate each PR must pass before it can be merged, based on the [semver](https://semver.org/) upgrade type.

### Decision matrix

| Upgrade type | Required gate before merge |
| ------------ | -------------------------- |
| **Patch** (`x.y.Z → x.y.Z+n`) | PR CI (`pr.yaml`) passes. No additional manual action required — merge once green. |
| **Minor** (`x.Y.z → x.Y+n.z`) | Trigger and pass the end-to-end test suite before merging. |
| **Major** (`X.y.z → X+n.y.z`) | Require a full integration test run to pass before merging. |

> **Rationale:** patch releases are, by convention, backward-compatible and low-risk, so automated CI is sufficient. Minor releases may introduce behavioral changes not covered by unit tests, so end-to-end coverage is added. Major releases carry explicit breaking-change expectations and require the broadest integration coverage available.

### Dependencies that require manual upgrade

The following dependencies are excluded from the automated Dependabot merge flow regardless of semver type. Upgrades to these packages carry significant ecosystem-wide compatibility implications (API breakage, controller-runtime contract changes, test framework changes) and must be planned, reviewed, and coordinated by a maintainer rather than merged automatically.

```yaml
- dependency-name: "k8s.io/*"
  versions: ["*"]
- dependency-name: "sigs.k8s.io/*"
  versions: ["*"]
- dependency-name: "tags.cncf.io/*"
  versions: ["*"]
- dependency-name: "github.com/onsi/ginkgo/v2"
  versions: ["*"]
```

For these dependencies, the Dependabot PR should be left open as a tracking reference. A maintainer must open a dedicated upgrade issue and PR, and merge only after the relevant integration and end-to-end tests pass.

## Reference

- [golang-fips/go](https://github.com/golang-fips/go) — the FIPS-patched Go fork that `go-toolset` is built from
- [Go Vulnerability Database](https://pkg.go.dev/vuln) — authoritative Go vulnerability database
- [National Vulnerability Database](https://nvd.nist.gov) — NVD, useful for cross-checking version ranges
- [golang-announce](https://groups.google.com/g/golang-announce) Google Group — fastest source for new Go security releases
- Red Hat Developer blog, "FIPS mode" articles covering `go-toolset`: [Go and FIPS 140-2 on Red Hat Enterprise Linux](https://developers.redhat.com/blog/2019/06/24/go-and-fips-140-2-on-red-hat-enterprise-linux), [Is your Go application FIPS compliant?](https://developers.redhat.com/articles/2022/05/31/your-go-application-fips-compliant)
