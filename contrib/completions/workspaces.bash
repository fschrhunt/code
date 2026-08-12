# Bash completion for workspaces.
_workspaces_complete() {
  local cur prev
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  case "$prev" in
    workspaces) COMPREPLY=( $(compgen -W 'setup clone new list remove root doctor version help' -- "$cur") );;
    setup) COMPREPLY=( $(compgen -W '--root --help' -- "$cur") );;
    remove) COMPREPLY=( $(compgen -W '--force --help' -- "$cur") );;
    *) COMPREPLY=();;
  esac
}
complete -F _workspaces_complete workspaces
