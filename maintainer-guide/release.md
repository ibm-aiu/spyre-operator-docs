# Release Guide

This guide outlines the process for releasing a new version of the Spyre Operator and its components.

## Table of Contents

- [Components](#components)
- [Prerequisites](#prerequisites)
- [Release Process](#release-process)
  - [Step 1: Confirm Milestone Completion](#step-1-confirm-milestone-completion)
  - [Step 2: Create GitHub Releases](#step-2-create-github-releases)
  - [Step 3: Create Version Patches (Components)](#step-3-create-version-patches-components)
  - [Step 4: Merge Version Patch PRs](#step-4-merge-version-patch-prs)
  - [Step 5: Create Operator Version Patch](#step-5-create-operator-version-patch)
  - [Step 6: Update Documentation](#step-6-update-documentation)
  - [Step 7: Announce Release and Close Epic](#step-7-announce-release-and-close-epic)
  - [Step 8: Create Next Version Milestone](#step-8-create-next-version-milestone)
  - [Step 9: Create Epic Issue for Next Milestone](#step-9-create-epic-issue-for-next-milestone)
- [Epic Issue Template](#epic-issue-template)
- [Notes](#notes)

## Components

The Spyre Operator ecosystem consists of the following components:

1. [spyre-operator](https://github.com/ibm-aiu/spyre-operator) - Main operator
2. [spyre-scheduler-plugins](https://github.com/ibm-aiu/spyre-scheduler-plugins) - Scheduler plugins
3. [spyre-device-plugin](https://github.com/ibm-aiu/spyre-device-plugin) - Device plugin
4. [spyre-webhook-validator](https://github.com/ibm-aiu/spyre-webhook-validator) - Webhook validator
5. [spyre-health-checker](https://github.com/ibm-aiu/spyre-health-checker) - Health checker
6. [dra-driver-spyre](https://github.com/ibm-aiu/dra-driver-spyre) - DRA driver
7. [spyre-operator-actions](https://github.com/ibm-aiu/spyre-operator-actions) - GitHub Actions

Each component repository includes:

- `create-release.yaml` workflow - Automates GitHub release creation
- `version-patch.yaml` workflow - Automates version patch PR creation

## Prerequisites

- Access to all component repositories
- Permissions to trigger GitHub Actions workflows
- Permissions to create releases and merge PRs
- Understanding of the project's versioning scheme

## Release Process

### Step 1: Confirm Milestone Completion

Before starting the release process, verify that all milestones are complete:

1. Navigate to [GitHub Milestones](https://github.com/ibm-aiu/spyre-operator/milestone)
2. Confirm all issues in the milestone are closed **except** the release epic issue
3. This should be done before the code freeze period begins

### Step 2: Create GitHub Releases

Create a GitHub release for all components using the `create-release.yaml` workflow:

**For each component repository:**

1. Navigate to the repository's Actions tab
2. Select the "Create Release" workflow
3. Click "Run workflow"
4. Specify the version tag (e.g., `v1.4.0`)
5. The workflow will automatically:
   - Create a GitHub release
   - Generate release notes
   - Build and publish artifacts

**Component repositories to release:**

- [spyre-scheduler-plugins](https://github.com/ibm-aiu/spyre-scheduler-plugins/actions/workflows/create-release.yaml)
- [spyre-device-plugin](https://github.com/ibm-aiu/spyre-device-plugin/actions/workflows/create-release.yaml)
- [spyre-webhook-validator](https://github.com/ibm-aiu/spyre-webhook-validator/actions/workflows/create-release.yaml)
- [spyre-health-checker](https://github.com/ibm-aiu/spyre-health-checker/actions/workflows/create-release.yaml)
- [dra-driver-spyre](https://github.com/ibm-aiu/dra-driver-spyre/actions/workflows/create-release.yaml)
- [spyre-operator-actions](https://github.com/ibm-aiu/spyre-operator-actions/actions/workflows/create-release.yaml)
- [spyre-operator](https://github.com/ibm-aiu/spyre-operator/actions/workflows/create-release.yaml)

### Step 3: Create Version Patches (Components)

Create version patch PRs for all components **except** the operator using the `version-patch.yaml` workflow:

**For each component repository (excluding spyre-operator):**

1. Navigate to the repository's Actions tab
2. Select the "Version Patch" workflow
3. Click "Run workflow"
4. Specify the new version (e.g., `1.4.0`)
5. The workflow will automatically:
   - Update version numbers in configuration files
   - Update changelogs
   - Create a PR with the version changes

**Component repositories to patch:**

- [spyre-scheduler-plugins](https://github.com/ibm-aiu/spyre-scheduler-plugins/actions/workflows/version-patch.yaml)
- [spyre-device-plugin](https://github.com/ibm-aiu/spyre-device-plugin/actions/workflows/version-patch.yaml)
- [spyre-webhook-validator](https://github.com/ibm-aiu/spyre-webhook-validator/actions/workflows/version-patch.yaml)
- [spyre-health-checker](https://github.com/ibm-aiu/spyre-health-checker/actions/workflows/version-patch.yaml)
- [dra-driver-spyre](https://github.com/ibm-aiu/dra-driver-spyre/actions/workflows/version-patch.yaml)
- [spyre-operator-actions](https://github.com/ibm-aiu/spyre-operator-actions/actions/workflows/version-patch.yaml)

**Note:** Do NOT run the version patch workflow for spyre-operator yet.

### Step 4: Merge Version Patch PRs

Ensure all version patch PRs from Step 3 are reviewed and merged:

1. Address any review comments
2. Obtain required approvals
3. Merge PRs in dependency order if applicable
4. Verify CI/CD pipelines pass successfully

### Step 5: Create Operator Version Patch

Create the version patch for the operator **last** using the `version-patch.yaml` workflow:

1. Navigate to [spyre-operator's Actions tab](https://github.com/ibm-aiu/spyre-operator/actions/workflows/version-patch.yaml)
2. Select the "Version Patch" workflow
3. Click "Run workflow"
4. Specify the new version (e.g., `1.4.0`)
5. The workflow will:
   - Fetch the VERSION of all other components
   - Update the operator's version
   - Propagate component versions throughout the operator configuration
   - Create a PR with all version changes
6. Review and merge the PR after approval

**Important:** The operator must be patched last because it depends on the versions of all other components.

### Step 6: Update Documentation

Update all relevant documentation:

1. Update version references in documentation
2. Update installation guides
3. Update API documentation if applicable
4. Update migration guides if there are breaking changes
5. Review and update README files

### Step 7: Announce Release and Close Epic

Announce the release and finalize the milestone:

1. Prepare release announcement with key highlights
2. Post announcement to relevant channels (Slack, mailing lists, etc.)
3. Update the project website if applicable
4. Close the release epic issue in GitHub
5. Close the milestone

### Step 8: Create Next Version Milestone

If not already created, set up the next milestone:

1. Navigate to [GitHub Milestones](https://github.com/ibm-aiu/spyre-operator/milestone)
2. Click "New milestone"
3. Set the milestone title (e.g., "v1.2.0")
4. Set the target due date
5. Add a description outlining the goals for the next release

### Step 9: Create Epic Issue for Next Milestone

Create an epic issue to track the next release:

1. Use the epic issue template below
2. Link it to the newly created milestone
3. Add appropriate labels (e.g., `epic`, `release`)

---

## Epic Issue Template

Use this template when creating a release epic issue:

```markdown
# Release Epic: [Version Number]

## Overview
This epic tracks the release of Spyre Operator version [X.Y.Z].

## Release Goals
- [ ] Goal 1: [Brief description]
- [ ] Goal 2: [Brief description]
- [ ] Goal 3: [Brief description]

## Target Release Date
[YYYY-MM-DD]

## Code Freeze Date
[YYYY-MM-DD]

## Release Checklist

### Pre-Release
- [ ] All milestone issues completed (except this epic)
- [ ] All tests passing
- [ ] Documentation reviewed and updated
- [ ] Breaking changes documented
- [ ] Migration guide prepared (if needed)

### Release Process
- [ ] GitHub releases created for all components
- [ ] Version patches created for components (excluding operator)
- [ ] All component version patch PRs merged
- [ ] Operator version patch created and merged
- [ ] Documentation updated
- [ ] Release notes finalized

### Post-Release
- [ ] Release announced
- [ ] Next milestone created
- [ ] Next epic issue created
- [ ] This epic closed

## Known Issues
[List any known issues or limitations in this release]

## Breaking Changes
[List any breaking changes and migration steps]

## Dependencies
[List any dependencies or blockers]

## Related Issues
[Link related issues and PRs]

## Release Notes Draft
[Draft key highlights for the release announcement]

---

**Milestone:** [Link to milestone]
**Labels:** `epic`, `release`
**Assignees:** [Release manager(s)]
```

---

## Notes

- Always follow semantic versioning (MAJOR.MINOR.PATCH)
- Coordinate with the team during code freeze periods
- Ensure all CI/CD checks pass before merging
- Keep stakeholders informed throughout the release process
- Document any deviations from this process for future reference
