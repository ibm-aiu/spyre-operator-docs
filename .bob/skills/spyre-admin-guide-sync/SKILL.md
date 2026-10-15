---
name: spyre-admin-guide-sync
description: Use when asked to sync, refresh, or update the admin guide (admin-guide/*.md) with new upstream commits — walks through every commit merged into each Spyre component repo since the last synced commit recorded in this skill, updates the admin guide where needed, then records the new latest commit per component.
---

# Spyre Admin Guide Sync

Walk through all commits merged to each component since the **last synced commit**
(recorded in the table below), update `admin-guide/` where the changes affect cluster admins,
and then **update the table in this file** with the new latest commit per component.

## Last Synced Commits

> This table is the state of the skill. Always read it first and always rewrite it at the end (Step 7).

| Component | GitHub repo | Tracked branch | Local clone (`.components/`) | Last synced commit | Date |
|---|---|---|---|---|---|
| spyre-operator | `ibm-aiu/spyre-operator` | `main` | `spyre-operator.git` | `420855cfdb0f4c9afe9b8444ef4c3b7044b35bc2` | 2026-10-15 |
| spyre-scheduler-plugins | `ibm-aiu/spyre-scheduler-plugins` | `spyre-scheduler` (**not** `master`/`main`) | `spyre-scheduler-plugins.git` | `66adca64e17f92f20112d31b83d026fb47c64a71` | 2026-10-13 |
| spyre-device-plugin | `ibm-aiu/spyre-device-plugin` | `main` | `spyre-device-plugin.git` | `2494e2ab6493a0c402a3c3288442c0050570068b` | 2026-10-14 |
| spyre-webhook-validator | `ibm-aiu/spyre-webhook-validator` | `main` | `spyre-webhook-validator.git` | `ed85d70474e8987bf5224cbd64617bc0be1681fe` | 2026-10-13 |
| spyre-health-checker | `ibm-aiu/spyre-health-checker` | `main` | `spyre-health-checker.git` | `b5637b473301f9f5ba0d2713bb7131f16b45228d` | 2026-10-13 |
| dra-driver-spyre | `ibm-aiu/dra-driver-spyre` | `main` | `dra-driver-spyre.git` | `7a60971088af0b302d7e89aa46352ba4c927a45f` | 2026-10-14 |
| spyre-device-plugin-init | `ibm-aiu/spyre-device-plugin-init` | `main` | `spyre-device-plugin-init.git` | `9c0b976f0fb8314f0ba544f0ab1d8548662170b6` | 2026-10-02 |
| spyre-metrics-exporter | `ibm-aiu/spyre-metric-exporter` (note: repo name differs) | `main` | `spyre-metrics-exporter.git` | `539aedf88de225ae2930cb34b596152731ae6f9d` | 2026-10-02 |
| spyre-operator-actions | `ibm-aiu/spyre-operator-action` (note: repo name differs) | `main` | `spyre-operator-actions.git` | `d29ae825e1f42923051322e1dfeeeb71be9ef05e` | 2026-10-14 |

**Baseline:** the first row set above was recorded when this skill was created. No admin guide
update was performed for that baseline — only commits **after** these hashes need review.

## Step 1 — Set up or refresh local clones

Component repos are cloned as **bare, single-branch** repositories into `.components/`
at the root of this docs repo. The folder is listed in `.gitignore`; never commit it and
never use the sibling checkouts in `../` (they sit on feature branches and may be stale or corrupted).

Verify `.components/` is in `.gitignore`; add it if missing.

Use `GIT_SSH_COMMAND` so a missing SSH key fails fast instead of hanging:

```bash
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
mkdir -p .components && cd .components

# name:repo:branch  (keep in sync with the table above)
for spec in \
  "spyre-operator:spyre-operator:main" \
  "spyre-scheduler-plugins:spyre-scheduler-plugins:spyre-scheduler" \
  "spyre-device-plugin:spyre-device-plugin:main" \
  "spyre-webhook-validator:spyre-webhook-validator:main" \
  "spyre-health-checker:spyre-health-checker:main" \
  "dra-driver-spyre:dra-driver-spyre:main" \
  "spyre-device-plugin-init:spyre-device-plugin-init:main" \
  "spyre-metrics-exporter:spyre-metric-exporter:main" \
  "spyre-operator-actions:spyre-operator-action:main"; do
  IFS=: read name repo br <<< "$spec"
  if [ -d "$name.git" ]; then
    git --git-dir="$name.git" fetch -q --tags origin "+$br:$br"      # refresh
  else
    git clone -q --bare --single-branch --branch "$br" --tags \
      "git@github.com:ibm-aiu/$repo.git" "$name.git"                  # first time
  fi
  echo "$name: $(git --git-dir=$name.git log -1 --format='%H %ad %s' --date=short $br)"
done
```

If a clone fails (e.g. "invalid index-pack output"), delete that `<name>.git` folder and re-clone it.
If `git@github.com` access fails, ask the user how to authenticate; do not weaken TLS/SSH verification.

## Step 2 — List new commits per component

For each component, using the **Last synced commit** `<LAST>` and **Tracked branch** `<BR>` from the table:

```bash
G="git --git-dir=.components/<name>.git"
$G log --first-parent --format='%h %ad %s' --date=short <LAST>..<BR>
```

`--first-parent` gives one line per merged PR (all repos merge via PRs). If the list is empty, the
component has nothing new — skip it. If `<LAST>` is not found in the clone, stop and tell the user
(the history was rewritten or the branch is wrong); do not guess a new baseline.

Report a one-line summary per component to the user (`N new merged PRs`) before reading diffs.

## Step 3 — Inspect each merged PR

For every merge commit `<M>` in the list:

```bash
$G show --stat --format='%h %s%n%n%b' <M>^1..<M> | head -60   # PR title/body + files touched
$G diff <M>^1 <M> -- <path>                                    # only the relevant paths
$G show <BR>:<path>                                            # read a file at the tip
```

Prioritise the paths that define admin-visible behaviour:

| Component | Look at |
|---|---|
| spyre-operator | `api/**/*_types.go` (SpyreClusterPolicy / SpyreNodeState fields, defaults, validation markers), `config/**`, `bundle/**`, `assets/**`, `internal/**` for default images/flags/env, `README`/`docs` |
| spyre-device-plugin | CLI flags, env vars, config file paths and schema, topology/metadata handling, `SpyreNodeState` reporting |
| spyre-device-plugin-init | Generated metadata files, runtime/toolbox image contract, init container args |
| spyre-metrics-exporter | Metrics names/labels, port, data/metrics file paths, runtime image for PF metrics |
| spyre-health-checker | Reporters, metrics, failure-handling behaviour, flags |
| dra-driver-spyre | Driver flags, `DeviceClass`/`ResourceSlice` shape, topology generation, compatibility |
| spyre-webhook-validator | Validation/mutation rules, which resources are rejected, new error messages |
| spyre-scheduler-plugins | Scheduler plugin names/args, scoring/filtering behaviour, Kubernetes version compatibility |
| spyre-operator-actions | Usually CI only — review only if it changes release artifacts or bundle/cert behaviour |

## Step 4 — Decide whether the admin guide needs a change

**Needs a doc change** (admin-visible):
- New, renamed, removed, or re-defaulted `SpyreClusterPolicy` / `SpyreNodeState` fields
- New components, optional features, or experimental modes and how to enable them
- New or changed flags, env vars, file/mount paths, ports, metric names, image requirements
- Changed install, upgrade, or prerequisite steps (operators, BIOS, kernel, K8s/OpenShift versions)
- New failure modes, log messages, or troubleshooting steps; fixed known issues
- Behaviour changes in scheduling, allocation, validation, or health reporting
- Security-relevant behaviour admins must act on (new secrets, TLS settings, RBAC)

**No doc change** (record as reviewed and skip):
- Dependency bumps, CVE patches with no config impact, refactors, tests, lint, coverage
- CI/workflow, Sonar, dependabot, release/version-patch PRs
- Docs-only changes inside the component repo that do not alter behaviour

When unsure, prefer asking the user over guessing. Never invent field names, defaults, or
paths — copy them from the code at the tip.

## Step 5 — Map changes to admin guide files

| Topic | File |
|---|---|
| Install, BIOS, dependent operators, operator setup | `admin-guide/simple-instruction.md` |
| SpyreClusterPolicy fields, optional components, images, log level, experimental modes | `admin-guide/cluster-policy-customization-guide.md` |
| Example policies | `admin-guide/spyreclusterpolicy/*.yaml` |
| Verify devices / allocation | `admin-guide/daily-operation-guide.md` |
| Device plugin config, topology, init container | `admin-guide/device-plugin-guide.md` |
| DRA driver | `admin-guide/dra-driver-guide.md` |
| Metrics exporter | `admin-guide/metrics-exporter-guide.md` |
| Card management / VF enablement | `admin-guide/cardmgmt-guide.md` |
| Known issues and fixes | `admin-guide/troubleshooting.md` |

If a change fits no existing file, tell the user and propose a new guide (and a README link) rather than
creating one silently.

## Step 6 — Edit the docs

- Use `apply_diff` / `insert_content` for targeted edits; follow each file's existing heading
  style, admonitions (`> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`) and `Table of Contents <!-- omit in toc -->` format.
- If you add or rename a `##` heading, update that file's ToC anchors.
- Show every new field with a YAML snippet consistent with the example policies. If an example YAML
  must change, update all `admin-guide/spyreclusterpolicy/*.yaml` files that are affected.
- Document breaking default changes with an `> [!IMPORTANT]` or `> [!WARNING]` callout.
- Do not edit `release-notes/` — use the `spyre-release-notes` skill for that.
- Keep the change minimal: only what the commits justify.

Keep a running list: *commit → decision (doc change / skipped + reason) → file edited*. Present it
to the user at the end.

## Step 7 — Update this skill (always)

After the docs are done (or if no doc change was needed), rewrite the **Last Synced Commits** table
with the tip hash and date of each tracked branch at the time of the sync:

```bash
git --git-dir=.components/<name>.git log -1 --format='%H %ad' --date=short <BR>
```

Rules:
- Update the row for **every** component, including ones with no doc change, so the next run starts
  from where this one ended.
- Use the exact tip that was reviewed in Step 2 — if the branch moved after you listed commits,
  re-run Step 2 for the new commits instead of recording an unreviewed hash.
- If the user stops midway, record only the components that were fully reviewed.
- Use `apply_diff` on this file; keep the table format and the Baseline note (append a line such as
  `Last sync: YYYY-MM-DD` below it).

## Step 8 — Verify

- `git status` shows only intended changes under `admin-guide/` and `.bob/skills/spyre-admin-guide-sync/SKILL.md`
  (and `.gitignore` on first use); `.components/` must not appear.
- ToC anchors in every edited file match their `##` headings.
- Every table row has a 40-character hash that exists in its clone:
  `git --git-dir=.components/<name>.git cat-file -t <hash>` prints `commit`.
- Final message to the user: per-component count of commits reviewed, the doc files changed, and
  the commits deliberately skipped with a one-phrase reason.
