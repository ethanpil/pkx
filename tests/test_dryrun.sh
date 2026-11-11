#!/bin/sh
# Dry-run assertion suite for pkx.
#
# Runs on any host: PKX_MANAGER forces the manager, PKX_SUDO=sudo makes
# escalation deterministic, and -n prints the native command instead of
# executing it — so no real package managers are needed.
#
# Usage:  sh tests/test_dryrun.sh
# Env:    PKX_SH   shell used to run pkx (default: sh),
#                  e.g. PKX_SH="busybox sh" or PKX_SH="bash --posix"

# Don't inherit a caller's exported IFS: the harness word-splits $PKX_SH
# and relies on default splitting throughout.
unset IFS

PKX=${PKX:-$(dirname "$0")/../pkx}
PKX_SH=${PKX_SH:-sh}

pass=0
fail=0

# run pkx under the chosen shell with a forced manager
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
run_pkx() {
    mgr=$1; shift
    PKX_MANAGER=$mgr PKX_SUDO=sudo $PKX_SH "$PKX" "$@"
}

# ok <mgr> <expected native command> <pkx args...>
ok() {
    mgr=$1; expected=$2; shift 2
    got=$(run_pkx "$mgr" -n "$@" 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ "$got" = "$expected" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL [$mgr] pkx $*"
        printf '  expected: %s\n' "$expected"
        printf '  got (rc=%s): %s\n' "$rc" "$got"
    fi
}

# no <mgr> <reason-substring> <pkx args...>  — expect exit code 3
# (unsupported) AND the refusal message to contain the substring, so a
# wrong or swapped UNSUP text cannot pass vacuously.
no() {
    mgr=$1; want=$2; shift 2
    got=$(run_pkx "$mgr" -n "$@" 2>&1); rc=$?
    case "$got" in
        *"$want"*) msg_ok=1 ;;
        *)         msg_ok=0 ;;
    esac
    if [ "$rc" -eq 3 ] && [ "$msg_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL [$mgr] pkx $* — expected exit 3 with '$want', got rc=$rc: $got"
    fi
}

# err <pkx args...>  — expect exit code 2 (usage error), no manager needed.
# -n and </dev/null are safety rails: if a validation path ever regresses,
# the invocation prints a command (rc 0 -> clean FAIL) instead of actually
# executing a package operation or hanging on a prompt in CI.
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
err() {
    got=$(PKX_MANAGER=apt PKX_SUDO=sudo $PKX_SH "$PKX" -n "$@" </dev/null 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL pkx $* — expected exit 2, got rc=$rc: $got"
    fi
}

# --- apt -------------------------------------------------------------------
ok apt "sudo apt-get install foo"                                install foo
ok apt "sudo apt-get install -y foo bar"                         install -y foo bar
ok apt "sudo apt-get remove foo"                                 remove foo
ok apt "apt-cache search foo"                                    search foo
ok apt "apt-cache show foo"                                      info foo
ok apt "sudo apt-get update"                                     refresh
ok apt "sudo apt-get update; sudo apt-get dist-upgrade"        upgrade
ok apt "sudo apt-get update; sudo apt-get dist-upgrade -y"     upgrade -y
ok apt "apt list --installed"                                    list
ok apt "sudo apt-get autoremove"                                 autoremove
ok apt "sudo apt-get clean"                                      clean
ok apt "dpkg -S /bin/ls"                                         owns /bin/ls
ok apt "dpkg -L foo"                                             files foo
ok apt "apt-get moo"                                             raw -- moo

# --- dnf -------------------------------------------------------------------
ok dnf "sudo dnf install foo"                                    install foo
ok dnf "sudo dnf install -y foo"                                 install -y foo
ok dnf "sudo dnf remove foo"                                     remove foo
ok dnf "dnf search foo"                                          search foo
ok dnf "dnf info foo"                                            info foo
ok dnf "sudo dnf makecache"                                      refresh
ok dnf "sudo dnf upgrade --refresh"                              upgrade
ok dnf "sudo dnf upgrade --refresh -y"                           upgrade -y
ok dnf "rpm -qa"                                                 list
ok dnf "sudo dnf autoremove"                                     autoremove
ok dnf "sudo dnf clean all"                                      clean
ok dnf "rpm -qf /bin/ls"                                         owns /bin/ls
ok dnf "rpm -ql foo"                                             files foo

# --- yum -------------------------------------------------------------------
ok yum "sudo yum install foo"                                    install foo
ok yum "sudo yum install -y foo"                                 install -y foo
ok yum "sudo yum remove foo"                                     remove foo
ok yum "yum search foo"                                          search foo
ok yum "yum info foo"                                            info foo
ok yum "sudo yum makecache"                                      refresh
ok yum "sudo yum update"                                         upgrade
ok yum "rpm -qa"                                                 list
ok yum "sudo yum autoremove"                                     autoremove
ok yum "sudo yum clean all"                                      clean
ok yum "rpm -qf /bin/ls"                                         owns /bin/ls
ok yum "rpm -ql foo"                                             files foo

# --- pacman ----------------------------------------------------------------
ok pacman "sudo pacman -S --needed foo"                                   install foo
ok pacman "sudo pacman -S --needed --noconfirm foo"                       install -y foo
ok pacman "sudo pacman -Rs foo"                                  remove foo
ok pacman "pacman -Ss foo"                                       search foo
ok pacman "pacman -Si foo"                                       info foo
no pacman "partial upgrade" refresh
ok pacman "sudo pacman -Syu"                                     upgrade
ok pacman "sudo pacman -Syu --noconfirm"                         upgrade -y
ok pacman "pacman -Q"                                            list
ok pacman "if orphans=\$(pacman -Qdtq); then sudo pacman -Rns \$orphans; else echo 'pkx: no orphaned packages to remove'; fi" autoremove
ok pacman "sudo pacman -Sc"                                      clean
ok pacman "pacman -Qo /bin/ls"                                   owns /bin/ls
ok pacman "pacman -Ql foo"                                       files foo
ok pacman "pacman -Syu"                                          raw -- -Syu

# --- apk -------------------------------------------------------------------
ok apk "sudo apk add foo"                                        install foo
ok apk "sudo apk del foo"                                        remove foo
ok apk "apk search foo"                                          search foo
ok apk "apk search -e -v foo"                                    info foo
ok apk "sudo apk update"                                         refresh
ok apk "sudo apk update && sudo apk upgrade"                     upgrade
ok apk "apk list --installed"                                    list
no apk "automatically" autoremove
ok apk "sudo apk cache clean"                                    clean
ok apk "apk info --who-owns /bin/ls"                             owns /bin/ls
ok apk "apk info -L foo"                                         files foo

# --- zypper ----------------------------------------------------------------
ok zypper "sudo zypper install foo"                              install foo
ok zypper "sudo zypper --non-interactive install foo"            install -y foo
ok zypper "sudo zypper remove foo"                               remove foo
ok zypper "zypper search foo"                                    search foo
ok zypper "zypper info foo"                                      info foo
ok zypper "sudo zypper refresh"                                  refresh
# zypper upgrade output depends on the host's /etc/os-release (Tumbleweed
# uses dist-upgrade / refuses single-package); skip on Tumbleweed hosts.
if grep -qi tumbleweed /etc/os-release 2>/dev/null; then
    echo "skip: zypper upgrade assertions (Tumbleweed host)"
else
    ok zypper "sudo zypper refresh && sudo zypper update"        upgrade
fi
ok zypper "zypper search --installed-only"                       list
no zypper "clean-deps" autoremove
ok zypper "sudo zypper clean --all"                              clean
ok zypper "rpm -qf /bin/ls"                                      owns /bin/ls
ok zypper "rpm -ql foo"                                          files foo

# --- xbps ------------------------------------------------------------------
ok xbps "sudo xbps-install foo"                                  install foo
ok xbps "sudo xbps-install -y foo"                               install -y foo
ok xbps "sudo xbps-remove foo"                                   remove foo
ok xbps "xbps-query -Rs foo"                                     search foo
ok xbps "xbps-query -RS foo"                                     info foo
ok xbps "sudo xbps-install -S"                                   refresh
ok xbps "sudo xbps-install -Su"                                  upgrade
ok xbps "xbps-query -l"                                          list
ok xbps "sudo xbps-remove -o"                                    autoremove
ok xbps "sudo xbps-remove -O"                                    clean
ok xbps "xbps-query -o /bin/ls"                                  owns /bin/ls
ok xbps "xbps-query -f foo"                                      files foo
no xbps "xbps-install" raw -- foo

# --- emerge ----------------------------------------------------------------
ok emerge "sudo emerge foo"                                      install foo
ok emerge "sudo emerge --deselect foo && sudo emerge --depclean foo" remove foo
ok emerge "emerge --search foo"                                  search foo
ok emerge "emerge --pretend --verbose foo"                       info foo
ok emerge "sudo emerge --sync"                                   refresh
ok emerge "sudo emerge --sync && sudo emerge --update --deep --newuse @world" upgrade
ok emerge "qlist -Iv"                                            list
ok emerge "sudo emerge --depclean"                               autoremove
ok emerge "sudo eclean-dist"                                     clean
ok emerge "qfile /bin/ls"                                        owns /bin/ls
ok emerge "qlist foo"                                            files foo

# --- brew (never sudo) -----------------------------------------------------
ok brew "brew install foo"                                       install foo
ok brew "brew uninstall foo"                                     remove foo
ok brew "brew search foo"                                        search foo
ok brew "brew info foo"                                          info foo
ok brew "brew update"                                            refresh
ok brew "brew update && brew upgrade"                            upgrade
ok brew "brew list --versions"                                   list
ok brew "brew autoremove"                                        autoremove
ok brew "brew cleanup"                                           clean
no brew "cannot map" owns /bin/ls
ok brew "brew list --verbose foo"                                files foo

# --- port ------------------------------------------------------------------
ok port "sudo port install foo"                                  install foo
ok port "sudo port -N install foo"                               install -y foo
ok port "sudo port uninstall foo"                                remove foo
ok port "port search foo"                                        search foo
ok port "port info foo"                                          info foo
ok port "sudo port sync"                                         refresh
ok port "sudo port selfupdate && sudo port upgrade outdated"     upgrade
ok port "port installed"                                         list
ok port "sudo port uninstall leaves"                             autoremove
ok port "sudo port clean --all installed"                        clean
ok port "port provides /bin/ls"                                  owns /bin/ls
ok port "port contents foo"                                      files foo

# --- pkg (FreeBSD) ---------------------------------------------------------
ok pkg "sudo pkg install foo"                                    install foo
ok pkg "sudo pkg install -y foo"                                 install -y foo
ok pkg "sudo pkg delete foo"                                     remove foo
ok pkg "pkg search foo"                                          search foo
ok pkg "pkg search -e -f foo"                                    info foo
ok pkg "sudo pkg update"                                         refresh
ok pkg "sudo pkg upgrade"                                        upgrade
ok pkg "pkg info"                                                list
ok pkg "sudo pkg autoremove"                                     autoremove
ok pkg "sudo pkg clean"                                          clean
ok pkg "pkg which /bin/ls"                                       owns /bin/ls
ok pkg "pkg info -l foo"                                         files foo

# --- pkg_add (OpenBSD) -----------------------------------------------------
ok pkg_add "sudo pkg_add foo"                                    install foo
ok pkg_add "sudo pkg_add -I foo"                                 install -y foo
ok pkg_add "sudo pkg_delete -I foo"                              remove -y foo
ok pkg_add "sudo pkg_add -I -u"                                  upgrade -y
ok pkg_add "sudo pkg_delete -I -a"                               autoremove -y
ok pkg_add "sudo pkg_delete foo"                                 remove foo
ok pkg_add "pkg_info -Q foo"                                     search foo
ok pkg_add "pkg_info foo"                                        info foo
no pkg_add "index refresh" refresh
ok pkg_add "sudo pkg_add -u"                                     upgrade
ok pkg_add "pkg_info"                                            list
ok pkg_add "sudo pkg_delete -a"                                  autoremove
no pkg_add "no package cache" clean
ok pkg_add "pkg_info -E /bin/ls"                                 owns /bin/ls
ok pkg_add "pkg_info -L foo"                                     files foo
no pkg_add "separate tools" raw -- foo

# --- pkgin (NetBSD) --------------------------------------------------------
ok pkgin "sudo pkgin install foo"                                install foo
ok pkgin "sudo pkgin -y install foo"                             install -y foo
ok pkgin "sudo pkgin remove foo"                                 remove foo
ok pkgin "pkgin search foo"                                      search foo
ok pkgin "pkgin pkg-descr foo"                                   info foo
ok pkgin "sudo pkgin update"                                     refresh
ok pkgin "sudo pkgin update && sudo pkgin full-upgrade"          upgrade
ok pkgin "pkgin list"                                            list
ok pkgin "sudo pkgin autoremove"                                 autoremove
ok pkgin "sudo pkgin clean"                                      clean
ok pkgin "pkg_info -Fe /bin/ls"                                  owns /bin/ls
ok pkgin "pkgin pkg-content foo"                                 files foo

# --- aliases ---------------------------------------------------------------
ok apt "sudo apt-get install foo"                                in foo
ok apt "sudo apt-get remove foo"                                 rm foo
ok apt "apt-cache search foo"                                    se foo
ok apt "sudo apt-get update; sudo apt-get dist-upgrade"        up
ok apt "apt list --installed"                                    list

# --- flag placement and forms ----------------------------------------------
ok apt "sudo apt-get install -y foo"                             install foo -y
ok apt "sudo apt-get install -y foo"                             -y install foo
ok pacman "sudo pacman -S --needed foo"                                   --via pacman install foo
ok pacman "sudo pacman -S --needed foo"                                   --via=arch install foo

# --- end-of-options (--) ----------------------------------------------------
# A dashed operand now also gets a native '--' so the tool sees a name.
ok apt "sudo apt-get remove -- -foo"                             remove -- -foo
ok apt "dpkg -S -- -x"                                           owns -- -x
ok apt "sudo apt-get install -y bar"                             -y install -- bar
ok pacman "sudo pacman -S --needed -- -foo"                               install -- -foo

# --- single-package upgrade (pkx upgrade <pkg>) -----------------------------
# The single-package form refreshes the index first, exactly like the
# no-argument form (the zypper case is asserted for the Leap path; a
# Tumbleweed host would refuse, like pacman).
ok apt     "sudo apt-get update; sudo apt-get install --only-upgrade foo" upgrade foo
ok apt     "sudo apt-get update; sudo apt-get install --only-upgrade -y foo" upgrade -y foo
ok dnf     "sudo dnf upgrade --refresh foo"             upgrade foo
ok dnf     "sudo dnf upgrade --refresh -y foo"          upgrade -y foo
ok yum     "sudo yum update foo"                        upgrade foo
ok yum     "sudo yum update -y foo"                     upgrade -y foo
no pacman "single-package upgrade"                         upgrade foo
ok apk     "sudo apk update && sudo apk upgrade foo"    upgrade foo
if ! grep -qi tumbleweed /etc/os-release 2>/dev/null; then
    ok zypper "sudo zypper refresh && sudo zypper update foo" upgrade foo
    ok zypper "sudo zypper refresh && sudo zypper --non-interactive update foo" upgrade -y foo
fi
# xbps would install a missing package, so each one is checked first
ok xbps    "xbps-query -p pkgver foo && sudo xbps-install -Su foo" upgrade foo
ok xbps    "xbps-query -p pkgver foo && sudo xbps-install -Su -y foo" upgrade -y foo
ok xbps    "xbps-query -p pkgver foo && xbps-query -p pkgver bar && sudo xbps-install -Su foo bar" upgrade foo bar
ok emerge  "sudo emerge --sync && sudo emerge --oneshot --update foo" upgrade foo
ok brew    "brew update && brew upgrade foo"            upgrade foo
ok brew    "brew update && brew upgrade foo bar"        upgrade foo bar
ok port    "sudo port selfupdate && sudo port upgrade foo" upgrade foo
ok port    "sudo port selfupdate && sudo port -N upgrade foo" upgrade -y foo
ok pkg     "sudo pkg upgrade foo"                       upgrade foo
ok pkg     "sudo pkg upgrade -y foo"                    upgrade -y foo
ok pkg_add "sudo pkg_add -u foo"                        upgrade foo
ok pkgin   "sudo pkgin update && sudo pkgin install foo" upgrade foo
ok pkgin   "sudo pkgin update && sudo pkgin -y install foo" upgrade -y foo
ok apt     "sudo apt-get update; sudo apt-get install --only-upgrade foo bar" upgrade foo bar
ok apt     "sudo apt-get update; sudo apt-get install --only-upgrade foo" up foo
ok apt     "sudo apt-get update; sudo apt-get install --only-upgrade foo" upgrade -- foo

# --- outdated (list upgradable, read-only, no sudo) --------------------------
ok apt     "apt list --upgradable"                       outdated
ok dnf     "dnf check-update"                            outdated
ok yum     "yum check-update"                            outdated
ok pacman  "pacman -Qu"                                  outdated
ok apk     "apk list -u"                                 outdated
ok zypper  "zypper list-updates"                         outdated
ok xbps    "xbps-install -un"                            outdated
ok emerge  "emerge --pretend --update --deep --newuse @world" outdated
ok brew    "brew outdated"                               outdated
ok port    "port outdated"                               outdated
ok pkg     "pkg version -vRL="                           outdated
ok pkg_add "pkg_add -un"                                 outdated
no pkgin   "full-upgrade"                                outdated

# --- list <pkg> (is this package installed? exit 0 = all installed) ------
# apt checks the status field: 'dpkg -s' exits 0 for a removed package whose
# config files remain. Tools whose check takes one argument run per operand.
APTQ="dpkg-query -W -f='\${Package} \${Version} \${db:Status-Status}\\n'"
ok apt     "$APTQ foo | grep ' installed\$'"            list foo
ok apt     "$APTQ foo | grep ' installed\$' && $APTQ bar | grep ' installed\$'" list foo bar
ok dnf     "rpm -q foo"                                  list foo
ok yum     "rpm -q foo"                                  list foo
ok pacman  "pacman -Q foo"                               list foo
ok apk     "apk info -e foo"                             list foo
ok zypper  "rpm -q foo"                                  list foo
ok xbps    "xbps-query -p pkgver foo"                    list foo
ok xbps    "xbps-query -p pkgver foo && xbps-query -p pkgver bar" list foo bar
ok emerge  "qlist -Iv foo"                               list foo
ok brew    "brew list --versions foo"                    list foo
ok port    "port -q installed foo | grep ."              list foo
ok port    "port -q installed foo | grep . && port -q installed bar | grep ." list foo bar
ok pkg     "pkg info foo"                                list foo
ok pkg_add "pkg_info -e foo"                             list foo
ok pkg_add "pkg_info -e foo && pkg_info -e bar"          list foo bar
ok pkgin   "pkg_info -e foo"                             list foo
# 'installed' is an alias of list (with and without operands)
ok dnf     "rpm -q foo"                                  installed foo
ok dnf     "rpm -qa"                                     installed

# --- single-argument tools run once per operand ------------------------------
ok xbps    "xbps-query -Rs foo | grep -i -e bar"         search foo bar
ok xbps    "xbps-query -RS foo && xbps-query -RS bar"    info foo bar
ok xbps    "xbps-query -f foo && xbps-query -f bar"      files foo bar
ok xbps    "xbps-query -o /a && xbps-query -o /b"        owns /a /b
ok pkg     "pkg search foo | grep -i -e bar"             search foo bar
ok pkg     "pkg search -e -f foo && pkg search -e -f bar" info foo bar
ok pkg     "pkg which /a && pkg which /b"                owns /a /b
ok pkg_add "pkg_info -Q foo | grep -i -e bar"           search foo bar
ok pkg_add "pkg_info -E /a && pkg_info -E /b"            owns /a /b
ok pkgin   "pkgin search foo | grep -i -e bar"           search foo bar
ok pkgin   "pkgin pkg-descr foo && pkgin pkg-descr bar"  info foo bar
ok pkgin   "pkgin pkg-content foo && pkgin pkg-content bar" files foo bar
ok xbps    "xbps-query -RS -- -foo"                      info -- -foo
ok xbps    "xbps-query -RS 'a b'"                        info "a b"

# --- local package files (install) ------------------------------------------
ok apt     "sudo apt-get install ./foo.deb"              install foo.deb
ok apt     "sudo apt-get install /tmp/foo.deb bar"       install /tmp/foo.deb bar
ok dnf     "sudo dnf install ./foo.rpm"                  install foo.rpm
ok zypper  "sudo zypper install ./foo.rpm"               install foo.rpm
ok apk     "sudo apk add ./foo.apk"                      install foo.apk
ok pacman  "sudo pacman -U ./foo.pkg.tar.zst"            install foo.pkg.tar.zst
ok pacman  "sudo pacman -U --noconfirm ./a.pkg.tar.zst /b.pkg.tar.xz" install -y ./a.pkg.tar.zst /b.pkg.tar.xz
no pacman  "another for the repository"                                    install ./foo.pkg.tar.zst vim
ok pkg     "sudo pkg add ./foo.pkg"                      install foo.pkg
no pkg     "another for the repository"                                    install foo.pkg vim
ok pkg_add "sudo pkg_add ./foo.tgz"                      install foo.tgz
ok pkgin   "sudo pkg_add ./foo.tgz"                      install foo.tgz
no xbps    "xbps-rindex"                                 install foo.xbps
no emerge  "ebuilds"                                     install foo.tgz
no brew    "installer -pkg"                              install foo.pkg
no port    "installer -pkg"                              install foo.pkg
ok apt     "sudo apt-get install ./-x.deb"               install -- -x.deb

# --- generic raw path for more managers -------------------------------------
ok dnf    "dnf history"                                          raw -- history
ok zypper "zypper repos"                                         raw -- repos
ok brew   "brew doctor"                                          raw -- doctor
ok pkgin  "pkgin stats"                                          raw -- stats

# --- multi-operand owns/files ------------------------------------------------
ok apt "dpkg -S /bin/ls /bin/cp"                                 owns /bin/ls /bin/cp
ok apt "dpkg -L foo bar"                                         files foo bar

# --- operand quoting (safe eval) -------------------------------------------
ok apt "apt-cache show 'perl(URI)'"          info "perl(URI)"
ok apk "sudo apk add 'foo>=1.0'"             install "foo>=1.0"
ok apt "dpkg -S '/Applications/My App/bin'"  owns "/Applications/My App/bin"
ok apt "sudo apt-get install 'a; reboot'"    install "a; reboot"
ok apt "sudo apt-get install foo bar"        install foo bar
ok apt "sudo apt-get install 'a b' c"        install "a b" c
ok apt "sudo apt-get install 'it'\\''s'"     install "it's"

# --- PKX_SUDO override ------------------------------------------------------
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
got=$(PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -n install foo 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$got" = "apt-get install foo" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL PKX_SUDO= install — expected 'apt-get install foo', got (rc=$rc): $got"
fi
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
got=$(PKX_MANAGER=apt PKX_SUDO=doas $PKX_SH "$PKX" -n install foo 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$got" = "doas apt-get install foo" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL PKX_SUDO=doas install — expected 'doas apt-get install foo', got (rc=$rc): $got"
fi

# --- which ------------------------------------------------------------------
got=$(run_pkx apt which 2>&1); rc=$?
case "$got" in
    *"apt-get install"*)
        if [ "$rc" -eq 0 ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1)); echo "FAIL which rc=$rc"
        fi ;;
    *) fail=$((fail + 1)); echo "FAIL which — output missing 'apt-get install': $got" ;;
esac
# which must show the single-package upgrade mapping...
case "$got" in
    *"upgrade <pkg>"*"--only-upgrade"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL which — missing 'upgrade <pkg>' row: $got" ;;
esac
# ...and its refusal on pacman
got=$(run_pkx pacman which 2>&1)
case "$got" in
    *"upgrade <pkg>"*"not supported"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL which pacman — missing upgrade <pkg> refusal: $got" ;;
esac
# single-verb lookup: only the requested rows, no header
got=$(run_pkx apt which upgrade 2>&1); rc=$?
case "$got" in
    *"--only-upgrade"*)
        case "$got" in
            *"apt-cache search"*|*"manager:"*)
                fail=$((fail + 1)); echo "FAIL which upgrade — unfiltered output: $got" ;;
            *)
                if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL which upgrade rc=$rc"; fi ;;
        esac ;;
    *) fail=$((fail + 1)); echo "FAIL which upgrade — missing single-package row: $got" ;;
esac
# aliases resolve in the filter, and the full table shows the alias line
got=$(run_pkx apt which ls 2>&1)
case "$got" in
    *"apt list --installed"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL which ls — got: $got" ;;
esac
# which accepts aliases, rejects meta-commands, and shows raw
got=$(run_pkx apt which installed 2>&1)
case "$got" in
    *"apt list --installed"*"dpkg-query"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL which installed — got: $got" ;;
esac
got=$(run_pkx pacman which raw 2>&1)
case "$got" in
    *"pacman <args>"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL which raw — got: $got" ;;
esac
err which help

# --- version ----------------------------------------------------------------
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
got=$($PKX_SH "$PKX" -V 2>&1); rc=$?
case "$got" in
    "pkx "*)
        if [ "$rc" -eq 0 ]; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1)); echo "FAIL -V rc=$rc"
        fi ;;
    *) fail=$((fail + 1)); echo "FAIL -V — got: $got" ;;
esac

# --- usage errors (exit 2) ---------------------------------------------------
err
err bogusverb
err install
err --via bogus install foo
err --badflag install foo
err raw
err upgrade ""
err install ""
err which foo
err -V install foo
err version foo
err help install remove
err update
err help update
err which update
err search -i foo
err -i search foo
err -s -i foo
err -si foo
err -x install foo
err -yx install foo
err -
err --bogus
err refresh foo
err --via "" install foo
err --via= install foo

# --- help / version verbs ----------------------------------------------------
# shellcheck disable=SC2086
got=$($PKX_SH "$PKX" help 2>&1); rc=$?
case "$got" in
    *"Usage: pkx"*)
        if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL help rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL help — no usage text: $got" ;;
esac
# shellcheck disable=SC2086
got=$($PKX_SH "$PKX" -h 2>&1); rc=$?
case "$got" in
    *"Usage: pkx"*)
        if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL -h rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL -h — no usage text: $got" ;;
esac
# shellcheck disable=SC2086
got=$($PKX_SH "$PKX" version 2>&1); rc=$?
case "$got" in
    "pkx "*)
        if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL version rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL version — got: $got" ;;
esac

# --- purge (remove + config files) and what remove does ---------------------
ok apt     "sudo apt-get purge foo"                      purge foo
ok apt     "sudo apt-get purge -y foo"                   purge -y foo
ok pacman  "sudo pacman -Rns foo"                        purge foo
ok pkg_add "sudo pkg_delete -c foo"                      purge foo
ok pkg_add "sudo pkg_delete -I -c foo"                   purge -y foo
no dnf     ".rpmsave"                                    purge foo
no yum     ".rpmsave"                                    purge foo
no zypper  ".rpmsave"                                    purge foo
no apk     "no purge"                                    purge foo
no xbps    "config files you edited"                     purge foo
no emerge  "CONFIG_PROTECT"                              purge foo
no brew    "zap"                                         purge foo
no port    "no purge"                                    purge foo
no pkg     "config files you edited"                     purge foo
no pkgin   "config files you edited"                     purge foo
err purge

# --- orphans (list only, never removes, never sudo) ---------------------------
ok apt     "apt-get --simulate autoremove"               orphans
ok dnf     "dnf repoquery --unneeded"                    orphans
no yum     "pkx autoremove"                              orphans
ok pacman  "pacman -Qdt"                                 orphans
no apk     "never any"                                   orphans
ok zypper  "zypper packages --unneeded"                  orphans
ok xbps    "xbps-remove -on"                             orphans
ok emerge  "emerge --pretend --depclean"                 orphans
ok brew    "brew autoremove --dry-run"                   orphans
ok port    "port echo leaves"                            orphans
ok pkg     "pkg autoremove --dry-run"                    orphans
ok pkg_add "pkg_delete -an"                              orphans
ok pkgin   "pkgin -n autoremove"                         orphans
err orphans foo

# --- deps / rdeps ------------------------------------------------------------
ok apt     "apt-cache depends foo"                       deps foo
ok apt     "apt-cache rdepends --installed foo"          rdeps foo
ok dnf     "dnf repoquery --installed --whatrequires foo" rdeps foo
ok yum     "yum deplist foo"                             deps foo
ok yum     "repoquery --installed --whatrequires foo"    rdeps foo
ok pacman  "pactree -s -d1 -u foo && pactree -s -d1 -u bar" deps foo bar
ok pacman  "pactree -r -d1 -u foo"                       rdeps foo
ok apk     "apk info -R foo"                             deps foo
ok apk     "apk info -r foo"                             rdeps foo
ok zypper  "zypper info --requires foo"                  deps foo
ok zypper  "zypper search --installed-only --requires-pkg foo" rdeps foo
ok xbps    "xbps-query -Rx foo && xbps-query -Rx bar"    deps foo bar
ok xbps    "xbps-query -X foo"                           rdeps foo
ok emerge  "equery depgraph --depth=1 foo"               deps foo
ok emerge  "equery depends foo"                          rdeps foo
ok brew    "brew deps foo"                               deps foo
ok brew    "brew uses --installed foo"                   rdeps foo
ok port    "port deps foo"                               deps foo
ok port    "port dependents foo"                         rdeps foo
ok pkg     "pkg rquery '%dn-%dv' foo"                    deps foo
ok pkg     "pkg info -r foo"                             rdeps foo
ok pkg_add "pkg_info -f foo | grep '^@depend'"           deps foo
ok pkg_add "pkg_info -R foo"                             rdeps foo
ok pkgin   "pkgin show-deps foo"                         deps foo
ok pkgin   "pkgin show-rev-deps foo"                     rdeps foo
err deps
err rdeps

# --- hold / unhold (hold with no operands lists, without sudo) ---------------
ok apt     "sudo apt-mark hold foo"                      hold foo
ok apt     "apt-mark showhold"                           hold
ok apt     "sudo apt-mark unhold foo"                    unhold foo
ok dnf     "sudo dnf versionlock add foo"                hold foo
ok dnf     "dnf versionlock list"                        hold
ok dnf     "sudo dnf versionlock delete foo"             unhold foo
ok yum     "sudo yum versionlock add foo"                hold foo
ok zypper  "sudo zypper addlock foo"                     hold foo
ok zypper  "zypper locks"                                hold
ok zypper  "sudo zypper removelock foo"                  unhold foo
ok xbps    "sudo xbps-pkgdb -m hold foo"                 hold foo
ok xbps    "xbps-query -H"                               hold
ok xbps    "sudo xbps-pkgdb -m unhold foo"               unhold foo
ok brew    "brew pin foo"                                hold foo
ok brew    "brew list --pinned"                          hold
ok brew    "brew unpin foo"                              unhold foo
ok pkg     "sudo pkg lock foo"                           hold foo
ok pkg     "sudo pkg lock -y foo"                        hold -y foo
ok pkg     "pkg lock -l"                                 hold
ok pkg     "sudo pkg unlock foo"                         unhold foo
no pacman  "IgnorePkg"                                   hold foo
no pacman  "IgnorePkg"                                   unhold foo
no apk     "world constraints"                           hold foo
no emerge  "package.mask"                                hold foo
no port    "cannot hold"                                 hold foo
no pkg_add "cannot hold"                                 hold foo
no pkgin   "cannot hold"                                 hold foo
err unhold

# --- repo list / repo add ------------------------------------------------------
ok apt     "apt-cache policy"                            repo
ok apt     "apt-cache policy"                            repo list
ok apt     "apt-cache policy"                            repos
ok apt     "sudo add-apt-repository ppa:a/b"             repo add ppa:a/b
ok apt     "sudo add-apt-repository -y ppa:a/b"          repo add -y ppa:a/b
no apt     "drop the name"                               repo add ppa:a/b name
ok dnf     "dnf repolist"                                repo
ok dnf     "sudo dnf config-manager --add-repo https://x/y.repo" repo add https://x/y.repo
ok yum     "sudo yum-config-manager --add-repo https://x/y.repo" repo add https://x/y.repo
ok pacman  "pacman-conf --repo-list"                     repo
no pacman  "pacman.conf"                                 repo add https://x
ok apk     "cat /etc/apk/repositories"                   repo
ok apk     "printf '%s\\n' https://x/main | sudo tee -a /etc/apk/repositories" repo add https://x/main
ok zypper  "zypper repos"                                repo
ok zypper  "sudo zypper addrepo https://x/r myrepo"      repo add https://x/r myrepo
ok xbps    "xbps-query -L"                               repo
no xbps    "/etc/xbps.d"                                 repo add https://x
ok emerge  "portageq get_repos /"                        repo
ok emerge  "sudo eselect repository enable guru"         repo add guru
ok brew    "brew tap"                                    repo
ok brew    "brew tap user/tap https://x/y"               repo add user/tap https://x/y
no port    "sources.conf"                                repo
ok pkg     "pkg -vv"                                     repo
no pkg     "/usr/local/etc/pkg/repos"                    repo add https://x
ok pkg_add "cat /etc/installurl"                         repo
no pkgin   "repositories.conf"                           repo
err repo add
err repo add a b c
err repo list foo
err repo bogus

# --- search: several terms always mean "all of them" -------------------------
# apt-cache and pacman already AND their terms; elsewhere pkx searches the
# first term and keeps results matching the rest.
ok apt     "apt-cache search foo bar"                    search foo bar
ok pacman  "pacman -Ss foo bar"                          search foo bar
ok apk     "apk search foo | grep -i -e bar | grep -i -e baz" search foo bar baz
ok dnf     "dnf search foo | grep -i -e bar"             search foo bar
ok zypper  "zypper search foo | grep -i -e bar"          search foo bar
ok brew    "brew search foo | grep -i -e bar"            search foo bar
ok port    "port search foo | awk -v RS= -v ORS='\\n\\n' -v t=bar 'tolower(\$0) ~ tolower(t)'" search foo bar
ok emerge  "emerge --search foo | awk -v RS= -v ORS='\\n\\n' -v t=bar 'tolower(\$0) ~ tolower(t)'" search foo bar
ok apk     "apk search foo | grep -i -e 'a b'"           search foo "a b"
ok apk     "apk search -- -foo | grep -i -e -bar"        search -- -foo -bar
ok apk     "apk search foo"                              search foo

# --- remove keeps edited config files everywhere; Arch included -------------
ok pacman  "sudo pacman -Rs --noconfirm foo"             remove -y foo

# --- aliases: every accepted spelling maps to its command --------------------
# (word aliases, then the one-letter ones, which also work as flags)
for pair in install:i install:in install:add remove:r remove:rm \
            remove:uninstall remove:del search:s search:se search:find \
            info:show list:l list:ls list:installed outdated:updates \
            upgrade:u upgrade:up orphans:unneeded clean:cleanup \
            owns:owner files:contents deps:depends rdeps:rdepends \
            hold:pin hold:lock unhold:unpin unhold:unlock repo:repos; do
    v=${pair%%:*}; al=${pair#*:}
    case $v in
        install|remove|search|info|files|deps|rdeps|hold|unhold) args=foo ;;
        owns) args=/bin/ls ;;
        *) args="" ;;
    esac
    # shellcheck disable=SC2086  # $args is intentionally split (0 or 1 word)
    want=$(run_pkx apt -n "$v" $args 2>&1)
    # shellcheck disable=SC2086
    ok apt "$want" "$al" $args
    if [ "${#al}" -eq 1 ]; then
        # shellcheck disable=SC2086
        ok apt "$want" "-$al" $args
    fi
done

# --- command flags, bundling, and conflicts ---------------------------------
ok apt "sudo apt-get install -y foo"                     -yi foo
ok apt "sudo apt-get install -y foo"                     -iy foo
ok apt "apt-cache search foo"                            foo -s
ok apt "sudo apt-get install search"                     -i -- search
ok apt "sudo apt-get install -y foo"                     -yq install foo
ok apt "sudo apt-get install foo"                        -i -i foo
ok apt "sudo apt-get install -- -foo"                    -i -- -foo

# --- raw: everything after the command is verbatim ---------------------------
ok pacman "pacman -S -- -foo"                            raw -S -- -foo
ok pacman "pacman -S -- -foo"                            raw -- -S -- -foo
ok pacman "pacman -Syu"                                  raw -Syu
ok pacman "pacman -n -i -s"                              raw -n -i -s
ok pacman "sudo pacman -S --needed raw"                           -i -- raw
err -i raw

# --- help for one command ------------------------------------------------------
# shellcheck disable=SC2086
got=$(PKX_MANAGER=apt PKX_SUDO=sudo $PKX_SH "$PKX" help search 2>&1); rc=$?
case "$got" in
    *"Usage: pkx search"*"Aliases: s, -s, se, find"*"apt-cache search <term>"*)
        if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL help search rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL help search — got: $got" ;;
esac
# '<command> --help' and '-h <command>' show the same, and run nothing
for form in "search --help" "-h search" "se -h" "-sh"; do
    # shellcheck disable=SC2086
    got2=$(PKX_MANAGER=apt PKX_SUDO=sudo $PKX_SH "$PKX" $form foo </dev/null 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && [ "$got2" = "$got" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1)); echo "FAIL pkx $form foo — rc=$rc got: $got2"
    fi
done
# A PATH with the shell and the utilities pkx needs but no package
# manager, to exercise "nothing detected".
N=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/pkxnomgr.$$")
mkdir -p "$N"
# shellcheck disable=SC2086
set -- $PKX_SH
for b in "$1" sed tr id uname cat; do
    ln -s "$(command -v "$b")" "$N/$b" 2>/dev/null
done
set --
# help works (without a mapping) even when no manager can be found
# shellcheck disable=SC2086
got=$(PKX_SUDO=sudo PKX_OS_RELEASE=/nonexistent PATH=$N $PKX_SH "$PKX" help install 2>&1); rc=$?
case "$got" in
    *"Usage: pkx install"*"no supported package manager"*)
        if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL help without manager rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL help without manager — got: $got" ;;
esac
# the alias table in the main help is generated from the same data
# shellcheck disable=SC2086
got=$($PKX_SH "$PKX" help 2>&1)
case "$got" in
    *"Aliases:"*"install     i in add"*"orphans     unneeded"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL help — alias table: $got" ;;
esac
# usage errors win over a missing manager (exit 2, not 1)
# shellcheck disable=SC2086
PKX_OS_RELEASE=/nonexistent PATH=$N $PKX_SH "$PKX" list "" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL usage-before-detection rc=$rc"; fi
# ...and a valid request with nothing detected is exit 1
# shellcheck disable=SC2086
PKX_OS_RELEASE=/nonexistent PATH=$N $PKX_SH "$PKX" list >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL no-manager rc=$rc"; fi
rm -rf "$N"

# --- detection: os-release names the native manager --------------------------
# Stubs for several managers share one PATH; os-release must decide, so a
# Debian box with apk-tools or pacman installed (for chroots) still gets apt.
D=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/pkxdet.$$")
mkdir -p "$D/bin"
for b in apt-get apk pacman dnf yum zypper xbps-install; do
    printf '#!/bin/sh\nexit 0\n' > "$D/bin/$b"; chmod +x "$D/bin/$b"
done
# hermetic PATH: the stubs plus only what pkx itself needs, so a real
# manager on the test host cannot influence detection
# shellcheck disable=SC2086
set -- $PKX_SH
for b in "$1" sed tr id uname cat; do
    ln -s "$(command -v "$b")" "$D/bin/$b" 2>/dev/null
done
set --
# detect <expected mgr> <os-release contents>
detect() {
    printf '%s\n' "$2" > "$D/os-release"
    # shellcheck disable=SC2086
    got=$(PATH="$D/bin" PKX_OS_RELEASE="$D/os-release" PKX_SUDO=sudo \
          $PKX_SH "$PKX" which 2>&1 | sed -n 's/^manager: *\([^ ]*\).*/\1/p')
    if [ "$got" = "$1" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1)); echo "FAIL detect '$2' — expected $1, got '$got'"
    fi
}
detect apt    'ID=debian'
detect apt    'ID=linuxmint
ID_LIKE="ubuntu debian"'
detect apk    'ID=alpine'
detect pacman 'ID=endeavouros
ID_LIKE=arch'
detect dnf    'ID="rocky"
ID_LIKE="rhel centos fedora"'
detect zypper 'ID="opensuse-tumbleweed"
ID_LIKE="opensuse suse"'
detect xbps   'ID=void'
rm -f "$D/bin/dnf"
detect yum    'ID="centos"'
# unknown distro: fall back to probing binaries (apt-get first)
detect apt    'ID=somethingelse'
rm -f "$D/bin/apt-get" "$D/bin/yum" "$D/bin/pacman" "$D/bin/zypper"
detect apk    'ID=somethingelse'
rm -rf "$D"

# --- zypper on Tumbleweed (os-release driven) --------------------------------
TW=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/pkxtw.$$")
printf 'ID="opensuse-tumbleweed"\nNAME="openSUSE Tumbleweed"\n' > "$TW"
# shellcheck disable=SC2086
got=$(PKX_OS_RELEASE="$TW" PKX_MANAGER=zypper PKX_SUDO=sudo $PKX_SH "$PKX" -n upgrade 2>&1)
if [ "$got" = "sudo zypper refresh && sudo zypper dist-upgrade" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL zypper Tumbleweed upgrade — got: $got"
fi
# shellcheck disable=SC2086
got=$(PKX_OS_RELEASE="$TW" PKX_MANAGER=zypper PKX_SUDO=sudo $PKX_SH "$PKX" -n upgrade foo 2>&1); rc=$?
case "$got" in
    *"single-package upgrade"*"Tumbleweed"*)
        if [ "$rc" -eq 3 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL zypper TW single rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL zypper Tumbleweed single-package — got: $got" ;;
esac
printf 'ID="opensuse-leap"\n' > "$TW"
# shellcheck disable=SC2086
got=$(PKX_OS_RELEASE="$TW" PKX_MANAGER=zypper PKX_SUDO=sudo $PKX_SH "$PKX" -n upgrade foo 2>&1)
if [ "$got" = "sudo zypper refresh && sudo zypper update foo" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL zypper Leap single-package — got: $got"
fi
rm -f "$TW"

# --- runtime (eval path, via stub binaries) ----------------------------------
# These execute pkx for real against stub package managers in a temp dir,
# covering what dry-run cannot: the teaching line, -q, native exit-code
# passthrough, and the missing-required-binary guard.
T=$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/pkxtest.$$")
mkdir -p "$T"
printf '#!/bin/sh\necho "stub: $*"\nexit 7\n' > "$T/apt-get"
printf '#!/bin/sh\nexit 0\n' > "$T/emerge"
chmod +x "$T/apt-get" "$T/emerge"

# native exit code passes through untouched (stub exits 7)
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -yq install foo </dev/null 2>/dev/null); rc=$?
if [ "$rc" -eq 7 ] && [ "$got" = "stub: install -y foo" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL runtime exit passthrough — rc=$rc got: $got"
fi

# teaching line goes to stderr and names the command; -q suppresses it
# shellcheck disable=SC2086
teach=$(PATH="$T:$PATH" PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -y install foo </dev/null 2>&1 >/dev/null)
case "$teach" in
    *"pkx: running: apt-get install -y foo"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL runtime teaching line — got: $teach" ;;
esac
# shellcheck disable=SC2086
quiet=$(PATH="$T:$PATH" PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -yq install foo </dev/null 2>&1 >/dev/null)
case "$quiet" in
    *"pkx: running:"*) fail=$((fail + 1)); echo "FAIL runtime -q — teaching line not suppressed: $quiet" ;;
    *) pass=$((pass + 1)) ;;
esac

# PKX_QUIET=1 silences; PKX_QUIET=0 does not
# shellcheck disable=SC2086
quiet=$(PATH="$T:$PATH" PKX_QUIET=1 PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -y install foo </dev/null 2>&1 >/dev/null)
case "$quiet" in
    *"pkx: running:"*) fail=$((fail + 1)); echo "FAIL runtime PKX_QUIET=1 — not suppressed: $quiet" ;;
    *) pass=$((pass + 1)) ;;
esac
# shellcheck disable=SC2086
teach=$(PATH="$T:$PATH" PKX_QUIET=0 PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -y install foo </dev/null 2>&1 >/dev/null)
case "$teach" in
    *"pkx: running: apt-get install -y foo"*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL runtime PKX_QUIET=0 — teaching line missing: $teach" ;;
esac

# missing required helper is caught cleanly (emerge present, qlist absent)
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=emerge PKX_SUDO='' $PKX_SH "$PKX" list </dev/null 2>&1); rc=$?
case "$got" in
    *"needs 'qlist'"*)
        if [ "$rc" -eq 1 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL runtime REQ guard rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL runtime REQ guard — got (rc=$rc): $got" ;;
esac

# --- outdated: 0 = up to date, 100 = upgrades available, else the error -----
# Stubs print $STUB_OUT (a file) and exit $STUB_RC.
for b in apt pacman dnf; do
    # shellcheck disable=SC2016  # the stub expands these when it runs
    printf '#!/bin/sh\n[ -n "$STUB_OUT" ] && cat "$STUB_OUT"\nexit "${STUB_RC:-0}"\n' > "$T/$b"
    chmod +x "$T/$b"
done
# outdated_rc <expected rc> <mgr> <stub rc> <stub output...>
outdated_rc() {
    want=$1; mgr=$2; src=$3; shift 3
    printf '%s\n' "$@" > "$T/out"
    [ $# -gt 0 ] || : > "$T/out"
    # shellcheck disable=SC2086
    got=$(PATH="$T:$PATH" STUB_OUT="$T/out" STUB_RC=$src PKX_MANAGER=$mgr PKX_SUDO='' \
          $PKX_SH "$PKX" -q outdated </dev/null 2>/dev/null); rc=$?
    if [ "$rc" -eq "$want" ] && [ "$got" = "$(cat "$T/out")" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1)); echo "FAIL outdated [$mgr stub rc=$src] — expected $want, got rc=$rc out: $got"
    fi
}
outdated_rc 100 apt    0 "Listing..." "foo/stable 2.0 amd64 [upgradable from: 1.0]"
outdated_rc 0   apt    0 "Listing..."
outdated_rc 5   apt    5 "Listing..."
outdated_rc 100 pacman 0 "foo 1.0 -> 2.0"
outdated_rc 0   pacman 1
outdated_rc 100 dnf    100 "foo.x86_64  2.0  updates"
outdated_rc 0   dnf    0

# --- without a terminal, commands that can prompt need -y ---------------------
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" install foo </dev/null 2>&1); rc=$?
case "$got" in
    *"stdin is not a terminal"*"-y"*)
        case "$got" in
            *"stub:"*) fail=$((fail + 1)); echo "FAIL no-tty refusal — the native tool ran: $got" ;;
            *) if [ "$rc" -eq 2 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL no-tty refusal rc=$rc"; fi ;;
        esac ;;
    *) fail=$((fail + 1)); echo "FAIL no-tty refusal — got (rc=$rc): $got" ;;
esac
# read-only commands, and managers that never prompt, are unaffected
printf '#!/bin/sh\necho "stub: $*"\n' > "$T/apk"; chmod +x "$T/apk"
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=apk PKX_SUDO='' $PKX_SH "$PKX" -q install foo </dev/null 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$got" = "stub: add foo" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL apk without -y — rc=$rc got: $got"; fi
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=apt PKX_SUDO='' $PKX_SH "$PKX" -q hold </dev/null 2>&1); rc=$?
case "$got" in
    *"not a terminal"*) fail=$((fail + 1)); echo "FAIL read-only command refused without a terminal: $got" ;;
    *) pass=$((pass + 1)) ;;
esac

# --- dnf5 changed deps and repo add ---------------------------------------------
printf '#!/bin/sh\nexit 0\n' > "$T/dnf5"; chmod +x "$T/dnf5"
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=dnf PKX_SUDO=sudo $PKX_SH "$PKX" -n deps foo 2>&1)
if [ "$got" = "dnf repoquery --providers-of=requires foo" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL dnf5 deps — got: $got"; fi
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=dnf PKX_SUDO=sudo $PKX_SH "$PKX" -n repo add https://x/y.repo 2>&1)
if [ "$got" = "sudo dnf config-manager addrepo --from-repofile=https://x/y.repo" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL dnf5 repo add — got: $got"; fi

# missing helper tools name the package that provides them
printf '#!/bin/sh\nexit 0\n' > "$T/pacman"; chmod +x "$T/pacman"
# shellcheck disable=SC2086
got=$(PATH="$T:$PATH" PKX_MANAGER=pacman PKX_SUDO='' $PKX_SH "$PKX" deps foo </dev/null 2>&1); rc=$?
case "$got" in
    *"needs 'pactree' (from pacman-contrib)"*)
        if [ "$rc" -eq 1 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL pactree hint rc=$rc"; fi ;;
    *) fail=$((fail + 1)); echo "FAIL pactree hint — got (rc=$rc): $got" ;;
esac

rm -rf "$T"

# --- shell completion -----------------------------------------------------------
# Generated from the command table; each script must at least parse in its
# own shell (skipped when that shell is not installed).
for sh_ in bash zsh fish; do
    # shellcheck disable=SC2086
    out=$($PKX_SH "$PKX" completion "$sh_" 2>&1); rc=$?
    case "$out" in
        *"install"*"autoremove"*"orphans"*"repo"*"completion"*)
            if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL completion $sh_ rc=$rc"; fi ;;
        *) fail=$((fail + 1)); echo "FAIL completion $sh_ — commands missing: $out" ;;
    esac
    if command -v "$sh_" >/dev/null 2>&1; then
        if printf '%s\n' "$out" | "$sh_" -n 2>/dev/null; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1)); echo "FAIL completion $sh_ — does not parse"
        fi
    fi
done
if command -v bash >/dev/null 2>&1; then
    C=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/pkxcomp.$$")
    # a bash script (not run by this POSIX harness itself)
    cat > "$C" <<'BASHEOF'
eval "$($PKX_SH "$PKX" completion bash)"
t() { COMP_WORDS=("$@"); COMP_CWORD=$((${#COMP_WORDS[@]} - 1)); COMPREPLY=(); _pkx; echo "${COMPREPLY[*]}"; }
t pkx or; t pkx --via pk; t pkx -y repo ""; t pkx help unh
BASHEOF
    got=$(PKX_SH="$PKX_SH" PKX="$PKX" bash "$C" 2>&1)
    rm -f "$C"
    want="orphans
pkg pkg_add pkgin
list add
unhold"
    if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL bash completion — got: $got"; fi
fi
# the help text shows the command literally (it is in an unquoted heredoc)
# shellcheck disable=SC2086
got=$($PKX_SH "$PKX" help 2>&1)
# shellcheck disable=SC2016  # the literal text, deliberately unexpanded
case "$got" in
    *'eval "$(pkx completion bash)"'*) pass=$((pass + 1)) ;;
    *) fail=$((fail + 1)); echo "FAIL help — completion hint was expanded: $got" ;;
esac
err completion
err completion tcsh
err completion bash zsh

echo
echo "pkx dry-run suite: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
