# Git and pull requests

Keep `main` ready to build. Develop one focused change at a time on a short-lived branch and merge it through a pull request after the required checks pass. The app's build and test commands are in [CONTRIBUTING.md](../CONTRIBUTING.md); publishing is a separate maintainer action described in [RELEASING.md](RELEASING.md).

## Start and save a change

Start with a clean working tree. Inspect existing changes before switching branches or pulling; preserve work you did not create.

```sh
git status --short
git switch main
git pull --ff-only
git switch -c codex/short-description
```

Use the `codex/` prefix for agent-created branches. Contributors may use descriptive names such as `fix/widget-placement`. Keep unrelated refactors, formatting, and features in separate commits. A useful commit title states the intent, for example `fix: preserve language when restarting Settings` or `test: cover stale playback responses`.

Review the diff and relevant verification results before committing. Stage specific files or hunks rather than everything in the working tree. `project.yml` is the project definition; commit the regenerated Xcode project with it. Commit the resolved Swift package lockfile when changing dependencies. Build products, personal signing changes, credentials, and local logs stay out of Git.

```sh
git diff --check
git diff
git add path/to/changed-file
git diff --staged
git commit -m "fix: describe the resulting behavior"
git push -u origin HEAD
```

## Review and merge

Open a PR against `main` with the problem, resulting behavior, and checks run. Use draft status while the change is still incomplete. Add regression tests for changed behavior and document any scenario that requires hardware, macOS permissions, or manual UI verification. Keep screenshots and logs limited to what explains the change, with private information removed.

The `CI` workflow runs for pull requests to `main`, pushes to `main`, and manual dispatches. Its stable required check names are:

| Check | Purpose |
| --- | --- |
| `Quality checks` | Script tests, localization validation, configuration checks, and repository hygiene |
| `macOS tests` | App-hosted regression suite and coverage report |
| `Universal Release build` | Build the app and helper for Apple silicon and Intel without a personal signing certificate |

Run `./script/ci.sh` locally for all stages, or select `checks`, `test`, or `build`. CI stores logs and test results as workflow artifacts; local results are under `.build/ci/`. CI does not publish, install, or launch the user's installed app. Fork PRs run without release credentials. Never introduce a privileged `pull_request_target` job that checks out and executes untrusted PR code.

Before merging, inspect the complete diff, green checks, and unresolved discussions. A solo maintainer can perform this review and merge without an approval from another account. Use **Squash and merge** for an ordinary focused PR; use **Rebase and merge** when each commit is independently useful and verified. Both keep `main` linear. Use a clear final title and retain relevant validation in the PR description.

If `main` changes while a PR is open, update the branch and rerun checks. Rebase only unpublished local commits; merge `origin/main` into an already shared feature branch when needed. Never force-push `main`, shared branches, or public tags. Do not delete a branch containing unmerged work. Git worktrees may isolate parallel changes, but inspect their status and retain needed work before removing them.

## Repository rules

The intended `main` policy is a pull request with the three checks above passing on the current base, resolved review conversations, and linear history. It blocks force-pushes and branch deletion. It requires **zero external approvals** so the solo maintainer can merge a reviewed PR. Repository merge settings permit squash and rebase, disable merge commits, and remove merged PR head branches automatically.

These GitHub settings are separate from files committed to the repository. Confirm their live state in **Settings → Branches / Rules** and **Settings → General → Pull Requests**; adding this guide or a workflow alone does not enable protection. Apply required checks only after the named jobs have run successfully, and keep their names stable when reorganizing CI. Do not rename or remove a required check without updating the repository rule in the same maintenance task.

## Dependency updates

Dependabot checks GitHub Actions weekly and groups their version updates into one PR. Review the upstream changes and CI results before merging; updates do not merge automatically. Keep Actions pinned to reviewed commit SHAs, with version comments that Dependabot can maintain.

The workflow also pins the Xcode runner baseline and validation-tool archives.
Update those versions and SHA-256 digests together after verifying the official
release, then run the same checks in a PR. XcodeGen's version must agree with
the committed generated project; regeneration is checked without rewriting
the working tree.

Sparkle is declared in `project.yml` and resolved by the Xcode project. Update that declaration and the resolved lockfile together, then regenerate and verify the app. The root `Package.swift` is not the complete application definition, so Dependabot is not configured to treat it as the app dependency manifest.

## Releases and recovery

Passing CI does not publish a release. Prepare and verify signed release artifacts separately using the [release procedure](RELEASING.md). Record the exact verified source commit in its source tag. Once public, tags and ZIP bytes remain immutable; a correction gets a higher build number, a new build-specific ZIP, and a new tag. For a refresh of the same display version, upload the verified archive before updating the Sparkle feed.

Use `git revert` to undo a merged change, then verify the resulting PR. Do not reset shared history or replace an existing release archive to hide a regression. A release fix needs its own verified build.

References: [GitHub branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), [Actions updates with Dependabot](https://docs.github.com/en/enterprise-cloud%40latest/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/auto-update-actions), and [issue form syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms).
