# Fish completion for workframe / wf. Install with:
#   workframe completion fish > ~/.config/fish/completions/workframe.fish
set -l commands init setup clone new resume current run dashboard list open path archive restore remove repos worktrees agents status doctor config sync clean update completion
complete -c workframe -f
complete -c wf -f
for command in $commands
  complete -c workframe -n "__fish_use_subcommand" -a $command
  complete -c wf -n "__fish_use_subcommand" -a $command
end
for command in workframe wf
  complete -c $command -n "__fish_seen_subcommand_from list" -l agent -r
  complete -c $command -n "__fish_seen_subcommand_from list" -l repo -r
  complete -c $command -n "__fish_seen_subcommand_from list" -l dirty
  complete -c $command -n "__fish_seen_subcommand_from list status repos worktrees" -l json
  complete -c $command -n "__fish_seen_subcommand_from doctor" -l fix
end
