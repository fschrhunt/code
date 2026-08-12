# Fish completion for workspaces.
complete -c workspaces -f
for command in setup clone new list remove root doctor version help
  complete -c workspaces -n "__fish_use_subcommand" -a $command
end
complete -c workspaces -n "__fish_seen_subcommand_from setup" -l root -r
complete -c workspaces -n "__fish_seen_subcommand_from remove" -l force
