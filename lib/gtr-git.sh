#!/bin/bash

# gtr-git.sh - Git operations and worktree management
# Contains functions for creating, removing, and managing git worktrees


_gtr_find_or_create_worktree() {
  local name="$1"
  local should_open="${2:-false}"
  local dir="$(_gtr_get_worktree_path "$name")"

  # If worktree already exists, return success
  if [[ -d "$dir" ]]; then
    echo "$dir"
    return 0
  fi

  # Check if configuration exists (either global or local)
  if ! _gtr_is_initialized; then
    echo "❌ No gtr configuration found" >&2
    echo "   Run 'gtr init' to create a global configuration (~/.gtr/config)" >&2
    echo "   or create a local configuration in this repository (.gtr/config)" >&2
    return 1
  fi

  # Prompt to create worktree
  local reply
  reply=$(_gtr_ask_user "Worktree '$name' doesn't exist. Create it now? [y/N] " "N")
  case "$reply" in
    [yY]|[yY][eE][sS])
      local branch_name="$(_gtr_get_worktree_branch_name "$name")"

      # Check if branch already exists
      if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Branch '$branch_name' already exists. Cannot create worktree." >&2
        return 1
      fi

      local base_branch="${_GTR_BASE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
      echo "Creating worktree '$name' based on $base_branch…"

      # Create directory structure if it doesn't exist
      mkdir -p "$(dirname "$dir")"

      if git worktree add "$dir" -b "$branch_name" "$base_branch"; then
        echo "✅ Created worktree '$name'"

        # Copy local files from main worktree to new worktree (only if we have files to copy)
        local main_worktree="$(_gtr_get_main_worktree)"
        local patterns=($(_gtr_read_config "$main_worktree"))
        if [[ ${#patterns[@]} -gt 0 ]]; then
          _gtr_copy_local_files "$main_worktree" "$dir" "true" "$main_worktree"
        fi


        echo "$dir"
        return 0
      else
        echo "git worktree add failed" >&2
        return 1
      fi
      ;;
    *)
      echo "Aborted." >&2
      return 1
      ;;
  esac
}

_gtr_create_worktree() {
  local name="$1"
  local base_branch="${_GTR_BASE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
  local worktree_path="$(_gtr_get_worktree_path "$name")"
  local branch_name="$(_gtr_get_worktree_branch_name "$name")"
  local main_worktree="$(_gtr_get_main_worktree)"
  local current_branch="$(git rev-parse --abbrev-ref HEAD)"
  local untracked="${_GTR_UNTRACKED:-true}"

  # Validate that --untracked only works when --base is current branch
  if [[ "$untracked" == "true" && "$base_branch" != "$current_branch" ]]; then
    echo "❌ Error: --untracked=true can only be used when --base is the current branch"
    echo "   Current branch: $current_branch"
    echo "   Base branch: $base_branch"
    echo "   Use --untracked=false to create worktree from a different base branch"
    return 1
  fi

  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    echo "Branch '$branch_name' already exists. Skipping '$name'."
    return 1
  fi

  # Handle uncommitted changes if requested
  local uncommitted_files=()
  if [[ "$untracked" == "true" ]]; then
    # Check if there are uncommitted changes (modified, added, staged, or new files)
    local uncommitted_status=$(git status --porcelain)
    if [[ -n "$uncommitted_status" ]]; then
      echo "📁 Including uncommitted changes in worktree..."

      # Collect files to copy and log each file that will be moved
      while IFS= read -r line; do
        # Skip empty lines
        if [[ -z "$line" ]]; then
          continue
        fi

        local status_code="${line:0:2}"
        local file_path="${line:3}"

        # Handle renamed files (R  old -> new)
        if [[ "$status_code" =~ ^R ]]; then
          file_path=$(echo "$file_path" | sed 's/.*-> //')
        fi

        # Skip if no file path
        if [[ -z "$file_path" ]]; then
          continue
        fi

        # Determine the type of change
        local change_type=""
        case "$status_code" in
          "??") change_type="new file" ;;
          " M") change_type="modified" ;;
          "M ") change_type="staged" ;;
          "MM") change_type="modified and staged" ;;
          "A ") change_type="added" ;;
          "AM") change_type="added and modified" ;;
          "D ") change_type="deleted" ;;
          " D") change_type="deleted (staged)" ;;
          "R ") change_type="renamed" ;;
          "C ") change_type="copied" ;;
          *) change_type="changed" ;;
        esac

        echo "  📄 $change_type: $file_path"
        uncommitted_files+=("$file_path")
      done <<< "$uncommitted_status"
    fi
  fi

  # Execute pre-create hook
  if ! _gtr_execute_pre_create_hook "$name" "$worktree_path" "$branch_name" "$base_branch" "$main_worktree"; then
    echo "❌ Pre-create hook failed, aborting worktree creation"
    return 1
  fi

  # Create directory structure if it doesn't exist
  mkdir -p "$(dirname "$worktree_path")"

  # Create worktree and branch from the specified base
  if git worktree add "$worktree_path" -b "$branch_name" "$base_branch"; then
    echo "✅ Created worktree '$name' based on $base_branch"

    # Copy uncommitted files to the worktree if requested
    if [[ ${#uncommitted_files[@]} -gt 0 ]]; then
      echo "📋 Copying uncommitted changes to worktree..."

      for file_path in "${uncommitted_files[@]}"; do
        local source_file="$main_worktree/$file_path"
        local target_file="$worktree_path/$file_path"
        local target_dir=$(dirname "$target_file")

        # Create target directory if it doesn't exist
        mkdir -p "$target_dir" 2>/dev/null

        # Copy the file
        if [[ -f "$source_file" ]]; then
          cp "$source_file" "$target_file" 2>/dev/null
          echo "  📄 Copied: $file_path"
        elif [[ -d "$source_file" ]]; then
          cp -r "$source_file" "$target_file" 2>/dev/null
          echo "  📁 Copied directory: $file_path"
        fi
      done

      echo "  ℹ️  Files copied to worktree. Git states (staged/modified) will need to be recreated manually."
    fi

    # Copy local files from main worktree to new worktree (only if we have files to copy)
    local patterns=($(_gtr_read_config "$main_worktree"))
    if [[ ${#patterns[@]} -gt 0 ]]; then
      _gtr_copy_local_files "$main_worktree" "$worktree_path" "true" "$main_worktree"
    fi


    # Execute post-create hook
    _gtr_execute_post_create_hook "$name" "$worktree_path" "$branch_name" "$base_branch" "$main_worktree"

    if [[ "$_GTR_NO_OPEN" == "false" ]]; then
      # Execute before-open hook
      _gtr_execute_before_open_hook "$name" "$worktree_path" "$_GTR_EDITOR" "create" "$main_worktree"
      
      echo "Opening '$worktree_path' with $_GTR_EDITOR"
      $_GTR_EDITOR "$worktree_path"
      
      # Execute post-open hook
      _gtr_execute_post_open_hook "$name" "$worktree_path" "$_GTR_EDITOR" "create" "$main_worktree"
    else
      echo "Worktree ready at '$worktree_path'"
    fi
    return 0
  else
    echo "Failed to create worktree '$name'"
    return 1
  fi
}

_gtr_remove_worktree() {
  local name="$1"
  local force="$2"
  local dry_run="$3"
  local expected_path="$(_gtr_get_worktree_path "$name")"
  local branch_name="$(_gtr_get_worktree_branch_name "$name")"
  local worktree_path=""
  local worktree_branch=""

  # First, try to find the worktree by directory name
  if [[ -d "$expected_path" ]]; then
    worktree_path="$expected_path"
    # Get the actual branch the worktree is on
    worktree_branch=$(git worktree list --porcelain | grep -A1 "worktree $worktree_path" | grep "branch refs/heads/" | sed 's/.*branch refs\/heads\///')
  else
    # Try to find worktree by branch name if directory not found
    worktree_branch="$name"
    worktree_path=$(git worktree list --porcelain | awk -v branch="$worktree_branch" '
      /^worktree / {
        worktree_path = $2
      }
      /^branch refs\/heads\// {
        current_branch = substr($0, 19)
        if (current_branch == branch) {
          print worktree_path
          exit
        }
      }
    ')

    if [[ -z "$worktree_path" ]]; then
      # Worktree not found, but check if the branch exists
      if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        # Branch exists but worktree doesn't - offer to delete the branch
        if [[ "$dry_run" == "true" ]]; then
          echo "🔍 [DRY RUN] Worktree not found but branch exists: $branch_name"
          echo "🔍 [DRY RUN] Would delete branch: $branch_name"
          return 0
        fi

        echo "⚠️  Worktree not found but branch exists: $branch_name"

        if [[ "$force" == "true" ]]; then
          echo "Deleting branch '$branch_name'"
          if git branch -D "$branch_name" 2>/dev/null; then
            echo "✅ Deleted branch '$branch_name'"
          else
            echo "❌ Failed to delete branch '$branch_name'"
            return 1
          fi
        else
          printf "Delete branch '$branch_name'? [y/N] "
          read -r reply
          case "$reply" in
            [yY]|[yY][eE][sS])
              echo "Deleting branch '$branch_name'"
              if git branch -D "$branch_name" 2>/dev/null; then
                echo "✅ Deleted branch '$branch_name'"
              else
                echo "❌ Failed to delete branch '$branch_name'"
                return 1
              fi
              ;;
            *)
              echo "Skipped deleting branch '$branch_name'"
              ;;
          esac
        fi
        return 0
      fi

      # Neither worktree nor branch found
      echo "❌ Worktree not found: $name"
      echo "💡 Available worktrees:"
      git worktree list
      return 1
    fi
  fi

  # Try alternative method if the first one didn't work
  if [[ -z "$worktree_branch" ]]; then
    worktree_branch=$(git worktree list --porcelain | awk -v worktree="$worktree_path" '
      /^worktree/ {
        if ($0 ~ worktree) {
          found=1; next
        } else {
          found=0; next
        }
      }
      found && /^branch refs\/heads\// {
        gsub(/^branch refs\/heads\//, "");
        print;
        exit
      }
    ')
  fi

  # Determine which branch to check for deletion
  local branch_to_check=""
  local is_fallback=false
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    branch_to_check="$branch_name"
  else
    if [[ -n "$worktree_branch" ]] && git show-ref --verify --quiet "refs/heads/$worktree_branch"; then
      branch_to_check="$worktree_branch"
      is_fallback=true
      echo "Expected branch '$branch_name' not found, but worktree was on branch '$worktree_branch'"
    fi
  fi

  if [[ "$dry_run" == "true" ]]; then
    echo "🔍 [DRY RUN] Would remove worktree: $worktree_path"
    if [[ -n "$branch_to_check" ]]; then
      # Safeguard: Never delete main/master branches
      if [[ "$branch_to_check" == "main" || "$branch_to_check" == "master" ]]; then
        echo "🔍 [DRY RUN] Would skip deletion of main branch '$branch_to_check'"
      else
        # Check if branch has uncommitted changes
        if ! git diff --quiet "HEAD" "$branch_to_check" 2>/dev/null; then
          echo "🔍 [DRY RUN] Would skip deletion of branch '$branch_to_check' (has changes)"
        else
          # Check if branch is ahead/behind or has different commits
          local base_commit=$(git merge-base "HEAD" "$branch_to_check" 2>/dev/null)
          if [[ -n "$base_commit" ]] && git diff --quiet "$base_commit" "$branch_to_check" 2>/dev/null; then
            echo "🔍 [DRY RUN] Would delete branch: $branch_to_check"
          else
            # Branch has diverged, but check if content is identical (e.g., squash merge case)
            if git diff --quiet "HEAD" "$branch_to_check" 2>/dev/null; then
              echo "🔍 [DRY RUN] Would delete branch: $branch_to_check (diverged but content identical - likely squash merged)"
            else
              echo "🔍 [DRY RUN] Would skip deletion of branch '$branch_to_check' (has diverged)"
            fi
          fi
        fi
      fi
    fi
  else
    # Check if we can safely delete the branch BEFORE removing the worktree
    local can_delete_branch=false
    local branch_deletion_reason=""

    if [[ -n "$branch_to_check" ]]; then
      # Safeguard: Never delete main/master branches
      if [[ "$branch_to_check" == "main" || "$branch_to_check" == "master" ]]; then
        branch_deletion_reason="main branch"
      else
        # Check if branch has uncommitted changes
        if ! git diff --quiet "HEAD" "$branch_to_check" 2>/dev/null; then
          branch_deletion_reason="has changes"
        else
          # Check if branch is ahead/behind or has different commits
          local base_commit=$(git merge-base "HEAD" "$branch_to_check" 2>/dev/null)
          if [[ -n "$base_commit" ]] && git diff --quiet "$base_commit" "$branch_to_check" 2>/dev/null; then
            can_delete_branch=true
          else
            # Branch has diverged, but check if content is identical (e.g., squash merge case)
            if git diff --quiet "HEAD" "$branch_to_check" 2>/dev/null; then
              echo "🔍 Branch '$branch_to_check' has diverged but content is identical (likely squash merged)"
              can_delete_branch=true
            else
              branch_deletion_reason="has diverged"
            fi
          fi
        fi
      fi
    fi

    # Check if we're currently in the worktree being removed
    local current_dir="$(pwd)"
    local main_worktree="$(_gtr_get_main_worktree)"
    local need_to_cd_back=false

    if [[ "$current_dir" == "$worktree_path" ]]; then
      echo "🔄 Currently in worktree being removed, changing to main repository..."
      cd "$main_worktree" || {
        echo "❌ Failed to change to main repository directory"
        return 1
      }
      need_to_cd_back=true
    fi

    # Execute pre-remove hook
    if ! _gtr_execute_pre_remove_hook "$name" "$worktree_path" "$worktree_branch" "$force" "$dry_run" "$main_worktree"; then
      echo "❌ Pre-remove hook failed, aborting worktree removal"
      if [[ "$need_to_cd_back" == "true" ]]; then
        cd "$current_dir" || echo "⚠️  Could not change back to original directory"
      fi
      return 1
    fi

    # Only remove the worktree if we can delete the branch OR force is used
    if [[ "$can_delete_branch" == "true" || "$force" == "true" ]]; then
      # Remove the worktree
      if git worktree remove "$worktree_path"; then
        echo "Removed worktree '$name'"

        # Now handle branch deletion based on our earlier checks
        if [[ -n "$branch_to_check" ]]; then
          if [[ "$can_delete_branch" == "true" ]]; then
            # Always ask for confirmation if this is a fallback branch, even with --force
            if [[ "$is_fallback" == "true" ]]; then
              printf "Delete branch '$branch_to_check' (no changes)? [y/N] "
              read -r reply
              case "$reply" in
                [yY]|[yY][eE][sS])
                  echo "Deleting branch '$branch_to_check'"
                  git branch -d "$branch_to_check" 2>/dev/null || echo "Could not delete branch '$branch_to_check'"
                  ;;
                *)
                  echo "Skipped deleting branch '$branch_to_check'"
                  ;;
              esac
            elif [[ "$force" == "true" ]]; then
              echo "Deleting branch '$branch_to_check' (no changes)"
              git branch -d "$branch_to_check" 2>/dev/null || echo "Could not delete branch '$branch_to_check'"
            else
              printf "Delete branch '$branch_to_check' (no changes)? [y/N] "
              read -r reply
              case "$reply" in
                [yY]|[yY][eE][sS])
                  echo "Deleting branch '$branch_to_check'"
                  git branch -d "$branch_to_check" 2>/dev/null || echo "Could not delete branch '$branch_to_check'"
                  ;;
                *)
                  echo "Skipped deleting branch '$branch_to_check'"
                  ;;
              esac
            fi
          else
            echo "Branch '$branch_to_check' $branch_deletion_reason. Not deleting."
          fi
        fi

        # Execute post-remove hook
        _gtr_execute_post_remove_hook "$name" "$worktree_path" "$worktree_branch" "$force" "$dry_run" "$main_worktree"

        # If we changed directories, we can't go back to the original worktree since it's deleted
        if [[ "$need_to_cd_back" == "true" ]]; then
          echo "✅ Worktree removed successfully. You're now in the main repository."
        fi
      else
        echo "Failed to remove worktree '$name'"

        # If we changed directories and removal failed, change back to original directory
        if [[ "$need_to_cd_back" == "true" ]]; then
          echo "🔄 Changing back to original worktree directory..."
          cd "$current_dir" || echo "⚠️  Could not change back to original directory"
        fi
      fi
    else
      # Worktree removal blocked because branch can't be safely deleted
      if [[ -n "$branch_to_check" ]]; then
        echo "❌ Cannot remove worktree '$name'"
        echo "   Branch '$branch_to_check' $branch_deletion_reason."
        echo "   Use --force to remove anyway."
      else
        echo "❌ Cannot remove worktree '$name' (no associated branch found)"
        echo "   Use --force to remove anyway."
      fi

      # If we changed directories, change back to original directory
      if [[ "$need_to_cd_back" == "true" ]]; then
        echo "🔄 Changing back to original worktree directory..."
        cd "$current_dir" || echo "⚠️  Could not change back to original directory"
      fi
    fi
  fi
}

_gtr_prune_worktrees() {
  local base_branch="${_GTR_BASE_BRANCH:-main}"
  local dry_run="${_GTR_DRY_RUN:-false}"
  local force="${_GTR_FORCE:-false}"
  local base="$(_gtr_get_base_dir)"
  local main_worktree="$(_gtr_get_main_worktree)"

  echo "🧹 Cleaning up merged worktrees (base: $base_branch)..."

  # Execute pre-prune hook
  if ! _gtr_execute_pre_prune_hook "$base_branch" "$dry_run" "$force" "$main_worktree"; then
    echo "❌ Pre-prune hook failed, aborting prune operation"
    return 1
  fi

  # Parse worktrees using a more robust approach
  local -a worktree_paths
  local -a branch_names

  # Read worktree data into arrays
  while IFS='|' read -r worktree_path branch_name; do
    if [[ -n "$worktree_path" && -n "$branch_name" ]]; then
      worktree_paths+=("$worktree_path")
      branch_names+=("$branch_name")
    fi
  done < <(git worktree list --porcelain | awk -v main_worktree="$main_worktree" '
    /^worktree / {
      worktree_path = $2
      if (worktree_path != main_worktree) {
        worktrees[worktree_path] = ""
      }
    }
    /^branch refs\/heads\// {
      if (worktree_path != main_worktree) {
        worktrees[worktree_path] = substr($0, 19)  # Remove "branch refs/heads/"
      }
    }
    END {
      for (wt in worktrees) {
        if (worktrees[wt] != "") {
          print wt "|" worktrees[wt]
        }
      }
    }
  ')

  # Process each worktree
  for i in "${!worktree_paths[@]}"; do
    local worktree_path="${worktree_paths[$i]}"
    local branch_name="${branch_names[$i]}"

    local should_remove=false
    local reason=""

    # Check if branch is merged using multiple strategies
    if git branch --merged "$base_branch" | grep -q "^[[:space:]]*$branch_name$"; then
      should_remove=true
      reason="merged into $base_branch"
    elif git merge-base --is-ancestor "$branch_name" "$base_branch" 2>/dev/null; then
      should_remove=true
      reason="ancestor of $base_branch"
    else
      # Check if the branch's commits are all in the base branch (squash merge case)
      local branch_commits=$(git rev-list "$branch_name" --not "$base_branch" 2>/dev/null | wc -l)
      if [[ "$branch_commits" -eq 0 ]]; then
        should_remove=true
        reason="all commits present in $base_branch (squash merged)"
      else
        # Fallback: Check if content is identical despite diverged history (squash merge scenario)
        if git diff --quiet "$base_branch" "$branch_name" 2>/dev/null; then
          should_remove=true
          reason="diverged but content identical (likely squash merged)"
        fi
      fi
    fi

    if [[ "$should_remove" == "true" ]]; then
      if [[ "$dry_run" == "true" ]]; then
        echo "🔍 [DRY RUN] Would remove: $worktree_path ($branch_name) - $reason"
      else
        if [[ "$force" == "true" ]]; then
          echo "🗑️  Removing: $worktree_path ($branch_name) - $reason"
          git worktree remove "$worktree_path" 2>/dev/null && \
          git branch -d "$branch_name" 2>/dev/null || \
          echo "⚠️  Could not remove worktree or branch: $worktree_path ($branch_name)"
        else
          local reply
          reply=$(_gtr_ask_user "Remove worktree '$worktree_path' ($branch_name) - $reason? [y/N] " "N")
          case "$reply" in
            [yY]|[yY][eE][sS])
              echo "🗑️  Removing: $worktree_path ($branch_name)"
              git worktree remove "$worktree_path" 2>/dev/null && \
              git branch -d "$branch_name" 2>/dev/null || \
              echo "⚠️  Could not remove worktree or branch: $worktree_path ($branch_name)"
              ;;
            *)
              echo "⏭️  Skipped: $worktree_path ($branch_name)"
              ;;
          esac
        fi
      fi
    else
      echo "✅ Keeping: $worktree_path ($branch_name) - not merged"
    fi
  done

  # Execute post-prune hook
  _gtr_execute_post_prune_hook "$base_branch" "$dry_run" "$force" "$main_worktree"

  if [[ "$dry_run" == "true" ]]; then
    echo "🔍 Dry run complete! Use without --dry-run to actually remove worktrees."
  else
    echo "✨ Cleanup complete!"
  fi
}