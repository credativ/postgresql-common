# shell functions used in postgresql-common
#
# (C) 2014 Martin Pitt <mpitt@debian.org>
# (C) 2014 Christoph Berg <myon@debian.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

# set DISTRO and RELEASE
get_release() {
    # return if we were already called
    [ "${DISTRO:-}" ] && [ "${RELEASE:-}" ] && return

    # we have /etc/os-release, use it
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        RELEASE="${VERSION_ID:-unstable}" # unstable doesn't have this field

    # fall back to lsb_release
    elif type lsb_release >/dev/null 2>/dev/null; then
        DISTRO="`lsb_release -is`"
        RELEASE="`lsb_release -rs`"

    else
        echo "get_release: WARNING: /etc/os-release and lsb_release not present, unknown distribution" >&2
    fi
}

# install locales; this happens differently on Debian and Ubuntu
# Arguments: locale charset [...]
locale_gen ()
{
    get_release

    case $DISTRO in
        debian)
            local run
            while [ "${2:-}" ]; do
                if ! grep -q "^$1 $2\$" /etc/locale.gen; then
                    echo "$1 $2" >> /etc/locale.gen
                    run=1
                fi
                shift 2
            done
            [ "${run:-}" ] && locale-gen
            ;;

        ubuntu)
            # locale-gen will skip existing locales, so just call it
            # unconditionally for all here
            local locales
            while [ "${2:-}" ]; do
                locales="${locales:-} $1"
                shift 2
            done
            locale-gen $locales
            ;;
    esac

    return 0
}

