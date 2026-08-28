# Fish completion for code.
complete -c code -f
for command in setup clone new list remove root doctor version help
  complete -c code -n "__fish_use_subcommand" -a $command
end
complete -c code -n "__fish_seen_subcommand_from setup" -l root -r
complete -c code -n "__fish_seen_subcommand_from setup" -s y -l yes
complete -c code -n "__fish_seen_subcommand_from remove" -l force
