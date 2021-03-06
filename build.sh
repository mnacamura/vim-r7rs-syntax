#!/usr/bin/env bash

set -euo pipefail

TMPD="$(mktemp -d --suffix vimgauche)"
readonly TMPD
cleanup() { rm -rf "$TMPD"; }
trap cleanup ERR SIGTERM EXIT

readonly LIB="$TMPD/lib.awk"

main() {
    if [[ -z "${GAUCHE_SRC+defined}" ]]; then
        echo "Please set GAUCHE_SRC to gauche source path" >&2
        exit 1
    fi

    if [[ -z "${1+defined}" ]]; then
        usage
    fi

    local cmd
    case "$1" in
        (cise)
            cmd="$1"
            shift
            build_"$cmd" "$@"
            ;;
        (*)
            usage
            ;;
    esac
}

usage() {
    cat >&2 <<EOF
Usage: $0 CMD [ARG...]

Commands:
    cise
EOF
    exit 1
}

build_cise() {
    if [[ -z "${1+defined}" ]]; then
        cat >&2 <<EOF
Usage: $0 cise TSV

Generate vim syntax for Gauche CiSE statements, expressions, types, and stub forms.

Args:
    TSV         TSV file generated by $0 tsv
EOF
        exit 1
    fi

    gawk -F'\t' '$3 ~ /^{cise type}$/ { print $4 }' "$1" \
        | sort | uniq \
        | gawk '{ switch ($0) {
                  default:
                      print "syn keyword r7rsCiSEType", $0
                      break
                  }
                }'
    gawk -F'\t' '$3 ~ /^{cise statement}$/ || $3 ~ /^{stub form}$/ { print $4 }' "$1" \
        | sort | uniq \
        | find_undefined_keywords_in 'r7rs\w*SyntaxM?' \
        | gawk '{ switch ($0) {
                  case /(define|decl)/:
                      # Use special color
                      print "syn keyword r7rsCiSESyntaxM", $0
                      break
                  # != contains ! but not mutator
                  case /!$/:
                      # Use special color
                      print "syn keyword r7rsCiSESyntaxM", $0
                      break
                  default:
                      print "syn keyword r7rsCiSESyntax", $0
                      break
                  }
                }'
    gawk -F'\t' '$3 ~ /^{cise expression}$/ { print $4 }' "$1" \
        | sort | uniq \
        | find_undefined_keywords_in 'r7rs(\w*Syntax|Function)M?' \
        | gawk '{ switch ($0) {
                  # != contains ! but not mutator
                  case /!$/:
                      # Use special color
                      print "syn keyword r7rsCiSEFunctionM", $0
                      break
                  default:
                      print "syn keyword r7rsCiSEFunction", $0
                      break
                  }
                }'
}

find_undefined_keywords_in() {
    local groupname="$1" keyword
    while read -r keyword; do
        if ! grep -E "syn keyword $groupname (.+ )?$(esc "$keyword")( |$)" \
               ./syntax/{r7rs,r7rs-large,srfi}.vim > /dev/null 2>&1
        then
            echo "$keyword"
        fi
    done
}

# Escape meta characters in EXTENDED regular expressions
esc() {
    echo "$1" | sed -E 's@(\*|\.|\^|\$|\+|\?)@\\\1@g'
}

cat > "$LIB" <<'EOF'
BEGIN {
    FS = "\t"
    OFS = "\t"
}
EOF

main "$@"
