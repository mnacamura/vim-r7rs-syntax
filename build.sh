#!/usr/bin/env bash

author='Mitsuhiro Nakamura'
email='m.nacamura@gmail.com'
homepage='https://github.com/mnacamura/vim-gauche'

readonly author email homepage

read -r -d '' common_meta <<EOF
" Language: Scheme (Gauche)
" Last Change: $(date +"%Y-%m-%d")
" Author: $author <$email>
" URL: $homepage
" License: Public domain
" Notes: To enable this plugin, set filetype=scheme and (b|g):is_gauche=1.
EOF

set -euo pipefail

show_usage() {
    cat >&2 <<EOF
Usage: $0 CMD [ARG...]

Commands:
    tsv
    macro
    specialform
    function
    variable
    constant
    module
    class
    syntax
    ftplugin
EOF
}

esc() {
    echo "$1" | sed -E 's@(\?|\*|\+|\.|\^|\$)@\\\1@g'
}

build_tsv() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 tsv [NAME...]

Convert Gauche document source files to a TSV table.

Args:
    NAME...     names of texinfo source files, suffix (.texi) can be omitted
EOF
        exit 1
    fi

    local name files=()
    for name in "$@"; do
        files+=("$GAUCHE_SRC/doc/${name%.texi}.texi")
    done

    grep -E '^@def' "${files[@]}" \
        | sed 's/:/ /' \
        | awk -f"$lib" -e 'BEGIN { FS = " " }
                           { $1 = basename($1)
                             # Join fields surrounded by {}
                             for (i = 3; i <= NF; i++) {
                                 j = i
                                 while ( $i ~ /^{/ && $j !~ /}$/ ) {
                                     j++
                                     if ( j > NF ) break
                                 }
                                 if ( j > i )
                                     for ( k = i + 1; k <= j; k++ ) {
                                         $i = $i" "$k
                                         $k = ""
                                     }
                             }
                             print
                           }' \
        | sed -E 's/\t\t+/\t/g' \
        | awk -f"$lib" -e '{ if ( $3 ~ /^{[^()]+}$/ )  # function could be like {(setter ...)}
                                 # $3 may have various cases; e.g. {Condition [tT]ype}
                                 print $1, $2, tolower($3), unwrap($4)
                             else
                                 print $1, $2, "", unwrap($3)
                           }' \
        | sort | uniq
}

build_macro() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 macro FILE

Generate vim syntax for Gauche macros.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@defmacx?/ { print libtype($1), $4 }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | while read -r line; do
              name="$(echo "$line" | awk -F'\t' '{ print $2 }')"
              if ! grep -E "^syn keyword scheme\\w*Syntax $(esc "$name")$" \
                  "$VIM_SRC"/runtime/syntax/scheme.vim > /dev/null 2>&1
              then
                  echo "$line"
              fi
          done \
        | awk -F'\t' '{ if ( $2 == "use" )
                            {}  # skip it as it is handled in schemeImport
                        else if ( $2 == "define-class" )
                            # Can be defined only on toplevel
                            print "syn keyword schemeSpecialSyntax "$2
                        else if ( $2 == "^c" )
                            print "syn match schemeSyntax /\\^[_a-z]/"
                        else
                            print "syn keyword schemeSyntax "$2
                      }'
}

build_specialform() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 specialform FILE

Generate vim syntax for Gauche special forms.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@defspecx?/ { print libtype($1), $4 }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | while read -r line; do
              name="$(echo "$line" | awk -F'\t' '{ print $2 }')"
              if ! grep -E "^syn keyword scheme\\w*Syntax $(esc "$name")$" \
                  "$VIM_SRC"/runtime/syntax/scheme.vim > /dev/null 2>&1
              then
                  echo "$line"
              fi
          done \
        | awk -F'\t' '{ if ( $2 == "import" )
                            {}  # skip it as it is handled in schemeImport
                        else if ( $2 == "require" || \
                                  $2 ~ /^define-(constant|in-module|inline)$/ )
                            # Can be defined only on toplevel (except define-inline)
                            print "syn keyword schemeSpecialSyntax "$2
                        else if ( $2 ~ /^(define|select)-module$/ || \
                                  $2 == "export-all" )
                            print "syn keyword schemeLibrarySyntax "$2
                        else
                            print "syn keyword schemeSyntax "$2
                      }'
}

build_function() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 function FILE

Generate vim syntax for Gauche functions.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@defunx?/ || \
                     ( /@deftpx?/ && /{function}/ ) || \
                     ( /@deffnx?/ && /{(generic )?function}/ ) {
                         print libtype($1), $4
                     }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | while read -r line; do
              name="$(echo "$line" | awk -F'\t' '{ print $2 }')"
              if ! grep -E "^syn keyword schemeFunction $(esc "$name")$" \
                  "$VIM_SRC"/runtime/syntax/scheme.vim > /dev/null 2>&1
              then
                  echo "$line"
              fi
          done \
        | awk -F'\t' '{ print "syn keyword schemeFunction "$2 }'
}

build_variable() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 variable FILE

Generate vim syntax for Gauche variables.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@defvarx?/ || \
                     /@defvrx?/ && /{comparator}/ {
                         print libtype($1), $4
                     }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | awk -F'\t' '{ print "syn keyword schemeVariable "$2 }'
}

build_constant() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 constant FILE

Generate vim syntax for Gauche constants.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@defvrx?/ && /{constant}/ {
                         print libtype($1), $4
                     }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | while read -r line; do
              name="$(echo "$line" | awk -F'\t' '{ print $2 }')"
              if ! grep -E "^syn keyword schemeConstant $(esc "$name")$" \
                  "$VIM_SRC"/runtime/syntax/scheme.vim > /dev/null 2>&1
              then
                  echo "$line"
              fi
          done \
        | awk -F'\t' '{ print "syn keyword schemeConstant "$2 }'
}

build_module() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 module FILE

Generate vim syntax for Gauche modules.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@deftpx?/ && /{(builtin )?module}/ { 
                         print libtype($1), $4
                     }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | awk -F'\t' '{ print "syn keyword gaucheModule "$2 }'
}

build_class() {
    if [ -z "${1+defined}" ]; then
        cat >&2 <<EOF
Usage: $0 class FILE

Generate vim syntax for Gauche classes.

Args:
    FILE        path to the TSV file generated by $0 tsv
EOF
        exit 1
    fi

    local line name
    awk -f"$lib" -e '/@deftpx?/ && /{((builtin )?class|metaclass)}/ {
                         print libtype($1), $4
                     }' "$1" \
        | sort | uniq \
        | awk -f"$lib" -e '{ print_with_at_expanded($0) }' \
        | awk -F'\t' '{ print "syn keyword gaucheClass "$2 }'
}

build_syntax() {
    if [ "$#" -eq 0 ]; then
        cat >&2 <<EOF
Usage: $0 syntax [FILE...]

Generate syntax/gauche.vim from generated vim files.

Args:
    FILE...     path to file(s) generated by $0 (macro|specialform|...)
EOF
        exit 1
    fi

    cat <<EOF
" Vim syntax file
$common_meta

if !exists('b:did_scheme_syntax')
  finish
endif
EOF

    echo
    cat <<'EOF'
" [] as parentheses {{{1

syn region schemeQuote matchgroup=schemeData start=/'['`]*\[/ end=/\]/ contains=ALLBUT,schemeQuasiquote,schemeQuasiquoteForm,schemeUnquote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster
syn region schemeQuasiquote matchgroup=schemeData start=/`['`]*\[/ end=/\]/ contains=ALLBUT,schemeQuote,schemeQuoteForm,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster
syn region schemeUnquote matchgroup=schemeParentheses start=/,\[/ end=/\]/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region schemeUnquote matchgroup=schemeParentheses start=/,@\[/ end=/\]/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region schemeQuoteForm matchgroup=schemeData start=/\(#\)\@<!\[/ end=/\]/ contained contains=ALLBUT,schemeQuasiquote,schemeQuasiquoteForm,schemeUnquote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster
syn region schemeQuasiquoteForm matchgroup=schemeData start=/\(#\)\@<!\[/ end=/\]/ contained contains=ALLBUT,schemeQuote,schemeForm,schemeDatumCommentForm,schemeImport,@schemeImportCluster,@schemeSyntaxCluster

" 'use' as import syntax {{{1

syn region schemeImport matchgroup=schemeImport start="\(([ \t\n]*\)\@<=use\>" end=")"me=e-1 contained contains=schemeImportForm,schemeIdentifier,schemeComment,schemeDatumComment,gaucheModule

" Hash-bang (#!) {{{1

syn match gaucheShebang /\(\%^\)\@<=#![\/ ].*$/
syn match gaucheSharpSpecial /\(\%^\)\@<!#![^ '`\t\n()\[\]"|;]\+/

" String interpolation (#") {{{1

syn region gaucheSharpString start=/\(\\\)\@<!#"/ skip=/\\[\\"]/ end=/"/ contains=gaucheSharpStringUnquote
syn region gaucheSharpStringUnquote matchgroup=schemeParentheses start=/\(\~\)\@<!\~\(\~\)\@!/ end=/[ `'\t\n\[\]()";]/me=e-1 contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region gaucheSharpStringUnquote matchgroup=schemeParentheses start=/\(\~\)\@<!\~#\?(/ end=/)/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster
syn region gaucheSharpStringUnquote matchgroup=schemeParentheses start=/\(\~\)\@<!\~\[/ end=/\]/ contained contains=ALLBUT,schemeDatumCommentForm,@schemeImportCluster

" Class (<foo>) and condition type (&bar) {{{1

syn match gaucheClass /<[^ '`\t\n()\[\]"|;]\+>/
syn match schemeConditionType /&[^ '`\t\n()\[\]"|;]\+/

" Keywords {{{1

EOF

    cat "$@" | sort | uniq

    cat <<EOF

" Highlights {{{1

hi def link gaucheClass Type
hi def link gaucheModule Type
hi def link gaucheSharpSpecial PreProc
hi def link gaucheSharpString schemeString
hi def link gaucheShebang Comment
hi def link schemeConditionType Type
hi def link schemeVariable Identifier

" vim: fdm=marker
EOF
}

build_ftplugin() {
    if [ "$#" -eq 0 ]; then
        cat >&2 <<EOF
Usage: $0 ftplugin [FILE...]

Generate ftplugin/gauche.vim from generated vim files.

Args:
    FILE...     path to file(s) generated by $0 (macro|specialform|...)
EOF
        exit 1
    fi

    cat <<EOF
" Vim filetype plugin file
$common_meta

if !exists('b:did_scheme_ftplugin')
  finish
endif

EOF

    local word
    awk '{ print $4 }' "$@" \
        | awk '/^(|r|g)let((|rec)(|1|\*)($|-)|\/)/ || /-let(|rec)(|1|\*)$/ \
            || /^define($|-)/ || /-define$/ \
            || /^match($|-)/ || /-match$/ \
            || /^(|e)case($|-)/ || ( /-(|e)case$/ && $0 !~ /(lower|upper|title)-case$/ ) \
            || /^lambda($|-)/ || ( /-lambda(|\*)$/ && $0 !~ /^scheme\.case-lambda$/ ) \
            || /^set!($|-)/ || ( /-set!$/ && $0 !~ /char-set!$/ ) \
            || /^do(-|times|list)/' \
        | sort | uniq \
        | while read -r word; do
              if ! grep -F "setl lispwords+=$word" \
                  "$VIM_SRC"/runtime/ftplugin/scheme.vim > /dev/null 2>&1
              then
                  echo "setl lispwords+=$word"
              fi
          done
}

if [ -z "${GAUCHE_SRC+defined}" ]; then
    echo "Please set GAUCHE_SRC to gauche source path" >&2
    exit 1
fi

if [ -z "${VIM_SRC+defined}" ]; then
    echo "Please set VIM_SRC to vim source path" >&2
    exit 1
fi

if [ -z "${1+defined}" ]; then
    show_usage
    exit 1
fi

lib="$(mktemp --suffix vimgauche)"
cat > "$lib" <<'EOF'
BEGIN {
    FS = "\t"
    OFS = "\t"
    atat[0] = "u8"
    atat[1] = "s8"
    atat[2] = "u16"
    atat[3] = "s16"
    atat[4] = "u32"
    atat[5] = "s32"
    atat[6] = "u64"
    atat[7] = "s64"
    atat[8] = "f16"
    atat[9] = "f32"
    atat[10] = "f64"
    atat[11] = "c32"
    atat[12] = "c64"
    atat[13] = "c128"
    html[0] = "a"
    html[1] = "abbr"
    html[2] = "acronym"
    html[3] = "address"
    html[4] = "area"
    html[5] = "b"
    html[6] = "base"
    html[7] = "bdo"
    html[8] = "big"
    html[9] = "blockquote"
    html[10] = "body"
    html[11] = "br"
    html[12] = "button"
    html[13] = "caption"
    html[14] = "cite"
    html[15] = "code"
    html[16] = "col"
    html[17] = "colgroup"
    html[18] = "dd"
    html[19] = "del"
    html[20] = "dfn"
    html[21] = "div"
    html[22] = "dl"
    html[23] = "dt"
    html[24] = "em"
    html[25] = "fieldset"
    html[26] = "form"
    html[27] = "frame"
    html[28] = "frameset"
    html[29] = "h1"
    html[30] = "h2"
    html[31] = "h3"
    html[32] = "h4"
    html[33] = "h5"
    html[34] = "h6"
    html[35] = "head"
    html[36] = "hr"
    html[37] = "html"
    html[38] = "i"
    html[39] = "iframe"
    html[40] = "img"
    html[41] = "input"
    html[42] = "ins"
    html[43] = "kbd"
    html[44] = "label"
    html[45] = "legend"
    html[46] = "li"
    html[47] = "link"
    html[48] = "map"
    html[49] = "meta"
    html[50] = "noframes"
    html[51] = "noscript"
    html[52] = "object"
    html[53] = "ol"
    html[54] = "optgroup"
    html[55] = "option"
    html[56] = "p"
    html[57] = "param"
    html[58] = "pre"
    html[59] = "q"
    html[60] = "samp"
    html[61] = "script"
    html[62] = "select"
    html[63] = "small"
    html[64] = "span"
    html[65] = "strong"
    html[66] = "style"
    html[67] = "sub"
    html[68] = "sup"
    html[69] = "table"
    html[70] = "tbody"
    html[71] = "td"
    html[72] = "textarea"
    html[73] = "tfoot"
    html[74] = "th"
    html[75] = "thead"
    html[76] = "title"
    html[77] = "tr"
    html[78] = "tt"
    html[79] = "ul"
    html[80] = "var"
}
function basename(path,    _path) {
    _path = path
    sub(".*/", "", _path)
    return _path
}
function libtype(texifile) {
    if ( texifile ~ /(core|macro|object)/ )
        return "gaucheBuiltin"
    if ( texifile ~ /gauche/ )
        return "gaucheExt"
    if ( texifile ~ /r7rs/ )
        return "scheme"
    if ( texifile ~ /srfi/ )
        return "srfi"
    if ( texifile ~ /util/ )
        return "gaucheUtil"
    return "Unknown"
}
function unwrap(field,    m) {
    if ( match(field, /^{\(\w+ (.+)\)}$/, m) )
        return m[1]
    return field
}
function print_with_at_expanded(line,    i, _line) {
    if ( line ~ /@@/ )
        for (i in atat) {
            _line = line
            gsub(/@@/, atat[i], _line)
            print _line
        }
    else if ( line ~ /html:@var{element}/ )
        for (i in html) {
            _line = line
            gsub(/@var{element}/, html[i], _line)
            print _line
        }
    else
        print line
}
EOF

cleanup() {
    rm -f "$lib"
}
trap cleanup ERR SIGTERM EXIT

case "$1" in
    tsv|macro|specialform|function|variable|constant|module|class|syntax|ftplugin)
        cmd="$1"
        shift
        build_"$cmd" "$@"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
