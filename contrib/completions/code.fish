# Fish completion for code.
complete -c code -f
for command in new list remove root upgrade version help
  complete -c code -n "__fish_use_subcommand" -a $command
end
complete -c code -n "__fish_seen_subcommand_from remove" -l force
