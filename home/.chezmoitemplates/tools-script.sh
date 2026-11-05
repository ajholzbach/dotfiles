{{ template "common.sh" . }}
finish() {
    status=$?
    [ -z "$installer" ] || rm -f "$installer"
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "To apply only the dotfiles, run: chezmoi init --apply --prompt --promptBool tools=false" >&2
    fi
}
trap finish EXIT
