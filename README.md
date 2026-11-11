# pkx

One set of commands to install and manage software on Linux, macOS and BSD.

## Description

pkx lets you use the same commands to manage software on every system. You
type a pkx command. pkx finds your system's package manager, shows you the
native command it will run, and runs it.

```
$ pkx install htop
pkx: running: sudo apt-get install htop
```

On Fedora, the same `pkx install htop` runs `sudo dnf install htop`. On a Mac,
it runs `brew install htop`.

What pkx does for you:

- **Finds your package manager.** You don't need to know whether the system
  uses apt, dnf, pacman or something else.
- **Shows you the real command.** Each time, pkx prints the native command
  before running it, so you learn it as you go. Use `-q` to hide it, or `-n`
  to see it without running anything.
- **Asks for administrator rights only when needed.** pkx adds `sudo` (or
  `doas`) to commands that change the system, and never to commands that
  only look things up.
- **Refuses rather than guesses.** If a package manager has no safe way to do
  what you asked, pkx stops and explains why. For example, on Arch Linux it
  refuses to update the package index on its own, because that can leave the
  system half-updated.
- **Is one small file.** pkx is a single shell script with no dependencies.
  It runs anywhere `/bin/sh` runs.

pkx works with these package managers:

| System | Package manager |
|---|---|
| Debian, Ubuntu, Linux Mint | apt |
| Fedora, RHEL, Rocky Linux, AlmaLinux | dnf (older systems: yum) |
| Arch Linux, Manjaro | pacman |
| Alpine Linux | apk |
| openSUSE, SLES | zypper |
| Void Linux | xbps |
| Gentoo | emerge (Portage) |
| macOS | Homebrew (brew) or MacPorts (port) |
| FreeBSD, DragonFly BSD | pkg |
| OpenBSD | pkg_add |
| NetBSD | pkgin |

For the exact native command behind every pkx command on every system, see
[docs/managers.md](docs/managers.md).

## Installation

You need:

- a Unix-like system with one of the package managers listed above
- `curl` or `wget`

### Install pkx

1. Download pkx into `/usr/local/bin` and make it executable:

   ```sh
   sudo curl -fsSL https://raw.githubusercontent.com/ethanpil/pkx/main/pkx -o /usr/local/bin/pkx
   sudo chmod +x /usr/local/bin/pkx
   ```

   With `wget` instead of `curl`:

   ```sh
   sudo wget -qO /usr/local/bin/pkx https://raw.githubusercontent.com/ethanpil/pkx/main/pkx
   sudo chmod +x /usr/local/bin/pkx
   ```

2. Check that it works:

   ```sh
   pkx which
   ```

   This shows the package manager pkx found and the native command for each
   pkx command.

To install without administrator rights, put the file in a folder on your
`PATH` that you own, such as `~/.local/bin`, and leave out `sudo`.

### Install a specific release

Replace `main` in the download address with a release tag, such as `v0.4.0`.
Each release's SHA-256 checksum is listed in [CHANGELOG.md](CHANGELOG.md).

This README describes the current version on `main`. Release 0.4.0 does not
have `purge`, the read-only `orphans`, `deps`, `rdeps`, `hold`, `unhold`,
`repo` or `completion`.

### Update or remove pkx

- **Update:** run the download command again.
- **Remove:** delete the file: `sudo rm /usr/local/bin/pkx`

### Turn on tab completion (optional)

Add one line to your shell's startup file:

| Shell | Add this line | To this file |
|---|---|---|
| bash | `eval "$(pkx completion bash)"` | `~/.bashrc` |
| zsh | `eval "$(pkx completion zsh)"` (after `compinit`) | `~/.zshrc` |
| fish | `pkx completion fish \| source` | `~/.config/fish/config.fish` |

Tab completion then fills in pkx commands, options and manager names.

## Command reference

### How to read this reference

Every command has this form:

```
pkx [options] <command> [arguments]
```

- `<package>` means you must give at least one package name.
- `[package]` means a package name is optional.
- `...` means you can give more than one.

To see what any command runs on your system, use `pkx help <command>`:

```
$ pkx help search
Usage: pkx search <term>...

Search the repositories (results match all terms)
Aliases: s, -s, se, find

On this system (apt, auto-detected):
  search         apt-cache search <term>
```

Terms used in this reference:

- **Package**: a piece of software your package manager can install.
- **Repository**: a server or folder that packages are installed from.
- **Package index**: the local list of which packages and versions your
  repositories offer. Your package manager downloads it from the
  repositories.
- **Dependency**: a package that another package needs in order to work.
- **Unneeded dependency**: a package that was installed only as a dependency
  and that nothing needs any more.

### Command summary

| Command | What it does |
|---|---|
| [`install`](#install) | Install packages |
| [`remove`](#remove) | Uninstall packages, keeping config files you edited |
| [`purge`](#purge) | Uninstall packages and delete their config files |
| [`autoremove`](#autoremove) | Remove unneeded dependencies |
| [`orphans`](#orphans) | List unneeded dependencies, without removing them |
| [`search`](#search) | Search the repositories |
| [`info`](#info) | Show details about a package |
| [`list`](#list) | List installed packages, or check whether packages are installed |
| [`owns`](#owns) | Show which package a file belongs to |
| [`files`](#files) | List the files a package installed |
| [`deps`](#deps) | List what a package depends on |
| [`rdeps`](#rdeps) | List installed packages that depend on a package |
| [`refresh`](#refresh) | Update the package index only |
| [`upgrade`](#upgrade) | Update the package index, then upgrade packages |
| [`outdated`](#outdated) | List packages that have upgrades available |
| [`hold`](#hold) | Keep packages at their current version, or list held packages |
| [`unhold`](#unhold) | Let held packages upgrade again |
| [`repo`](#repo) | List repositories, or add one |
| [`clean`](#clean) | Delete downloaded package files from the cache |
| [`which`](#which) | Show the package manager pkx found and what each command runs |
| [`help`](#help) | Show help for pkx or for one command |
| [`version`](#version) | Show the pkx version |
| [`completion`](#completion) | Print a tab-completion script for your shell |
| [`raw`](#raw) | Pass arguments straight to the package manager |

### Install and remove software

#### install

`pkx install <package>...`

Installs packages from your repositories, or from package files you
downloaded.

```sh
pkx install htop
pkx install git curl tmux
pkx install ./zoom_amd64.deb
```

- A name ending in a package file extension, such as `.deb`, `.rpm`, `.apk`
  or `.pkg.tar.zst`, is treated as a file on your computer.
- On Arch, FreeBSD and NetBSD, install package files and repository
  packages with separate commands.
- Void, Gentoo, Homebrew and MacPorts cannot install package files. pkx
  tells you the native alternative.
- Other names for this command: `i`, `in`, `add`, `-i`

#### remove

`pkx remove <package>...`

Uninstalls packages. Config files you changed are kept.

```sh
pkx remove htop
```

- Some package managers also remove dependencies that are no longer
  needed; others leave them. Run `pkx autoremove` afterwards to get the
  same result everywhere.
- On NetBSD, pkgin also removes packages that depend on the one you remove.
- Other names for this command: `r`, `rm`, `uninstall`, `del`, `-r`

#### purge

`pkx purge <package>...`

Uninstalls packages and deletes their config files, including ones you
changed.

```sh
pkx purge nginx
```

- Works with apt, pacman and OpenBSD's pkg_add. Other package managers have
  no purge operation; pkx tells you what to do instead.

#### autoremove

`pkx autoremove`

Removes unneeded dependencies.

```sh
pkx orphans      # see what would be removed
pkx autoremove   # remove it
```

#### orphans

`pkx orphans`

Lists unneeded dependencies. Removes nothing.

```sh
pkx orphans
```

- Other name for this command: `unneeded`

### Find information

#### search

`pkx search <term>...`

Searches the repositories. With more than one term, every result matches
all of the terms.

```sh
pkx search htop
pkx search terminal emulator
```

- Other names for this command: `s`, `se`, `find`, `-s`

#### info

`pkx info <package>...`

Shows details about a package, such as its version and description.

```sh
pkx info curl
```

- Other name for this command: `show`

#### list

`pkx list [package]...`

With no package names, lists every installed package. With package names,
checks whether those packages are installed.

```sh
pkx list
pkx list git curl
```

- When you give package names, pkx exits with code 0 only if every one of
  them is installed. This makes it useful in scripts:

  ```sh
  pkx -q list git || pkx -y install git
  ```

- Other names for this command: `l`, `ls`, `installed`, `-l`

#### owns

`pkx owns <file>...`

Shows which installed package a file belongs to.

```sh
pkx owns /usr/bin/vim
```

- Give the full path to the file. Some package managers cannot find a file
  from its name alone.
- Other name for this command: `owner`

#### files

`pkx files <package>...`

Lists the files an installed package put on your system.

```sh
pkx files tmux
```

- Other name for this command: `contents`

#### deps

`pkx deps <package>...`

Lists the packages a package depends on.

```sh
pkx deps curl
```

- Other name for this command: `depends`

#### rdeps

`pkx rdeps <package>...`

Lists the installed packages that depend on a package. Use it to see what
would break if you removed that package.

```sh
pkx rdeps openssl
```

- Other name for this command: `rdepends`

### Keep software up to date

#### refresh

`pkx refresh`

Updates the package index. Installs and upgrades nothing.

```sh
pkx refresh
```

- On Arch Linux, pkx refuses this command, because updating the package
  index without upgrading can break the system. Use `pkx upgrade` instead.

#### upgrade

`pkx upgrade [package]...`

Updates the package index, then upgrades packages. With no package names,
upgrades everything. With package names, upgrades only those packages.

```sh
pkx upgrade
pkx upgrade firefox
```

- On Arch Linux and openSUSE Tumbleweed, pkx refuses to upgrade single
  packages, because a partial upgrade can break these systems. Upgrade
  everything instead.
- On Gentoo and NetBSD, upgrading a named package also installs it if it is
  missing.
- Other names for this command: `u`, `up`, `-u`

#### outdated

`pkx outdated`

Lists installed packages that have newer versions available.

```sh
pkx outdated
```

- Exit code 0 means everything is up to date. Exit code 100 means upgrades
  are available:

  ```sh
  pkx -q outdated > /dev/null
  if [ $? -eq 100 ]; then echo "Upgrades are available"; fi
  ```

- Other name for this command: `updates`

### Control versions and sources

#### hold

`pkx hold [package]...`

Keeps packages at their current version, so upgrades skip them. With no
package names, lists the packages you are holding.

```sh
pkx hold nginx
pkx hold
```

- Works with apt, dnf, yum, zypper, xbps, Homebrew and FreeBSD's pkg. On
  other systems, pkx tells you the native way to do it.
- Other names for this command: `pin`, `lock`

#### unhold

`pkx unhold <package>...`

Lets held packages upgrade again.

```sh
pkx unhold nginx
```

- Other names for this command: `unpin`, `unlock`

#### repo

`pkx repo` or `pkx repo list`: lists your repositories.

`pkx repo add <source> [name]`: adds a repository.

Write the source the way your package manager expects it:

```sh
pkx repo                                                               # list repositories
pkx repo add ppa:deadsnakes/ppa                                        # Ubuntu (PPA)
pkx repo add https://download.docker.com/linux/fedora/docker-ce.repo  # Fedora (.repo file)
pkx repo add hashicorp/tap                                             # Homebrew (tap)
pkx repo add https://dl-cdn.alpinelinux.org/alpine/edge/testing testing  # Alpine
```

- On Alpine, the name is optional. With a name, packages from that
  repository are installed only when you ask for them by name, as in
  `pkx install hyfetch@testing`.
- A repository from a third party may also need its signing key installed.
- Listing works with every package manager except MacPorts and NetBSD's
  pkgin. Adding works with apt, dnf, yum, apk, zypper, emerge and Homebrew.
- Other name for this command: `repos`

### Free up disk space

#### clean

`pkx clean`

Deletes downloaded package files from the package manager's cache.

```sh
pkx clean
```

- Other name for this command: `cleanup`

### pkx itself

#### which

`pkx which [command]`

Shows the package manager pkx found, how it gets administrator rights, and
the native command for each pkx command. With a command name, shows only
that command.

```sh
pkx which
pkx which upgrade
```

#### help

`pkx help [command]`

Shows general help, or help for one command, including the native command
it runs on your system. `pkx <command> --help` does the same.

```sh
pkx help
pkx help upgrade
pkx upgrade --help
```

#### version

`pkx version`

Shows the pkx version. `pkx -V` does the same.

#### completion

`pkx completion bash|zsh|fish`

Prints a tab-completion script for your shell. See
[Turn on tab completion](#turn-on-tab-completion-optional).

```sh
pkx completion fish > ~/.config/fish/completions/pkx.fish
```

#### raw

`pkx raw <arguments>`

Passes the arguments to your package manager without changing them. Use it
for anything pkx has no command for.

```sh
pkx raw -Qi bash        # on Arch, runs: pacman -Qi bash
sudo pkx raw autoclean  # on Debian, runs: apt-get autoclean
```

- pkx does not add `sudo` to `raw` commands. Add it yourself if needed.
- Put pkx's own options before `raw`. Everything after `raw` goes to the
  package manager.
- On Debian and Ubuntu, `raw` uses `apt-get`, not `apt`.
- Not available for xbps and OpenBSD, which split their commands across
  several programs. Run those programs directly.

### Options

| Option | What it does |
|---|---|
| `-y`, `--yes` | Answer "yes" to the package manager's questions |
| `-n`, `--dry-run` | Show the native command, but do not run it |
| `-q`, `--quiet` | Do not show the native command before running it |
| `--via <manager>` | Use this package manager instead of the one pkx finds |
| `-h`, `--help` | Show help (with a command: help for that command) |
| `-V`, `--version` | Show the pkx version |

- You can put options before or after the command: `pkx -y install htop`
  and `pkx install htop -y` do the same thing.
- You can combine one-letter options: `pkx -yq upgrade`.
- To pass a package name that starts with `-`, put `--` before it:
  `pkx remove -- -oddname`.

#### Short command names

The one-letter names `i`, `r`, `s`, `l` and `u` also work as options. These
all install htop:

```sh
pkx install htop
pkx i htop
pkx -i htop
pkx -yi htop     # install, and answer yes to questions
```

You can't use a command name and a command option together: `pkx search -i
htop` is an error. To install a package whose name is a pkx command, put
`--` before it: `pkx -i -- search`.

#### Why there is no `update` command

"Update" means different things to different package managers: apt and
Homebrew use it to update the package index, while dnf and zypper use it to
upgrade packages. So pkx has no `update` command. Use `pkx refresh` to
update the package index, or `pkx upgrade` to upgrade packages.

### Environment variables

| Variable | What it does |
|---|---|
| `PKX_MANAGER` | Use this package manager, like `--via`. Example: `PKX_MANAGER=apt` |
| `PKX_SUDO` | The command pkx uses to get administrator rights. By default pkx uses `sudo`, or `doas` if `sudo` is not installed, and nothing when you are already root. Set it to an empty value (`PKX_SUDO=`) to never add one. |
| `PKX_QUIET` | Set to `1` to always hide the native command, like `-q` |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | No supported package manager was found, or a tool the command needs is not installed. pkx names the missing tool and, for common helper tools, the package that provides it. |
| 2 | The command was typed incorrectly, or `-y` is needed (see [Using pkx in scripts](#using-pkx-in-scripts)) |
| 3 | Your package manager has no safe way to do this. pkx explains why and, where possible, what to do instead. |
| 100 | From `pkx outdated` only: upgrades are available |
| Any other code | The package manager's own exit code |

### Using pkx in scripts

When pkx runs without a terminal, as in a script, a Dockerfile or a CI job,
nobody can answer the package manager's questions. In that case pkx refuses
any command that might ask one, and exits with code 2, unless you give `-y`.
This stops a script from carrying on when nothing was actually installed.

```sh
pkx -y install git curl
pkx -y upgrade
```

Commands that only look things up, such as `search` or `list`, never need
`-y`. Package managers that never ask questions (apk, emerge, Homebrew and
OpenBSD's pkg_add) don't need it either.

Two exit codes are designed for scripts:

- `pkx list <package>...` exits with code 0 only if every package is
  installed.
- `pkx outdated` exits with code 0 when everything is up to date, and 100
  when upgrades are available.

## More information

- [docs/managers.md](docs/managers.md): the native command behind every pkx
  command on every package manager, and notes on each system
- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [CONTRIBUTING.md](CONTRIBUTING.md): how to run the tests
- License: [MIT](LICENSE)
