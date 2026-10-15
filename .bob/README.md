# Bob Skills for This Repository

This folder contains IBM Bob skills that help maintain the Spyre Operator documentation.
A skill is a `SKILL.md` file of step-by-step instructions that Bob loads when your request matches the skill's description.

## Available skills

| Skill | Use it to | Changes |
|---|---|---|
| [`spyre-admin-guide-sync`](skills/spyre-admin-guide-sync/SKILL.md) | Review commits merged in the component repos since the last sync and update `docs/admin-guide/` where needed | `docs/admin-guide/**`, the commit table in its own `SKILL.md` |
| [`spyre-release-notes`](skills/spyre-release-notes/SKILL.md) | Generate `docs/release-notes/vX.Y.Z.md` for a new release | `docs/release-notes/`, `README.md`, `mkdocs.yml` |

## How to use a skill

1. Open this repository as the workspace in Bob (the `.bob/skills/` folder is picked up automatically).
2. Describe the task in the chat. Bob matches your request to a skill by its `description`, so no special command is needed. Naming the skill also works.
3. Bob asks permission before activating a skill, unless **Skills** is turned on under Bob Settings → Auto-Approve.
4. Review the edits Bob proposes, then commit them yourself. Skills do not commit or push.

A skill loads once per conversation. Start a new conversation for a new run.

### Example prompts

```text
Sync the admin guide with new component commits.
```

```text
Use spyre-admin-guide-sync. Only look at spyre-operator and dra-driver-spyre this time.
```

```text
Write release notes for v1.5.0 (previous version v1.4.0).
```

## `spyre-admin-guide-sync`

Keeps `docs/admin-guide/` aligned with the nine component repos.

**Prerequisites**

- SSH access to `git@github.com:ibm-aiu/*` (the skill uses `BatchMode`, so it fails fast instead of prompting).
- `git` installed. No `gh` CLI needed.

**What happens on a run**

1. Bob clones or refreshes bare repos in `.components/` (git-ignored, about 50 MB). Your sibling checkouts in `../` are never used or modified.
2. For each component, Bob lists the PRs merged after the commit recorded in the skill's **Last Synced Commits** table.
3. Bob reads the diffs, decides which changes matter to cluster admins, and edits the matching `docs/admin-guide/*.md` files.
4. Bob rewrites the commit table in `SKILL.md` to the new tips and reports what changed and what was skipped.

**What you should do**

- Review the doc edits. Bob will ask you about borderline changes instead of guessing.
- **Commit the updated `SKILL.md` together with the doc edits.** The table in that file is the state of the sync. If it isn't committed, the next person re-reviews the same commits.
- Run it on an up-to-date branch of this repo so the table does not conflict with a teammate's sync.

**Tracked branches**

Most components track `main`. `spyre-scheduler-plugins` tracks `spyre-scheduler`, not `master`. The skill's table is the source of truth; edit it if a default branch changes.

**Troubleshooting**

| Symptom | Fix |
|---|---|
| A clone fails with `invalid index-pack output` | Delete that `.components/<name>.git` folder and run again. |
| Bob says the last synced commit was not found | The branch history changed. Confirm the tracked branch with the team, then ask Bob to propose a new baseline. Don't guess one. |
| SSH or permission error | Check access to the `ibm-aiu` org (`ssh -T git@github.com`). |

## `spyre-release-notes`

Builds a release notes file in the established format from each component's GitHub release changelog.

**Prerequisites**

- Releases for all components already created (see [`maintainer-guide/release.md`](../docs/maintainer-guide/release.md)).
- Optional: the `gh` CLI authenticated to `ibm-aiu`, so Bob can fetch changelogs. Otherwise Bob asks you to paste them.

**What happens on a run**

1. Bob asks for the new and previous versions.
2. It collects the changelogs, filters out non-admin-visible changes, and writes `docs/release-notes/vX.Y.Z.md`.
3. It adds the new entry to the Release Notes list in the root `README.md` and `mkdocs.yml`.

## Writing or changing a skill

- Each skill lives in `.bob/skills/<skill-name>/SKILL.md` with `name` and `description` front matter. A skill without a `description` is ignored.
- Write the `description` so it says when to use the skill. Bob uses it to decide when to activate.
- Supporting files (templates, checklists, scripts) can sit next to `SKILL.md`.
- Keep skills in this folder in sync with the docs they update. For example, if you add a guide file under `docs/admin-guide/`, add it to the mapping table in `spyre-admin-guide-sync`.
- Never put secrets in a skill. Use SSH keys or `gh auth` from your own environment.
