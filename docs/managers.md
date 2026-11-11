# How pkx maps each command to each package manager

This page is the detailed reference behind the [README](../README.md). Use it
when you need to know exactly which native command pkx runs on a given
system, or why pkx refuses an operation there.

To see the mappings for the system you are on, run `pkx which` (all
commands) or `pkx help <command>` (one command).

## Supported package managers and detection

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

Detection reads `/etc/os-release` (`ID`, then `ID_LIKE`) to pick the
distro's own manager, so a Debian box that also has `pacman`, `dnf` or
`apk-tools` installed for building chroots still gets `apt`, and a Fedora
box with Homebrew still gets `dnf`. Without a usable os-release (macOS, the
BSDs) pkx probes for the manager binaries instead. Override any time with `--via <mgr>` or the
`PKX_MANAGER` environment variable (friendly names work too: `--via arch`,
`--via void`, `--via openbsd`, ...).

## Command mappings

What each command runs, per manager (abbreviated — the `sudo`/`doas` prefix and
some flags are omitted for readability). The test suite asserts the exact
command for every one of these mappings.

| verb | apt | dnf | pacman | apk | zypper | brew |
|---|---|---|---|---|---|---|
| `install` | `apt-get install` | `dnf install` | `pacman -S --needed` | `apk add` | `zypper install` | `brew install` |
| `install <file>`⁷ | `apt-get install ./f` | `dnf install ./f` | `pacman -U` | `apk add ./f` | `zypper install ./f` | *n/a*² |
| `remove` | `apt-get remove` | `dnf remove` | `pacman -Rs` | `apk del` | `zypper remove` | `brew uninstall` |
| `purge` | `apt-get purge` | *n/a*² | `pacman -Rns` | *n/a*² | *n/a*² | *n/a*² |
| `search` | `apt-cache search` | `dnf search`¹¹ | `pacman -Ss` | `apk search`¹¹ | `zypper search`¹¹ | `brew search`¹¹ |
| `info` | `apt-cache show` | `dnf info` | `pacman -Si` | `apk search -e -v` | `zypper info` | `brew info` |
| `refresh` | `apt-get update` | `dnf makecache` | *refused*¹ | `apk update` | `zypper refresh` | `brew update` |
| `upgrade` | `update; dist-upgrade` | `dnf upgrade --refresh` | `pacman -Syu` | `update && upgrade` | `refresh && update` | `update && upgrade` |
| `upgrade <pkg>` | `update; install --only-upgrade` | `dnf upgrade --refresh` | *refused*⁴ | `update && upgrade` | `refresh && update`⁴ | `update && upgrade` |
| `outdated`⁶ | `apt list --upgradable` | `dnf check-update` | `pacman -Qu` | `apk list -u` | `zypper list-updates` | `brew outdated --verbose` |
| `list` | `apt list --installed` | `rpm -qa` | `pacman -Q` | `apk list --installed` | `zypper search --installed-only` | `brew list --versions` |
| `list <pkg>` | `dpkg-query -W … \| grep`⁸ | `rpm -q` | `pacman -Q` | `apk info -e` | `rpm -q` | `brew list --versions` |
| `autoremove` | `apt-get autoremove` | `dnf autoremove` | `-Rns $(pacman -Qdtq)`³ | *n/a*² | *n/a*² | `brew autoremove` |
| `orphans` | `apt-get --simulate autoremove` | `dnf repoquery --unneeded` | `pacman -Qdt` | *n/a*² | `zypper packages --unneeded` | `brew autoremove --dry-run` |
| `clean` | `apt-get clean` | `dnf clean all` | `pacman -Sc` | `apk cache clean` | `zypper clean --all` | `brew cleanup` |
| `owns` | `dpkg -S` | `rpm -qf` | `pacman -Qo` | `apk info --who-owns` | `rpm -qf` | *n/a*² |
| `files` | `dpkg -L` | `rpm -ql` | `pacman -Ql` | `apk info -L` | `rpm -ql` | `brew list --verbose` |
| `deps` | `apt-cache depends` | `dnf repoquery --requires --resolve`¹² | `pactree -s -d1 -u`⁹ | `apk info -R` | `zypper info --requires` | `brew deps --direct`⁹ |
| `rdeps` | `apt-cache rdepends --installed` | `dnf repoquery --installed --whatrequires` | `pactree -r -d1 -u`⁹ | `apk info -r` | `zypper search --installed-only --requires-pkg` | `brew uses --installed`⁹ |
| `hold` | `apt-mark showhold` | `dnf versionlock list`¹² | *n/a*² | *n/a*² | `zypper locks` | `brew list --pinned` |
| `hold <pkg>` | `apt-mark hold` | `dnf versionlock add`¹² | *n/a*² | *n/a*² | `zypper addlock` | `brew pin` |
| `unhold` | `apt-mark unhold` | `dnf versionlock delete`¹² | *n/a*² | *n/a*² | `zypper removelock` | `brew unpin` |
| `repo list` | `apt-cache policy` | `dnf repolist` | `pacman-conf --repo-list` | `cat /etc/apk/repositories` | `zypper repos` | `brew tap` |
| `repo add` | `add-apt-repository` | `dnf config-manager --add-repo`¹² | *n/a*² | `tee -a /etc/apk/repositories && apk update`¹³ | `zypper addrepo` | `brew tap` |

| verb | yum | xbps | emerge | port | pkg (FreeBSD) | pkg_add (OpenBSD) | pkgin (NetBSD) |
|---|---|---|---|---|---|---|---|
| `install` | `yum install` | `xbps-install` | `emerge` | `port install` | `pkg install` | `pkg_add` | `pkgin install` |
| `install <file>`⁷ | `yum install ./f` | *n/a*² | *n/a*² | *n/a*² | `pkg add` | `pkg_add ./f` | `pkg_add ./f` |
| `remove` | `yum remove` | `xbps-remove` | `--deselect && --depclean` | `port uninstall` | `pkg delete` | `pkg_delete` | `pkgin remove` |
| `purge` | *n/a*² | *n/a*² | *n/a*² | *n/a*² | *n/a*² | `pkg_delete -c` | *n/a*² |
| `search` | `yum search`¹¹ | `xbps-query -Rs`¹¹ | `emerge --search`¹¹ | `port search`¹¹ | `pkg search`¹¹ | `pkg_info -Q`¹¹ | `pkgin search`¹¹ |
| `info` | `yum info` | `xbps-query -RS`⁹ | `emerge --search '%^<pkg>$'` | `port info` | `pkg search -e -f`⁹ | `pkg_info`⁵ | `pkgin pkg-descr`⁹ |
| `refresh` | `yum makecache` | `xbps-install -S` | `emerge --sync` | `port sync` | `pkg update` | *n/a*² | `pkgin update` |
| `upgrade` | `yum update` | `xbps-install -Su` | `--sync && -uDN @world` | `selfupdate && upgrade outdated` | `pkg upgrade` | `pkg_add -u` | `update && full-upgrade` |
| `upgrade <pkg>` | `yum update` | `xbps-query && xbps-install -Su`¹⁰ | `--sync && emerge -1u` | `selfupdate && upgrade` | `pkg upgrade` | `pkg_add -u` | `update && install` |
| `outdated`⁶ | `yum check-update` | `xbps-install -un` | `emerge -puDN @world` | `port outdated` | `pkg version -vRL=` | `pkg_add -un`⁶ | *n/a*² |
| `list` | `rpm -qa` | `xbps-query -l` | `qlist -Iv` | `port installed` | `pkg info` | `pkg_info` | `pkgin list` |
| `list <pkg>` | `rpm -q` | `xbps-query -p pkgver`⁹ | `qlist -Iv`⁹ | `port -q installed \| grep .`⁹ | `pkg info` | `pkg_info -e`⁹ | `pkg_info -e`⁹ |
| `autoremove` | `yum autoremove` | `xbps-remove -o` | `emerge --depclean` | `port uninstall leaves` | `pkg autoremove` | `pkg_delete -a` | `pkgin autoremove` |
| `orphans` | *n/a*² | `xbps-remove -on` | `emerge -p --depclean` | `port echo leaves` | `pkg autoremove --dry-run` | `pkg_delete -an` | `pkgin -n autoremove` |
| `clean` | `yum clean all` | `xbps-remove -O` | `eclean-dist` | `port clean --all` | `pkg clean` | *n/a*² | `pkgin clean` |
| `owns` | `rpm -qf` | `xbps-query -o`⁹ | `qfile` | `port provides` | `pkg which`⁹ | `pkg_info -E`⁹ | `pkg_info -Fe` |
| `files` | `rpm -ql` | `xbps-query -f`⁹ | `qlist` | `port contents` | `pkg info -l` | `pkg_info -L` | `pkgin pkg-content`⁹ |
| `deps` | `yum deplist` | `xbps-query -Rx`⁹ | `equery depgraph --depth=1`⁹ | `port deps` | `pkg rquery '%dn-%dv'`⁹ | `pkg_info -f \| grep @depend` | `pkgin show-deps`⁹ |
| `rdeps` | `repoquery --installed --whatrequires` | `xbps-query -X`⁹ | `equery depends`⁹ | `port dependents` | `pkg info -r` | `pkg_info -R` | `pkgin show-rev-deps`⁹ |
| `hold` | `yum versionlock list` | `xbps-query -H` | *n/a*² | *n/a*² | `pkg lock -l` | *n/a*² | *n/a*² |
| `hold <pkg>` | `yum versionlock add` | `xbps-pkgdb -m hold` | *n/a*² | *n/a*² | `pkg lock` | *n/a*² | *n/a*² |
| `unhold` | `yum versionlock delete` | `xbps-pkgdb -m unhold` | *n/a*² | *n/a*² | `pkg unlock` | *n/a*² | *n/a*² |
| `repo list` | `yum repolist` | `xbps-query -L` | `portageq get_repos /` | *n/a*² | `pkg -vv` | `cat /etc/installurl` | *n/a*² |
| `repo add` | `yum-config-manager --add-repo` | *n/a*² | `eselect repository enable` | *n/a*² | *n/a*² | *n/a*² | *n/a*² |

¹ See [pacman and `refresh`](#pacman-and-refresh) below.
² Exits with code 3 and a one-line explanation of why the operation doesn't
exist there — run it to see the reason.
³ Guarded: the removal runs only when `pacman -Qdtq` succeeds and reports
orphans; otherwise pkx prints a notice and exits 0 (a failed query still
shows pacman's own error on stderr).
⁴ Refused on Arch always, and on openSUSE Tumbleweed (a rolling release) —
see [Upgrading a single package](#upgrading-a-single-package) below.
⁵ Details for installed packages only; OpenBSD has no repo-details command,
so use `pkx search` for repository lookup.
⁶ `outdated` exits **0** when everything is up to date, **100** when
upgrades are available, and anything else is the native tool's error.
`dnf`/`yum check-update` already work that way; for the others pkx passes
the output through untouched while counting the outdated-package lines
(`pacman -Qu`'s exit 1 for "nothing to do" becomes 0). Because the output
goes through a pipe, pkx adds `-o Apt::Cmd::Disable-Script-Warning=1` to
apt (which otherwise warns that it "does not have a stable CLI
interface") and `--verbose` to brew (which otherwise drops the versions).
OpenBSD's `pkg_add -un` is the one exception: its exit status passes
through.
⁷ An operand ending in a package-file extension (`.deb`, `.rpm`, `.apk`,
`.pkg.tar.*`, `.xbps`, `.pkg`, `.tgz`, `.txz`) is a local file; a relative
path gets `./` so apt treats it as a path (apt reads `dir/foo.deb` as package
`dir` from release `foo.deb`), while absolute paths and URLs are passed
as given. pacman, FreeBSD `pkg` and pkgin
need a different command for files, so mixing files and repository names in
one `install` is refused there (exit 3) — run two commands.
⁸ `dpkg-query -W -f='${Package} ${Version} ${db:Status-Status}\n' <pkg> | grep ' installed$'`,
once per package. `dpkg -s` can't be used: it exits 0 for a removed
package whose config files remain (state `rc`).
⁹ These tools accept exactly one package/pattern per call (xbps-query
errors with "too many arguments"), or, given several, answer for any one
of them (`qlist`) or only for what they have in common (`brew deps`,
`brew uses`), so pkx runs them once per operand, joined with `&&`.
¹⁰ `xbps-install -u` would *install* a named package that is missing, so
pkx first checks each one with `xbps-query -p pkgver` (exit 2 if absent).
¹¹ Several search terms mean *all* of them, everywhere. apt-cache and
pacman already work that way; for the rest pkx searches for the first term
and keeps only results that also contain the others, as plain text and
ignoring case (`… | grep -i -F -e <term>`, or an awk filter over whole
result blocks for port and emerge). So `pkx search lib c++` finds the C++
libraries everywhere; only the first term is passed to the native search,
which treats it the native way (a regex for some tools).
¹² dnf5 (Fedora 41+) spells two of these differently, and pkx picks the
form by asking `dnf --version` (Fedora 39/40 can have a separate `dnf5`
binary installed while `dnf` is still dnf4): `dnf repoquery
--providers-of=requires` and `dnf config-manager addrepo
--from-repofile=<url>`. dnf4 needs dnf-plugins-core for `config-manager`
and python3-dnf-plugin-versionlock for `versionlock` (yum:
yum-plugin-versionlock). `repo add` takes the URL of a `.repo` file.
¹³ See [Adding a repository on Alpine](#adding-a-repository-on-alpine).

Some mappings call a standard helper that isn't always installed —
`pactree` (pacman-contrib), `equery`/`eclean-dist` (gentoolkit),
`qlist`/`qfile` (portage-utils), `eselect repository`
(eselect-repository), `repoquery`/`yum-config-manager` (yum-utils),
`add-apt-repository` (software-properties-common). pkx checks before
running and names the package to install (for `eselect repository`, it
checks that eselect has the module, not just that eselect exists).

## Notes by manager and command

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
(`install`, `remove`, `purge`, `refresh`, `upgrade`, `autoremove`, `clean`,
`hold <pkg>`, `unhold`, `repo add`); queries — `search`, `info`, `list`,
`outdated`, `orphans`, `owns`, `files`, `deps`, `rdeps`, `hold` without
operands, `repo list` — always run unprivileged.

### Gentoo

`list`, `owns` and `files` use `qlist`/`qfile` from **portage-utils**;
`clean`, `deps` and `rdeps` use `eclean-dist`/`equery` from **gentoolkit**;
`repo add` uses **eselect-repository** — the standard Gentoo admin tools.
If one is missing, pkx checks the leading binary before running and tells
you which tool to install rather than failing mid-command; `pkx -n <verb>`
shows you what would have run.

`info` is `emerge --search '%^<pkg>$'`: an exact-name match (the `%` makes
the key a regex, anchored by pkx) that prints the description, homepage,
license and the latest available and installed versions. Use a
`category/name` operand to pick one when a name exists in several
categories; pkx then adds emerge's `@` prefix (`'%@^<category/name>$'`),
which asks for a category/name match explicitly (current portage also
infers it from the `/`; older releases need the prefix).

### Rolling releases and legacy tools

`pkx upgrade` on openSUSE **Tumbleweed** uses `zypper dist-upgrade` (`dup`),
the correct path for a rolling release; Leap and SLES get `zypper update`.
pkx picks between them from `/etc/os-release`.

`pkx autoremove` on **yum** uses `yum autoremove`, which exists on yum ≥ 3.4.3
(RHEL/CentOS 7+). On the much older yum of RHEL/CentOS 6 there is no
`autoremove`, and the command will report that.

#### Adding a repository on Alpine

apk has no command for adding a repository: repositories are simply lines in
`/etc/apk/repositories`. So `pkx repo add <url>` appends the line (only if it
isn't there already, so re-running it is harmless) and then runs
`apk update`, because apk can't use a repository until its index has been
fetched:

```
$ pkx repo add https://dl-cdn.alpinelinux.org/alpine/edge/testing testing
pkx: running: if grep -qxF -e '@testing https://…/edge/testing' /etc/apk/repositories; then …; else printf '%s\n' '@testing https://…/edge/testing' | sudo tee -a /etc/apk/repositories; fi && sudo apk update
```

The optional name makes it a **tagged repository** (`@testing <url>`), apk's
way of adding a repository without letting it take over: its packages are
installed only when asked for explicitly, as `pkx install hyfetch@testing`;
a plain `pkx install hyfetch` reports the package as "masked in: @testing".
Without a name, the repository is an ordinary one and its packages are
candidates for every install and upgrade — usually not what you want for
edge/testing on a stable release. A third-party repository also needs its
signing key in `/etc/apk/keys/`, or `apk update` reports it as untrusted.

`pkx clean` on **Alpine** runs `apk cache clean`. With no local package
cache configured (the default on minimal installs and the official Docker
image), apk-tools 2.x errors — apk itself telling you there is nothing to
clean — while apk-tools 3.x treats it as a quiet no-op (verified on
Alpine 3.24 / apk 3.0.6).

`pkx upgrade` on **Debian/Ubuntu** joins the two steps with `;` rather than
`&&`: `apt-get update` exits non-zero on a benign partial refresh (one dead
PPA) even though the usable lists updated, and blocking security upgrades
on that would be worse than proceeding.

`pkx owns <file>` works best with a **full path** (`pkx owns /usr/bin/vim`).
dpkg and pacman resolve bare names, but `rpm -qf`, MacPorts, FreeBSD `pkg
which` and xbps need the real path — and xbps in particular matches
patterns silently, so a bare name simply produces no output.

`pkx autoremove` on **Arch** prints a small shell conditional as the command
it runs — that's pkx's own guard (remove only if the query found orphans),
since bare `pacman -Rns` with no targets errors. The pacman parts inside
it are the real commands.

`pkx install` on **Arch** passes `--needed`, so an already-installed
package is skipped (as apt, dnf and apk do) rather than reinstalled.

On **OpenBSD**, `-y` maps to `pkg_add -I` / `pkg_delete -I`, which force
non-interactive mode there. (NetBSD's `pkg_add -I` means "skip install
scripts", but NetBSD goes through pkgin, whose `-y` is used instead.)

**Declined prompts at a terminal:** if you answer "n" yourself, xbps still
exits 0 (apt, pacman and dnf exit 1). Without a terminal pkx requires `-y`
instead (see [Using pkx in scripts](../README.md#using-pkx-in-scripts)). pkgin's `-y` does not
cover `autoremove`, which still asks.

`pkx orphans` on **Arch** passes `pacman -Qdt`'s exit status through, which
is 1 when there are no orphans.

On **Termux**, pkx maps to apt and skips the not-running-as-root warning:
Termux is rootless by design.

**Image-based and declarative systems** (Fedora Silverblue's rpm-ostree,
openSUSE MicroOS's transactional-update, NixOS) are deliberately out of
scope — mutating them per-package doesn't fit the verb model. pkx detects
them and points you at the native command instead of a bare failure.

**PATH and escalation:** pkx resolves manager binaries via your `PATH` and
relies on `sudo`'s `secure_path` (default on) for the escalated command.
If you use `PKX_SUDO="sudo -E"` or a `doas` config that keeps the
environment, make sure your `PATH` contains no world-writable or relative
entries.

### `remove` and `purge`

`remove` always uninstalls the named packages and never deletes
configuration files you edited. `purge` also deletes those, and is refused
(exit 3, with the native alternative) where the manager has no such
operation. Whether no-longer-needed dependencies leave with the package is
the manager's own policy — run `pkx orphans` / `pkx autoremove` afterwards
for the same end state everywhere.

| Manager | `remove` | dependencies | `purge` |
|---|---|---|---|
| apt | keeps all config files | stay (autoremove) | `apt-get purge` deletes config files |
| dnf | edited config saved as `.rpmsave` | removed if unneeded | refused: rpm has no purge |
| yum, zypper | edited config saved as `.rpmsave` | stay | refused: rpm has no purge |
| pacman | edited config saved as `.pacsave` (`-Rs`) | removed if unneeded | `pacman -Rns` deletes them too |
| apk | edited config kept | removed if unneeded | refused: apk-tools has no purge |
| xbps, pkg | edited config kept | stay (autoremove) | refused |
| emerge | edited config kept (CONFIG_PROTECT) | removed if unneeded (`--depclean`) | refused |
| brew, port | — | stay (autoremove) | refused |
| pkg_add | edited config kept | stay (autoremove) | `pkg_delete -c` |
| pkgin | edited config kept; **also removes packages that depend on it** | stay | refused |

### Upgrading a single package

`pkx upgrade <pkg>` refreshes the package index (exactly like the
no-argument form, so a stale index can never hide the newest version) and
then upgrades only the named packages, using each manager's explicit
upgrade command — `brew upgrade`, `dnf upgrade`, `xbps-install -Su <pkg>`,
`apt-get install --only-upgrade`, and so on. `pkx install <pkg>` is not a
reliable substitute: on xbps and OpenBSD's `pkg_add` installing an
already-installed package is a no-op, and on the others "install also
upgrades" is incidental behavior rather than the command's contract.

**Refused on rolling releases** (exit 3): upgrading one package on Arch, or
on openSUSE Tumbleweed, is a
[partial upgrade](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported),
which can break the system, so pkx points you at `pkx upgrade`
(`pacman -Syu` / `zypper dist-upgrade`) instead — the same fail-loudly rule
as `refresh`.

**Gentoo and NetBSD caveat:** portage and pkgin have no upgrade-only
primitive, so `emerge --oneshot --update <pkg>` and `pkgin install <pkg>`
also *install* the package when it is missing. xbps would too, so there pkx
checks that each package is installed first. Everywhere else an absent
package is not installed: apt reports it, dnf fails, and apk silently does
nothing (exit 0). (`--oneshot` keeps an upgraded Gentoo
dependency out of the @world set, so `pkx autoremove` can still reclaim it.)

### One verb, one meaning

`refresh` only updates the index. `upgrade` with no arguments refreshes and
then upgrades everything (a compound command where the native tool needs one
— dry-run shows exactly what will execute, e.g.
`apt-get update; apt-get dist-upgrade`); with arguments it upgrades just
those packages.

## Related tools

| Tool | Difference from pkx |
|---|---|
| [pacapt](https://github.com/icy/pacapt) | Shell script, but uses pacman's `-Syu` flag syntax and leans on bash; pkx is verb-based and pure POSIX |
| [pacaptr](https://github.com/rami3l/pacaptr) | Polished Rust binary, pacman syntax; needs the right binary per platform/arch |
| [upt](https://github.com/sigoden/upt) | Verb-based Rust binary; same per-arch install problem |
| [sysget](https://github.com/emilengler/sysget) | Verb-based C++; dormant |

pkx's niche: obvious verbs + a single `curl`-able POSIX file that runs
anywhere `/bin/sh` exists + teaching mode.
