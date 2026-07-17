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
        echo "  expected: $expected"
        echo "  got (rc=$rc): $got"
    fi
}

# no <mgr> <pkx args...>  — expect exit code 3 (unsupported)
no() {
    mgr=$1; shift
    got=$(run_pkx "$mgr" -n "$@" 2>&1); rc=$?
    if [ "$rc" -eq 3 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL [$mgr] pkx $* — expected exit 3, got rc=$rc: $got"
    fi
}

# err <pkx args...>  — expect exit code 2 (usage error), no manager needed
# shellcheck disable=SC2086  # PKX_SH is intentionally word-split
err() {
    got=$(PKX_MANAGER=apt PKX_SUDO=sudo $PKX_SH "$PKX" "$@" 2>&1); rc=$?
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
ok apt "sudo apt-get update && sudo apt-get dist-upgrade"        upgrade
ok apt "sudo apt-get update && sudo apt-get dist-upgrade -y"     upgrade -y
ok apt "dpkg --get-selections"                                   list
ok apt "sudo apt-get autoremove"                                 orphans
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
ok dnf "sudo dnf autoremove"                                     orphans
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
ok yum "sudo yum autoremove"                                     orphans
ok yum "sudo yum clean all"                                      clean
ok yum "rpm -qf /bin/ls"                                         owns /bin/ls
ok yum "rpm -ql foo"                                             files foo

# --- pacman ----------------------------------------------------------------
ok pacman "sudo pacman -S foo"                                   install foo
ok pacman "sudo pacman -S --noconfirm foo"                       install -y foo
ok pacman "sudo pacman -Rns foo"                                 remove foo
ok pacman "pacman -Ss foo"                                       search foo
ok pacman "pacman -Si foo"                                       info foo
no pacman refresh
ok pacman "sudo pacman -Syu"                                     upgrade
ok pacman "sudo pacman -Syu --noconfirm"                         upgrade -y
ok pacman "pacman -Q"                                            list
ok pacman "if orphans=\$(pacman -Qdtq); then sudo pacman -Rns \$orphans; else echo 'pkx: no orphaned packages to remove'; fi" orphans
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
ok apk "apk info"                                                list
no apk orphans
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
ok zypper "sudo zypper refresh && sudo zypper update"            upgrade
ok zypper "zypper search --installed-only"                       list
no zypper orphans
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
ok xbps "sudo xbps-remove -o"                                    orphans
ok xbps "sudo xbps-remove -O"                                    clean
ok xbps "xbps-query -o /bin/ls"                                  owns /bin/ls
ok xbps "xbps-query -f foo"                                      files foo
no xbps raw -- foo

# --- emerge ----------------------------------------------------------------
ok emerge "sudo emerge foo"                                      install foo
ok emerge "sudo emerge --deselect foo && sudo emerge --depclean foo" remove foo
ok emerge "emerge --search foo"                                  search foo
ok emerge "emerge --pretend --verbose foo"                       info foo
ok emerge "sudo emerge --sync"                                   refresh
ok emerge "sudo emerge --sync && sudo emerge --update --deep --newuse @world" upgrade
ok emerge "qlist -Iv"                                            list
ok emerge "sudo emerge --depclean"                               orphans
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
ok brew "brew autoremove"                                        orphans
ok brew "brew cleanup"                                           clean
no brew owns /bin/ls
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
ok port "sudo port uninstall leaves"                             orphans
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
ok pkg "sudo pkg autoremove"                                     orphans
ok pkg "sudo pkg clean"                                          clean
ok pkg "pkg which /bin/ls"                                       owns /bin/ls
ok pkg "pkg info -l foo"                                         files foo

# --- pkg_add (OpenBSD) -----------------------------------------------------
ok pkg_add "sudo pkg_add foo"                                    install foo
ok pkg_add "sudo pkg_add foo"                                    install -y foo
ok pkg_add "sudo pkg_delete foo"                                 remove foo
ok pkg_add "pkg_info -Q foo"                                     search foo
ok pkg_add "pkg_info foo"                                        info foo
no pkg_add refresh
ok pkg_add "sudo pkg_add -u"                                     upgrade
ok pkg_add "pkg_info"                                            list
ok pkg_add "sudo pkg_delete -a"                                  orphans
no pkg_add clean
ok pkg_add "pkg_info -E /bin/ls"                                 owns /bin/ls
ok pkg_add "pkg_info -L foo"                                     files foo
no pkg_add raw -- foo

# --- pkgin (NetBSD) --------------------------------------------------------
ok pkgin "sudo pkgin install foo"                                install foo
ok pkgin "sudo pkgin -y install foo"                             install -y foo
ok pkgin "sudo pkgin remove foo"                                 remove foo
ok pkgin "pkgin search foo"                                      search foo
ok pkgin "pkgin pkg-descr foo"                                   info foo
ok pkgin "sudo pkgin update"                                     refresh
ok pkgin "sudo pkgin update && sudo pkgin full-upgrade"          upgrade
ok pkgin "pkgin list"                                            list
ok pkgin "sudo pkgin autoremove"                                 orphans
ok pkgin "sudo pkgin clean"                                      clean
ok pkgin "pkg_info -Fe /bin/ls"                                  owns /bin/ls
ok pkgin "pkgin pkg-content foo"                                 files foo

# --- aliases ---------------------------------------------------------------
ok apt "sudo apt-get install foo"                                in foo
ok apt "sudo apt-get remove foo"                                 rm foo
ok apt "apt-cache search foo"                                    se foo
ok apt "sudo apt-get update && sudo apt-get dist-upgrade"        up
ok apt "dpkg --get-selections"                                   list

# --- flag placement and forms ----------------------------------------------
ok apt "sudo apt-get install -y foo"                             install foo -y
ok apt "sudo apt-get install -y foo"                             -y install foo
ok pacman "sudo pacman -S foo"                                   --via pacman install foo
ok pacman "sudo pacman -S foo"                                   --via=arch install foo

# --- end-of-options (--) ----------------------------------------------------
ok apt "sudo apt-get remove -foo"                                remove -- -foo
ok apt "dpkg -S -x"                                              owns -- -x
ok apt "sudo apt-get install -y bar"                             -y install -- bar

# --- single-package upgrade (pkx upgrade <pkg>) -----------------------------
# The single-package form refreshes the index first, exactly like the
# no-argument form (the zypper case is asserted for the Leap path; a
# Tumbleweed host would refuse, like pacman).
ok apt     "sudo apt-get update && sudo apt-get install --only-upgrade foo" upgrade foo
ok apt     "sudo apt-get update && sudo apt-get install --only-upgrade -y foo" upgrade -y foo
ok dnf     "sudo dnf upgrade --refresh foo"             upgrade foo
ok dnf     "sudo dnf upgrade --refresh -y foo"          upgrade -y foo
ok yum     "sudo yum update foo"                        upgrade foo
ok yum     "sudo yum update -y foo"                     upgrade -y foo
no pacman                                               upgrade foo
ok apk     "sudo apk update && sudo apk upgrade foo"    upgrade foo
ok zypper  "sudo zypper refresh && sudo zypper update foo" upgrade foo
ok zypper  "sudo zypper refresh && sudo zypper --non-interactive update foo" upgrade -y foo
ok xbps    "sudo xbps-install -Su foo"                  upgrade foo
ok xbps    "sudo xbps-install -Su -y foo"               upgrade -y foo
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
ok apt     "sudo apt-get update && sudo apt-get install --only-upgrade foo bar" upgrade foo bar
ok apt     "sudo apt-get update && sudo apt-get install --only-upgrade foo" up foo
ok apt     "sudo apt-get update && sudo apt-get install --only-upgrade foo" upgrade -- foo

# --- operand quoting (safe eval) -------------------------------------------
ok apt "apt-cache show 'perl(URI)'"          info "perl(URI)"
ok apk "sudo apk add 'foo>=1.0'"             install "foo>=1.0"
ok apt "dpkg -S '/Applications/My App/bin'"  owns "/Applications/My App/bin"
ok apt "sudo apt-get install 'a; reboot'"    install "a; reboot"
ok apt "sudo apt-get install foo bar"        install foo bar
ok apt "sudo apt-get install 'a b' c"        install "a b" c

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
err list foo
err which foo
err -V install foo
err install foo -h
err --via "" install foo
err --via= install foo

echo
echo "pkx dry-run suite: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
