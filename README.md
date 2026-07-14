# pkx

**One package-manager syntax for every Unix.**

`pkx` is a single POSIX `sh` script that wraps the native package manager on
every major Linux distro, macOS, and the BSDs behind one small set of verbs:

```
$ pkx install htop
pkx: running: sudo dnf install htop
...
```

Same command on Debian, Arch, Alpine, openSUSE, Void, Gentoo, FreeBSD,
OpenBSD, NetBSD, or a Mac. `pkx` figures out which package manager the system
uses, translates the verb, handles `sudo`/`doas` for you, and — by default —
**prints the real native command before running it**, so every use also
teaches you the actual command for the box you're on.

## Goals

- **Muscle memory.** One set of obvious verbs (`install`, `remove`, `search`,
  `upgrade`, ...) that works identically everywhere. No more "wait, is it
  `apt update` or `dnf makecache` or `pacman -Sy` here?"
- **Teaching mode, not a crutch.** pkx shows you the native command it runs
  (`pkx: running: sudo apt-get install htop`). Silence it with `-q`, or use
  `-n` to print the command without running anything.
- **Zero dependencies, one file.** Pure POSIX `sh` — no bash, no python, no
  compiled binary per architecture. It runs on `dash`, busybox `ash`, and any
  `/bin/sh`, which means it works on a minimal Alpine container or an ancient
  ppc64 box the moment you copy it there.
- **Fail loudly, never approximate.** One verb has one meaning. When a
  manager has no safe equivalent (e.g. an index-only `refresh` on Arch), pkx
  refuses with an explanation and a distinct exit code instead of silently
  doing something almost-right.

## Install

One file, no dependencies:

```sh
curl -fsSL https://raw.githubusercontent.com/ethanpil/pax/main/pkx -o /usr/local/bin/pkx
chmod +x /usr/local/bin/pkx
```

or with wget:

```sh
wget -qO /usr/local/bin/pkx https://raw.githubusercontent.com/ethanpil/pax/main/pkx
chmod +x /usr/local/bin/pkx
```

(Use `sudo` for `/usr/local/bin`, or drop it anywhere on your `PATH`, e.g.
`~/.local/bin`.) Verify with:

```sh
pkx which
```

which prints the detected manager and exactly what every verb maps to on this
system.

## Quick start

```sh
pkx install htop tmux      # install packages
pkx remove htop            # uninstall
pkx search terminal        # search the repos
pkx info tmux              # package details
pkx upgrade                # refresh index + upgrade everything
pkx list                   # installed packages
pkx owns /usr/bin/vim      # which package owns this file?
pkx files tmux             # which files did this package install?
pkx orphans                # remove no-longer-needed dependencies
pkx clean                  # clear the package manager caches
```

Short aliases for the frequent ones: `pkx in`, `pkx rm`, `pkx se`, `pkx up`,
`pkx ls`.

## Supported package managers

| Platform | Manager |
|---|---|
| Debian, Ubuntu, Mint, ... | `apt` (apt-get / apt-cache / dpkg) |
| Fedora, RHEL, Rocky, Alma | `dnf` |
| Older RHEL / CentOS | `yum` |
| Arch, Manjaro, ... | `pacman` |
| Alpine | `apk` |
| openSUSE, SLES | `zypper` |
| Void | `xbps` |
| Gentoo | `emerge` (portage) |
| macOS | `brew` (Homebrew), `port` (MacPorts) |
| FreeBSD, DragonFly | `pkg` |
| OpenBSD | `pkg_add` / `pkg_info` / `pkg_delete` |
| NetBSD | `pkgin` |

Detection prefers the distro's native manager — a Fedora box with Homebrew
installed still gets `dnf`. Override any time with `--via <mgr>` or the
`PKX_MANAGER` environment variable (friendly names work too: `--via arch`,
`--via void`, `--via openbsd`, ...).

## Verb reference

What each verb runs, per manager. This table is the contract — the test suite
asserts every cell.

| verb | apt | dnf | pacman | apk | zypper | brew |
|---|---|---|---|---|---|---|
| `install` | `apt-get install` | `dnf install` | `pacman -S` | `apk add` | `zypper install` | `brew install` |
| `remove` | `apt-get remove` | `dnf remove` | `pacman -Rns` | `apk del` | `zypper remove` | `brew uninstall` |
| `search` | `apt-cache search` | `dnf search` | `pacman -Ss` | `apk search` | `zypper search` | `brew search` |
| `info` | `apt-cache show` | `dnf info` | `pacman -Si` | `apk info` | `zypper info` | `brew info` |
| `refresh` | `apt-get update` | `dnf makecache` | *refused*¹ | `apk update` | `zypper refresh` | `brew update` |
| `upgrade` | `update && dist-upgrade` | `dnf upgrade --refresh` | `pacman -Syu` | `update && upgrade` | `refresh && update` | `update && upgrade` |
| `list` | `dpkg --get-selections` | `rpm -qa` | `pacman -Q` | `apk info` | `zypper search -i` | `brew list --versions` |
| `orphans` | `apt-get autoremove` | `dnf autoremove` | `-Qdtq \| -Rns -` | *n/a*² | *n/a*² | `brew autoremove` |
| `clean` | `apt-get clean` | `dnf clean all` | `pacman -Scc` | `apk cache clean` | `zypper clean --all` | `brew cleanup` |
| `owns` | `dpkg -S` | `rpm -qf` | `pacman -Qo` | `apk info --who-owns` | `rpm -qf` | *n/a*² |
| `files` | `dpkg -L` | `rpm -ql` | `pacman -Ql` | `apk info -L` | `rpm -ql` | `brew list --verbose` |

| verb | yum | xbps | emerge | port | pkg (FreeBSD) | pkg_add (OpenBSD) | pkgin (NetBSD) |
|---|---|---|---|---|---|---|---|
| `install` | `yum install` | `xbps-install` | `emerge` | `port install` | `pkg install` | `pkg_add` | `pkgin install` |
| `remove` | `yum remove` | `xbps-remove` | `--deselect && --depclean` | `port uninstall` | `pkg delete` | `pkg_delete` | `pkgin remove` |
| `search` | `yum search` | `xbps-query -Rs` | `emerge --search` | `port search` | `pkg search` | `pkg_info -Q` | `pkgin search` |
| `info` | `yum info` | `xbps-query -RS` | `emerge --info` | `port info` | `pkg info` | `pkg_info` | `pkgin pkg-descr` |
| `refresh` | `yum makecache` | `xbps-install -S` | `emerge --sync` | `port sync` | `pkg update` | *n/a*² | `pkgin update` |
| `upgrade` | `yum update` | `xbps-install -Su` | `--sync && -uDN @world` | `selfupdate && upgrade outdated` | `pkg upgrade` | `pkg_add -u` | `update && full-upgrade` |
| `list` | `rpm -qa` | `xbps-query -l` | `qlist -Iv` | `port installed` | `pkg info` | `pkg_info` | `pkgin list` |
| `orphans` | `yum autoremove` | `xbps-remove -o` | `emerge --depclean` | `port uninstall leaves` | `pkg autoremove` | `pkg_delete -a` | `pkgin autoremove` |
| `clean` | `yum clean all` | `xbps-remove -O` | `eclean-dist` | `port reclaim` | `pkg clean` | *n/a*² | `pkgin clean` |
| `owns` | `rpm -qf` | `xbps-query -o` | `qfile` | `port provides` | `pkg which` | `pkg_info -E` | `pkg_info -Fe` |
| `files` | `rpm -ql` | `xbps-query -f` | `qlist` | `port contents` | `pkg info -l` | `pkg_info -L` | `pkgin pkg-content` |

¹ See [pacman and `refresh`](#pacman-and-refresh) below.
² Exits with code 3 and a one-line explanation of why the operation doesn't
exist there — run it to see the reason.

Meta-commands:

- `pkx which` — print the detected manager, the escalation command, and every
  verb mapping for this system.
- `pkx raw -- <args>` — escape hatch: pass args straight to the native tool
  (`pkx raw -- -Syu` on Arch runs `pacman -Syu`). No sudo is added — you're
  in manual mode.

## Flags and environment

| Flag | Meaning |
|---|---|
| `-y`, `--yes` | Assume yes on prompts (maps to `-y`, `--noconfirm`, `--non-interactive`, `-N`, `-I`, ... per manager) |
| `-n`, `--dry-run` | Print the native command; run nothing |
| `-q`, `--quiet` | Don't print the native command before running |
| `--via <mgr>` | Force a specific manager |
| `-h`, `--help` | Help |
| `-V`, `--version` | Version |

| Variable | Meaning |
|---|---|
| `PKX_MANAGER` | Same as `--via` |
| `PKX_SUDO` | Privilege command to use for root operations. Default: plain when root, else `sudo`, else `doas`. Set it empty (`PKX_SUDO=`) to disable escalation, or e.g. `PKX_SUDO="sudo -E"` to customize. |

**Exit codes:** `2` usage error, `3` verb not supported by this manager,
`1` no manager found; anything else is the native tool's exit code, passed
through untouched — so scripts can tell pkx problems from package problems.

## Quirks and design notes

### pacman and `refresh`

`pkx refresh` means "update the package index, change nothing else." On Arch
that would be `pacman -Sy` — which is [famously dangerous](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported):
installing anything after a bare `-Sy` is a partial upgrade that can break
the system. There is no safe index-only refresh on Arch, so pkx refuses
(exit 3) and points you at `pkx upgrade` (`pacman -Syu`) instead. This is the
"fail loudly" rule in action.

### Homebrew and sudo

pkx never escalates for `brew` — Homebrew refuses to run as root by design.
Every other manager gets `sudo`/`doas` only for verbs that need it
(`install`, `remove`, `refresh`, `upgrade`, `orphans`, `clean`); `search`,
`info`, `list`, `owns` and `files` always run unprivileged.

### Gentoo

`list`, `owns` and `files` use `qlist`/`qfile` from **portage-utils**, and
`clean` uses `eclean-dist` from **gentoolkit** — the standard Gentoo admin
tools. If they're missing you'll get a plain command-not-found from the
system, and `pkx -n <verb>` shows you what would have run.

### One verb, one meaning

`refresh` only updates the index. `upgrade` refreshes and then upgrades
everything (a compound command where the native tool needs one — dry-run
shows exactly what will execute, e.g.
`apt-get update && apt-get dist-upgrade`). `pkx upgrade foo` is rejected on
purpose: upgrading a single package is `pkx install foo`.

## Prior art

| Tool | Difference from pkx |
|---|---|
| [pacapt](https://github.com/icy/pacapt) | Shell script, but uses pacman's `-Syu` flag syntax and leans on bash; pkx is verb-based and pure POSIX |
| [pacaptr](https://github.com/rami3l/pacaptr) | Polished Rust binary, pacman syntax; needs the right binary per platform/arch |
| [upt](https://github.com/sigoden/upt) | Verb-based Rust binary; same per-arch install problem |
| [sysget](https://github.com/emilengler/sysget) | Verb-based C++; dormant |

pkx's niche: obvious verbs + a single `curl`-able POSIX file that runs
anywhere `/bin/sh` exists + teaching mode.

## Development

The whole tool is one file: [`pkx`](pkx). The test suite runs on any host —
`--dry-run` plus a forced manager means no real package managers are needed:

```sh
sh tests/test_dryrun.sh
```

Every cell of the verb table above is asserted there. CI additionally runs
`shellcheck --shell=sh`, `checkbashisms`, and the suite under `dash`,
busybox `ash`, and `bash --posix`.

## Changelog

### 0.1.0 — 2026-07-14

Initial release.

- Verbs: `install`, `remove`, `search`, `info`, `refresh`, `upgrade`,
  `list`, `orphans`, `clean`, `owns`, `files`, `which`, `raw` (+ aliases
  `in`, `rm`, `se`, `up`, `ls`)
- 13 managers: apt, dnf, yum, pacman, apk, zypper, xbps, emerge, brew,
  port, pkg (FreeBSD), pkg_add (OpenBSD), pkgin (NetBSD)
- Teaching mode (prints the native command; `-q` to silence)
- `-n` dry-run, `-y` assume-yes, `--via` / `PKX_MANAGER` override,
  `PKX_SUDO` escalation control (sudo → doas fallback, never for brew)
- Fail-loudly semantics: exit 3 for unmappable operations, native exit
  codes passed through
- POSIX sh only; tested under dash, busybox ash, and bash --posix

## License

[MIT](LICENSE)
