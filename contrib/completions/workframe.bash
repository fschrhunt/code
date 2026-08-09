# Bash completion for workframe / wf. Install with:
#   source <(workframe completion bash)
_workframe_complete() {
  local cur prev words cword
  _init_completion || return
  local commands='init setup clone new resume current run dashboard list open path archive restore remove repos worktrees agents status doctor config sync clean update version help completion'
  case "$prev" in
    workframe|wf) COMPREPLY=( $(compgen -W "$commands" -- "$cur") ); return ;;
    --agent) COMPREPLY=( $(compgen -W "$(workframe agents list 2>/dev/null | sed -n 's/^  //p')" -- "$cur") ); return ;;
  esac
  case "${words[1]}" in
    list) COMPREPLY=( $(compgen -W 'archived --agent --repo --dirty --json --help' -- "$cur") );;
    status|repos|worktrees) COMPREPLY=( $(compgen -W '--json --help' -- "$cur") );;
    doctor) COMPREPLY=( $(compgen -W '--fix --help' -- "$cur") );;
    completion) COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") );;
    *) COMPREPLY=() ;;
  esac
}
complete -F _workframe_complete workframe wf
