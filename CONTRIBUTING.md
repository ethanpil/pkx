# Contributing to pkx

The whole tool is one file: [`pkx`](pkx). The test suite runs on any host —
`--dry-run` plus a forced manager means no real package managers are needed:

```sh
sh tests/test_dryrun.sh
```

Every cell of the command tables in [docs/managers.md](docs/managers.md) is asserted there, along with every
alias, flag form, os-release detection (via `PKX_OS_RELEASE`, which points
pkx at a different os-release file), the Tumbleweed upgrade path, and —
against stub binaries — the `outdated` exit codes and the no-terminal `-y`
rule. The generated completion scripts are checked with `bash -n`, `zsh -n`
and `fish -n`, and the bash one is exercised. CI additionally runs
`shellcheck --shell=sh`, `checkbashisms`, and the suite under `dash`,
busybox `ash`, and `bash --posix`.
