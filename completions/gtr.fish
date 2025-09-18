# fish completion for gtr

function __gtr_base_dir --description 'Get gtr base dir'
  if test -n "$GTR_BASE_DIR"
    echo "$GTR_BASE_DIR"
  else
    echo "$HOME/Documents/dev/worktrees"
  end
end

function __gtr_worktree_names --description 'List worktree names'
  set -l base (__gtr_base_dir)
  if test -d "$base"
    command ls -1 "$base" ^/dev/null
  end
end

# Subcommands
complete -c gtr -n '__fish_use_subcommand' -a create -d 'Create new worktrees'
complete -c gtr -n '__fish_use_subcommand' -a c -d 'Alias for create'
complete -c gtr -n '__fish_use_subcommand' -a remove -d 'Remove worktrees'
complete -c gtr -n '__fish_use_subcommand' -a rm -d 'Alias for remove'
complete -c gtr -n '__fish_use_subcommand' -a cd -d 'Change directory to worktree'
complete -c gtr -n '__fish_use_subcommand' -a list -d 'List worktrees'
complete -c gtr -n '__fish_use_subcommand' -a ls -d 'Alias for list'
complete -c gtr -n '__fish_use_subcommand' -a l -d 'Alias for list'
complete -c gtr -n '__fish_use_subcommand' -a idea -d 'Manage development ideas'
complete -c gtr -n '__fish_use_subcommand' -a i -d 'Alias for idea'
complete -c gtr -n '__fish_use_subcommand' -a claude -d 'Run claude in worktree'
complete -c gtr -n '__fish_use_subcommand' -a cursor -d 'Run cursor in worktree'
complete -c gtr -n '__fish_use_subcommand' -a prune -d 'Clean up merged worktrees'
complete -c gtr -n '__fish_use_subcommand' -a doctor -d 'Check/fix local files in worktree'
complete -c gtr -n '__fish_use_subcommand' -a init -d 'Initialize gtr configuration'

# Global options
complete -c gtr -l prefix -d 'Branch prefix' -r
complete -c gtr -l username -d 'Username for branch naming' -r
complete -c gtr -l editor -d 'Editor to open worktrees' -r
complete -c gtr -l no-open -d "Don't open editor after creating worktree"
complete -c gtr -l no-install -d 'Skip pnpm commands on create'
complete -c gtr -l base -d 'Base branch' -r
complete -c gtr -l uncommitted -d 'Include uncommitted changes' -x -a 'true false'

# Command-specific options
complete -c gtr -n '__fish_seen_subcommand_from remove rm' -l force -d 'Force removal'
complete -c gtr -n '__fish_seen_subcommand_from remove rm' -l dry-run -d 'Dry run'

complete -c gtr -n '__fish_seen_subcommand_from prune' -l base -d 'Base branch' -r
complete -c gtr -n '__fish_seen_subcommand_from prune' -l dry-run -d 'Dry run'
complete -c gtr -n '__fish_seen_subcommand_from prune' -l force -d 'Force removal'

complete -c gtr -n '__fish_seen_subcommand_from doctor' -l fix -d 'Copy/overwrite missing files'
complete -c gtr -n '__fish_seen_subcommand_from doctor' -l force -d 'Skip interactive prompts'

complete -c gtr -n '__fish_seen_subcommand_from init' -l doctor -d 'Check configuration coverage'
complete -c gtr -n '__fish_seen_subcommand_from init' -l fix -d 'Auto-add missing files to config'

# Idea subcommands
complete -c gtr -n '__fish_seen_subcommand_from idea i' -a create -d 'Create new idea'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -a c -d 'Alias for create'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -a list -d 'List ideas'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -a l -d 'Alias for list'

# Idea list options
complete -c gtr -n '__fish_seen_subcommand_from idea i' -l mine -d 'Show only your ideas'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -l todo -d 'Show only TODO status ideas'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -l status -d 'Filter by status' -x -a 'TODO IN_PROGRESS DONE BLOCKED'
complete -c gtr -n '__fish_seen_subcommand_from idea i' -l filter -d 'Filter by content' -r

# Name completion for worktree-taking commands
for sc in create c remove rm cd claude cursor doctor
  complete -c gtr -n "__fish_seen_subcommand_from $sc" -a '(__gtr_worktree_names)'
end


