---
name: spyre-release-notes
description: Use when writing or generating release notes for a new Spyre Operator version — collects component changelogs, filters significant changes, and produces a structured release notes document following the project's established format.
---

# Spyre Release Notes Generator

Follow these steps to produce `release-notes/vX.Y.Z.md` for a new Spyre Operator release.

## Step 1 — Identify the version

Ask the user for the new release version (e.g. `1.5.0`) and the previous version (e.g. `1.4.0`) if not already stated.

## Step 2 — Collect component changelogs

For each component below, ask the user to paste the auto-generated GitHub release changelog
(or fetch it yourself using `execute_command` with the `gh` CLI if the repos are accessible):

```bash
gh release view vX.Y.Z --repo ibm-aiu/<component> --json body -q .body
```

Components:
- `spyre-operator`
- `spyre-scheduler-plugins`
- `spyre-device-plugin`
- `spyre-webhook-validator`
- `spyre-health-checker`
- `dra-driver-spyre`
- `spyre-device-plugin-init`
- `spyre-metrics-exporter`
- `spyre-operator-actions`

## Step 3 — Read the previous release notes for context

Use `read_file` to load the most recent release notes file (e.g. `release-notes/v1.4.0.md`)
so the format, tone, and style are fresh in context before writing.

## Step 4 — Filter and consolidate changes

From all collected changelogs, extract only changes that are significant to an operator admin or end user:

**Include:**
- New user-facing components or capabilities
- New, renamed, or removed `SpyreClusterPolicy` API fields
- Default value changes (especially breaking ones)
- Breaking changes to existing behaviour
- Security fixes (CVEs, auth/TLS hardening, bypass fixes)
- Significant dependency upgrades with runtime impact (Go version, base image, Kubernetes API compatibility)

**Exclude:**
- Internal refactors with no user-visible effect
- Test-only or doc-only changes
- Dependency version bumps with no behavioural impact
- CI plumbing changes unless they affect release artifacts

**Consolidate cross-component themes:** if multiple components contribute to the same feature
(e.g. a new metric in health-checker AND a new dashboard panel in the operator), write it as
one cohesive entry — not one entry per component.

## Step 5 — Write the release notes

Create `release-notes/vX.Y.Z.md` using `write_file` with the following structure.
Match the heading levels, table format, admonition style (`> [!IMPORTANT]`, `> [!NOTE]`,
`> [!WARNING]`), and ToC format from the previous release notes exactly.

### Required sections (in order)

```
# Release Notes — vX.Y.Z

## Table of Contents <!-- omit in toc -->
(list all ## sections below)

---

## New Components
(### per new open-source or promoted component; include what changed architecturally and config pointer)

## New Features
(### per significant capability; include DRA changes, reporter frameworks, dashboard panels, scraping additions, etc.)

## API Changes

### New Fields
(#### per new or changed field across any Spyre custom resource:
- `SpyreClusterPolicy` — operator-wide and per-component configuration
- `SpyreNodeState` — per-node device state reported by the device plugin

For each field include: CR kind, field path, type, optional/required, default value, and a YAML snippet showing usage.)

### Default Value Changes ⚠️ Breaking
(table: Kind | Field | vPREV default | vCURR default; IMPORTANT callout if existing CRs are affected)

## Security Fixes
(table: Area | Detail)

## CI / Engineering Changes
(table: Area | Detail)

## Migration Guide
(actionable steps for every breaking change; link back to the Default Value Changes table)
```

Omit any section that has no content for this release. Do not add placeholder text.

## Step 6 — Update README

Use `apply_diff` to add a new list entry under the `## 📋 Release Notes` section in `README.md`:

```markdown
- [vX.Y.Z](release-notes/vX.Y.Z.md)
```

Insert it above the previous version so the list is newest-first.

## Step 7 — Verify

Read back the written file with `read_file` and confirm:
- ToC entries match the actual `##` section headings in the body (exact anchor match)
- Every `####` API field entry has a YAML snippet
- Breaking changes appear in both the API Changes table and the Migration Guide
- No section is empty
