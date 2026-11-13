# gates-action

Composite GitHub Action that runs the Gates required check on a pull request. It
installs [eris](https://github.com/sibylline-labs/eris) and runs `eris gate ci`.

## What it does

The action adds one required check, `gates`. What the check enforces is driven by your
organisation's Gates CI settings, not by the workflow:

- how untracked pull requests are handled;
- the bot allowlist;
- the profile check;
- surface unlocks, read from `.claude/surfaces.yml` in your repository.

The action runs two steps:

1. **Install eris.** It downloads the eris binary for the runner from a GitHub release,
   checks its SHA-256 against the release's `SHA256SUMS`, and only then makes it
   executable. A missing or mismatched checksum fails the step.
2. **Run `eris gate ci`.** It reads the pull request event (`$GITHUB_EVENT_PATH`) and the
   registry file, and exits non-zero when the check fails.

## Usage

```yaml
name: gates

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, ready_for_review]

permissions:
  contents: read

jobs:
  gates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          fetch-depth: 0
      - uses: sibylline-labs/gates-action@v1
        with:
          token: ${{ secrets.GATES_TOKEN }}
```

- **`fetch-depth: 0` is required.** The check diffs the pull request against its
  merge-base, and a shallow clone does not contain it.
- Keep the job named `gates`: the job name is the check name that branch protection or a
  ruleset requires.
- The trigger types re-run the check when a pull request is opened, pushed to, reopened,
  edited (for example a title change) or moved out of draft.

`eris gates init` scaffolds this workflow.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `token` | yes | | A Gates service token with the `gates:read` scope. |
| `api-url` | no | `https://api.sibylline.group` | Base URL of the Gates API. |
| `eris-version` | no | empty (latest release) | eris release tag to install. |
| `eris-repository` | no | `sibylline-labs/eris` | GitHub repository whose releases carry the eris binary. |
| `eris-token` | no | `${{ github.token }}` | Token used to read the releases of `eris-repository`. |
| `registry` | no | `.claude/surfaces.yml` | Path to the surfaces registry, relative to the repository root. |

The action has no outputs.

## Token

Create the Gates service token with the `gates:read` scope and nothing else, and store it
as the `GATES_TOKEN` secret. The check makes read-only requests to the Gates API, so it
needs no other scope. The action hands the token to eris through the
`ERIS_YAKS_TOKEN` environment variable, and the API URL through `ERIS_YAKS_URL`; it is
never placed on a command line.

## Requirements

- A Linux x64 or macOS arm64 runner. Other runners fail with an error that names them.
- The GitHub CLI (`gh`), which GitHub-hosted runners include, and `sha256sum` or
  `shasum`.
- An eris release that includes the `gate ci` command. Pin one with `eris-version` if you
  need a specific release.

## License and security

Apache License 2.0, see [LICENSE](LICENSE). Report vulnerabilities as described in
[SECURITY.md](SECURITY.md).
