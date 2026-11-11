# Changelog

## 0.5.0 — unreleased

Verified against real apk 3.0, pacman 7.1, xbps 0.60, apt/dpkg 1.22,
dnf5 5.4 and zypper 1.14 in chroots, in addition to the dry-run suite.

**Changed**

- **`orphans` now only lists** unneeded dependencies; removing them is
  `autoremove`, the name apt, dnf, yum, brew, pkg and pkgin already use.
  In 0.4.0 `orphans` removed them — a script relying on that now gets a
  read-only listing instead, the safe direction for such a change.
- `remove` on Arch is `pacman -Rs` (was `-Rns`), so it keeps config files
  you edited (as `.pacsave`), like `remove` on every other manager; the old
  behavior is the new `purge`.
- Several search terms now mean "all of them" on every manager (they meant
  "any" on apk, zypper and several BSD tools, and errored on xbps).
- `outdated` exits 0 when up to date and 100 when upgrades are available,
  on every manager except OpenBSD (previously each tool's own convention:
  dnf 100, pacman 1-for-none, most others always 0).
- Without a terminal, commands that may prompt require `-y` (exit 2
  otherwise), so a prompt can no longer silently decline — on xbps that
  used to exit 0 having done nothing.
- `installed <pkg>` folded into `list [pkg]...`: no operands lists
  everything, operands check them (exit 0 = all installed). `installed`
  still works as an alias. This also ends the one-typo gap between the
  destructive `install` and the read-only `installed`.
- `pkx <command> --help` / `pkx -h <command>` show that command's help and
  run nothing (previously a usage error). `pkx help <command>` does the same.
- Detection reads `/etc/os-release` first, so a distro's own manager wins
  over other managers installed alongside it (apk-tools, pacman and dnf are
  all packaged for Debian/Ubuntu). Binary probing is now the fallback, with
  apk after the other Linux managers.
- `pkx install` on Arch passes `--needed` (no silent reinstall).

**Added**

- Aliases for every common command (`add`, `uninstall`, `del`, `find`,
  `show`, `ls`, `updates`, `cleanup`, `owner`, `contents`, one-letter `i r s
  l u`), and the one-letter ones as flags: `pkx -s htop`, `pkx -yi htop`.
- Combined short flags (`-yq`).
- `pkx update` explains that it is ambiguous instead of "unknown command".
- Local package files: `pkx install ./foo.pkg.tar.zst` uses `pacman -U`,
  FreeBSD uses `pkg add`, NetBSD `pkg_add`; a bare `foo.deb` gets `./` so
  apt treats it as a path; managers that cannot install files say so.
- `pkx which` also shows the `raw` mapping, and `which`/`help` accept
  aliases.
- `purge <pkg>...` — uninstall and delete config files (apt, pacman,
  OpenBSD; refused with the native alternative elsewhere).
- `orphans` — read-only list of what `autoremove` would remove (11 of 13
  managers; Alpine never has any, and yum can't list them without starting
  a removal).
- `deps <pkg>...` and `rdeps <pkg>...` — what a package depends on, and
  which installed packages depend on it (all 13 managers).
- `hold [pkg]...` / `unhold <pkg>...` — pin packages at their version, or
  list held ones (apt, dnf, yum, zypper, xbps, brew, FreeBSD pkg; refused
  with the native alternative elsewhere).
- `info` on Gentoo is an exact-name `emerge --search` (description,
  homepage, versions) instead of `emerge --pretend --verbose`, which showed
  a build plan rather than package details.
- `repo [list]` and `repo add <source> [name]` — list or add repositories
  (list on 11 managers, add on 7). On Alpine the name makes it a tagged
  repository (`pkg@name`), and the index is fetched right away.
- `pkx completion bash|zsh|fish` — completion scripts generated from the
  command table.
- A missing helper tool is reported with the package that provides it
  (e.g. `pactree` from pacman-contrib).

**Fixed**

- apt: `pkx installed` (now `list <pkg>`) said a removed package with
  leftover config files (dpkg state `rc`) was installed — `dpkg -s` exits 0
  for it.
- xbps: `info`, `search`, `files`, `owns` and `installed` with two or more
  operands failed outright (`xbps-query: too many arguments`); they now run
  once per operand. The same applies to FreeBSD `pkg search`/`pkg which`,
  OpenBSD `pkg_info -Q`/`-E`/`-e`, pkgin `search`/`pkg-descr`/`pkg-content`
  and the MacPorts installed check (where one installed port could vouch
  for another).
- xbps: `pkx upgrade <pkg>` installed the package when it was missing.
- OpenBSD: `-y` maps to `pkg_add -I`/`pkg_delete -I` again — on OpenBSD
  `-I` forces non-interactive mode; 0.2.0 dropped it by confusing it with
  NetBSD's `-I`.
- `raw` dropped a later `--` (`pkx raw -S -- -foo` ran `pacman -S -foo`).
- `PKX_QUIET=0` silenced teaching mode; `0`/`no`/`false`/`off` now don't.
- Usage errors are reported before manager detection, so `pkx list ""` on
  a machine with no manager is exit 2, not 1. `pkx version extra` is a
  usage error instead of ignoring the extra arguments.
- pkgin `outdated` refusal now points at the real preview
  (`pkgin -n full-upgrade`).

## 0.4.0 — 2026-07-16

Release file SHA-256 (`pkx` at tag `v0.4.0`):
`7bff46176a7779025a6341c667aed4fd2091814c4899f9b427264874d9fd1918`

**Added**

- `pkx outdated` — read-only list of packages with available upgrades,
  on 12 of 13 managers (pkgin has no separate listing and says so).
  This restores the most common read-only query, present in the
  original gist as `paccheckforupdates` and dropped in the rewrite.
- `pkx installed <pkg>...` — portable is-it-installed predicate
  (exit 0 = installed), the other query the original gist had
  (`pacinstalled`) that scripts previously had to fake by grepping
  `pkx list`.
- `pkx which <verb>` — look up a single mapping (aliases accepted);
  the full `which` table now also shows the verb aliases.
- `PKX_QUIET` environment variable — persistent `-q`.
- A dashed operand now gets a native `--` end-of-options marker, so
  `pkx remove -- -foo` really does protect the name (raw exempt).
- Release installs are tag-pinned with a published sha256.

**Fixed**

- An explicit but empty `--via` value errors instead of silently
  auto-detecting — a script whose manager variable expanded empty was
  running privileged operations against the wrong manager.
- `-h`/`-V` combined with a command now error; `pkx -V install htop`
  used to print the version and exit 0 with the install silently
  discarded.
- apt upgrades no longer abort on a benign partial index refresh (one
  dead PPA): the update and upgrade steps are joined with `;`, matching
  what apt itself does with stale lists.
- zypper warns instead of silently assuming non-rolling when
  `/etc/os-release` is unreadable (the Tumbleweed check used to fail
  open into a partial upgrade).
- `list` on apt/Alpine is installed-only with versions
  (`apt list --installed`, `apk list --installed`) instead of
  dpkg selections (which include removed-but-not-purged packages) and
  bare names.
- Teaching-mode output strips control bytes, so terminal escape
  sequences in an operand can't repaint the displayed command; the
  shell-quoting safe-set is spelled out so it cannot vary with locale.
- Bare `pkx` prints a two-line hint instead of the full usage dump.
- Termux no longer sees a spurious not-running-as-root warning, and
  image-based systems (rpm-ostree, MicroOS, NixOS) get a pointer to
  their native tool instead of a bare "no manager found".

**Internal**

- CI: sha256-verified pinned shellcheck, actions pinned to commit SHAs,
  superseded runs cancelled, and a macOS job (BSD sed + bash-3.2
  /bin/sh). The test suite grew to 268 assertions and now also
  executes pkx against stub binaries, covering the teaching line, `-q`,
  native exit-code passthrough, and the missing-binary guard; refusal
  messages are asserted by content.

## 0.3.0 — 2026-07-16

**Changed**

- `pkx upgrade <pkg>` now refreshes the package index first, exactly like
  the no-argument form, so a stale index can no longer hide the newest
  version (or fail outright in a fresh container).
- Single-package upgrade is refused on openSUSE Tumbleweed (exit 3) for
  the same partial-upgrade reason it is refused on Arch.
- Gentoo single-package upgrade uses `emerge --oneshot --update`, so an
  upgraded dependency is no longer permanently added to @world.
- Exit 3 now means "operation unsupported by this manager", which covers
  argument-dependent refusals such as single-package upgrade on Arch; the
  refusal message names the operation instead of contradicting itself.

**Fixed**

- Empty operands (e.g. `pkx upgrade ""` from an unset shell variable) are
  rejected with a usage error instead of silently building a nonsense
  native command.
- `pkx which` shows the `upgrade <pkg>` mapping — and its refusal on
  Arch/Tumbleweed — instead of silently omitting the feature.
- The README no longer claims `brew install`/`port install` of an
  installed package is a no-op (it isn't; that claim is true only of
  xbps and OpenBSD's `pkg_add`).
- The pre-run binary check verifies the binary the command actually
  invokes (`dpkg`, `rpm`, `xbps-query`, `pkg_info`, ...) rather than the
  manager's primary binary, restoring the guarantee for every helper-tool
  verb instead of only Gentoo's.
- `info` on FreeBSD uses `pkg search -e -f` (exact match, full output)
  instead of dumping every substring match; on OpenBSD it is `pkg_info`
  again — real details, installed packages only — since OpenBSD has no
  repo-details command.
- `clean` on Alpine emits plain `apk cache clean` again; deciding
  cache-enabledness inside pkx made dry-run/teaching output depend on
  the machine running pkx rather than the manager, and made the test
  suite fail on Alpine itself.
- `pkx help` fits in 80 columns again (the `--via` manager list had
  grown into one 107-column line).

## 0.2.0 — 2026-07-14

**Added**

- `pkx upgrade <pkg>` — upgrade one or more named packages instead of
  everything, using each manager's real single-package upgrade command
  (`brew upgrade`, `dnf upgrade`, `xbps-install -u`,
  `apt-get install --only-upgrade`, …). Previously `upgrade` refused any
  argument and suggested `pkx install <pkg>`, which is a silent no-op on
  Homebrew, MacPorts, xbps and OpenBSD's `pkg_add`. Refused on Arch, where
  a single-package upgrade is an unsupported partial upgrade.
- `--` ends flag parsing, so an operand beginning with `-` can be passed.

**Fixed**

- Operands are shell-quoted, so package specs like `perl(URI)` and
  `foo>=1.0`, paths with spaces, and shell metacharacters are passed
  through literally instead of being re-split, glob-expanded, or executed.
- `remove` on Gentoo scoped `--depclean` to the named package (it removed
  every system-wide orphan).
- `clean` on MacPorts cleared caches instead of uninstalling ports.
- `clean` on Alpine no longer swallows sudo's password prompt or
  misreports real errors, and is a clean no-op when no cache is enabled.
- `orphans` on Arch is a clean no-op when there are none.
- `info` on Alpine, Gentoo, FreeBSD and OpenBSD queries the repositories,
  so it works for packages that are not installed yet.
- `-y` on OpenBSD no longer maps to `pkg_add -I` (which skips install
  scripts rather than assuming yes).
- `clean` on Arch uses `-Sc`, not the far more destructive `-Scc`.
- `upgrade` on openSUSE Tumbleweed uses `dist-upgrade`.
- Verbs that shell out to a helper tool (Gentoo's `qlist`, `qfile`,
  `eclean-dist`) report the missing tool instead of dying with a raw 127.

## 0.1.0 — 2026-07-14

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
