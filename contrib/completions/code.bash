# Bash completion for code.
_code_complete() {
  local cur prev
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  case "$prev" in
    code) COMPREPLY=( $(compgen -W 'clone new list remove root upgrade version help' -- "$cur") );;
    remove) COMPREPLY=( $(compgen -W '--force --help' -- "$cur") );;
    *) COMPREPLY=();;
  esac
}
complete -F _code_complete code
