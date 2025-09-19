#!/bin/bash

# gtr-ideas.sh - Idea management functions
# Contains all idea-related helper functions and commands

# Helper function to get all worktree directories
# Usage: _gtr_get_all_worktree_dirs
# Returns: array of all worktree directories including main repo
_gtr_get_all_worktree_dirs() {
  local main_worktree="$(_gtr_get_main_worktree)"
  local worktree_dirs=("$main_worktree")
  
  # Get all worktrees from git
  while IFS= read -r worktree_path; do
    if [[ -n "$worktree_path" && "$worktree_path" != "$main_worktree" ]]; then
      worktree_dirs+=("$worktree_path")
    fi
  done < <(git worktree list --porcelain | grep "^worktree " | cut -d' ' -f2- 2>/dev/null)
  
  echo "${worktree_dirs[@]}"
}

# Helper function to list ideas with filtering (cross-worktree version)
# Usage: _gtr_list_ideas [--mine] [--todo] [--status=STATUS] [--filter=STRING]
# Returns: list of idea files with metadata
_gtr_list_ideas() {
  local show_mine="false"
  local show_todo="false"
  local status_filter=""
  local content_filter=""
  local username="${_GTR_USERNAME:-$(whoami)}"
  
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --mine)
        show_mine="true"
        ;;
      --todo)
        show_todo="true"
        ;;
      --status=*)
        status_filter="${arg#*=}"
        ;;
      --filter=*)
        content_filter="${arg#*=}"
        ;;
    esac
  done
  
  # Get all worktree directories
  local worktree_dirs=($(_gtr_get_all_worktree_dirs))
  local idea_files=()
  
  # Search for idea files in all worktrees
  for worktree_dir in "${worktree_dirs[@]}"; do
    local ideas_dir="$worktree_dir/.gtr/ideas"
    if [[ -d "$ideas_dir" ]]; then
      while IFS= read -r -d '' file; do
        if [[ -f "$file" && "$file" == *.md ]]; then
          idea_files+=("$file")
        fi
      done < <(find "$ideas_dir" -name "*.md" -type f -print0 2>/dev/null)
    fi
  done
  
  if [[ ${#idea_files[@]} -eq 0 ]]; then
    echo "No ideas found. Create your first idea with 'gtr idea create'"
    return 0
  fi
  
  # Sort by creation date (newest first) using filename timestamp
  IFS=$'\n' idea_files=($(printf '%s\n' "${idea_files[@]}" | sort -r))
  
  echo "📋 Ideas:"
  echo ""
  
  for file in "${idea_files[@]}"; do
    local filename=$(basename "$file")
    local worktree_name=$(basename "$(dirname "$(dirname "$file")")")
    local author=""
    local summary=""
    local status=""
    local datetime=""
    local repo_name=""
    local current_branch=""
    
    # Extract metadata from YAML front matter
    local in_frontmatter=false
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        if [[ "$in_frontmatter" == "false" ]]; then
          in_frontmatter=true
        else
          break
        fi
      elif [[ "$in_frontmatter" == "true" ]]; then
        case "$line" in
          author:*)
            author="${line#author: }"
            author="${author%\"}"
            author="${author#\"}"
            ;;
          summary:*)
            summary="${line#summary: }"
            summary="${summary%\"}"
            summary="${summary#\"}"
            ;;
          status:*)
            status="${line#status: }"
            status="${status%\"}"
            status="${status#\"}"
            ;;
          datetime:*)
            datetime="${line#datetime: }"
            datetime="${datetime%\"}"
            datetime="${datetime#\"}"
            ;;
          repo_name:*)
            repo_name="${line#repo_name: }"
            repo_name="${repo_name%\"}"
            repo_name="${repo_name#\"}"
            ;;
          current_branch_name:*)
            current_branch="${line#current_branch_name: }"
            current_branch="${current_branch%\"}"
            current_branch="${current_branch#\"}"
            ;;
        esac
      fi
    done < "$file"
    
    # Apply filters
    local should_show=true
    
    if [[ "$show_mine" == "true" && "$author" != "$username" ]]; then
      should_show=false
    fi
    
    if [[ "$show_todo" == "true" && "$status" != "TODO" ]]; then
      should_show=false
    fi
    
    if [[ -n "$status_filter" && "$status" != "$status_filter" ]]; then
      should_show=false
    fi
    
    # Apply content filter (search in summary and file content)
    if [[ -n "$content_filter" ]]; then
      local content_matches=false
      
      # Check if summary matches (case-insensitive)
      local summary_lower=$(echo "$summary" | tr '[:upper:]' '[:lower:]')
      local filter_lower=$(echo "$content_filter" | tr '[:upper:]' '[:lower:]')
      if [[ "$summary_lower" == *"$filter_lower"* ]]; then
        content_matches=true
      fi
      
      # Check if file content matches (excluding frontmatter, case-insensitive)
      if [[ "$content_matches" == "false" ]]; then
        local in_frontmatter=false
        while IFS= read -r line; do
          if [[ "$line" == "---" ]]; then
            if [[ "$in_frontmatter" == "false" ]]; then
              in_frontmatter=true
            else
              in_frontmatter=false
            fi
          elif [[ "$in_frontmatter" == "false" ]]; then
            local line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
            if [[ "$line_lower" == *"$filter_lower"* ]]; then
              content_matches=true
              break
            fi
          fi
        done < "$file"
      fi
      
      if [[ "$content_matches" == "false" ]]; then
        should_show=false
      fi
    fi
    
    if [[ "$should_show" == "true" ]]; then
      # Format datetime for display
      local display_date=""
      if [[ -n "$datetime" ]]; then
        display_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$datetime" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$datetime")
      fi
      
      # Display idea with worktree info
      echo "📄 $filename"
      echo "   Summary: $summary"
      echo "   Author:  $author"
      echo "   Status:  $status"
      echo "   Date:    $display_date"
      if [[ "$worktree_name" != "$(basename "$(_gtr_get_main_worktree)")" ]]; then
        echo "   Worktree: $worktree_name ($current_branch)"
      else
        echo "   Worktree: main ($current_branch)"
      fi
      echo ""
    fi
  done
}

# Idea management commands

_gtr_idea_show_help() {
  cat << 'EOF'
gtr idea - Manage development ideas across worktrees

USAGE:
    gtr idea [COMMAND] [OPTIONS] [ARGS...]

COMMANDS:
    create, c [summary]        Create a new idea file (default: prompt for summary)
    list, l [OPTIONS]          List all ideas with optional filtering
    open, o [OPTIONS]          Interactive idea opener with optional filtering
    clear                      Clear all ideas across all worktrees (with confirmation)
    --help, -h                 Show this help message

OPTIONS:
    --mine                     Show only your ideas (for list/open commands)
    --todo                     Show only TODO ideas (for list command)
    --status=STATUS            Filter by status: TODO, IN_PROGRESS, DONE, BLOCKED (for list command)
    --filter=STRING            Search for ideas containing STRING in title or content (for list command)

EXAMPLES:
    # Create ideas
    gtr idea                           # Create idea (prompt for summary)
    gtr idea "New feature idea"        # Create idea with summary
    gtr idea create "Bug fix idea"     # Create idea with explicit command

    # List ideas
    gtr idea list                      # List all ideas
    gtr idea list --mine               # List only your ideas
    gtr idea list --todo               # List only TODO ideas
    gtr idea list --status=IN_PROGRESS # List ideas in progress
    gtr idea list --filter=bug         # Search for ideas containing "bug"

    # Open ideas
    gtr idea open                      # Interactive opener for all ideas
    gtr idea open --mine               # Interactive opener for your ideas only

    # Clear ideas
    gtr idea clear                     # Clear all ideas (with confirmation)

FEATURES:
    • Ideas are stored in .gtr/ideas/ directory
    • Automatic metadata including author, timestamp, repo info
    • Cross-worktree idea discovery and management
    • Rich filtering and search capabilities
    • Interactive idea selection and opening

For more information, visit: https://medium.com/@dtunai/mastering-git-worktrees-with-claude-code-for-parallel-development-workflow-41dc91e645fe
EOF
}

gtr_idea_create() {
  local summary=""
  
  # Check if summary was provided as argument
  if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
    summary="${_GTR_ARGS[0]}"
  fi
  
  # If no summary provided, prompt for it
  if [[ -z "$summary" ]]; then
    printf "Enter idea summary: "
    read -r summary
    if [[ -z "$summary" ]]; then
      echo "❌ No summary provided. Idea creation cancelled."
      return 1
    fi
  fi
  
  # Ensure ideas directory exists
  if ! _gtr_ensure_ideas_dir; then
    return 1
  fi
  
  # Get repository information
  local repo_info="$(_gtr_get_repo_info)"
  IFS='|' read -r repo_name repo_url current_branch latest_commit <<< "$repo_info"
  
  # Generate filename and file path
  local filename="$(_gtr_generate_idea_filename "$summary")"
  local ideas_dir="$(_gtr_get_ideas_dir)"
  local file_path="$ideas_dir/$filename"
  
  # Create idea file content
  local content="$(_gtr_create_idea_content "$summary" "$repo_name" "$repo_url" "$current_branch" "$latest_commit")"
  
  # Write idea file
  if echo "$content" > "$file_path"; then
    echo "✅ Created idea: $filename"
    echo "📁 Location: $file_path"
    
    # Open in editor if configured
    local editor="${_GTR_EDITOR:-cursor}"
    if command -v "$editor" >/dev/null 2>&1; then
      echo "🔧 Opening in $editor..."
      "$editor" "$file_path"
    else
      echo "💡 Open with: $editor \"$file_path\""
    fi
  else
    echo "❌ Failed to create idea file: $file_path"
    return 1
  fi
}

gtr_idea_list() {
  # Parse arguments for filtering
  local filter_args=()
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --mine|--todo|--status=*|--filter=*)
        filter_args+=("$arg")
        ;;
    esac
  done
  
  # List ideas with filters
  _gtr_list_ideas "${filter_args[@]}"
}

gtr_idea_open() {
  # Parse arguments for filtering
  local show_mine="false"
  local username="${_GTR_USERNAME:-$(whoami)}"
  
  for arg in "${_GTR_ARGS[@]}"; do
    case "$arg" in
      --mine)
        show_mine="true"
        ;;
    esac
  done
  
  # Get all worktree directories
  local worktree_dirs=($(_gtr_get_all_worktree_dirs))
  local idea_files=()
  
  # Search for idea files in all worktrees
  for worktree_dir in "${worktree_dirs[@]}"; do
    local ideas_dir="$worktree_dir/.gtr/ideas"
    if [[ -d "$ideas_dir" ]]; then
      while IFS= read -r -d '' file; do
        if [[ -f "$file" && "$file" == *.md ]]; then
          idea_files+=("$file")
        fi
      done < <(find "$ideas_dir" -name "*.md" -type f -print0 2>/dev/null)
    fi
  done
  
  if [[ ${#idea_files[@]} -eq 0 ]]; then
    echo "No ideas found. Create your first idea with 'gtr idea create'"
    return 0
  fi
  
  # Sort by creation date (newest first) using filename timestamp
  IFS=$'\n' idea_files=($(printf '%s\n' "${idea_files[@]}" | sort -r))
  
  # Create array of display strings with branch info and status
  local display_items=()
  local file_paths=()
  
  for file in "${idea_files[@]}"; do
    local filename=$(basename "$file")
    local worktree_name=$(basename "$(dirname "$(dirname "$file")")")
    local summary=""
    local current_branch=""
    local status=""
    local author=""
    
    # Extract metadata from YAML front matter
    local in_frontmatter=false
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        if [[ "$in_frontmatter" == "false" ]]; then
          in_frontmatter=true
        else
          break
        fi
      elif [[ "$in_frontmatter" == "true" ]]; then
        case "$line" in
          summary:*)
            summary="${line#summary: }"
            summary="${summary%\"}"
            summary="${summary#\"}"
            ;;
          current_branch_name:*)
            current_branch="${line#current_branch_name: }"
            current_branch="${current_branch%\"}"
            current_branch="${current_branch#\"}"
            ;;
          status:*)
            status="${line#status: }"
            status="${status%\"}"
            status="${status#\"}"
            ;;
          author:*)
            author="${line#author: }"
            author="${author%\"}"
            author="${author#\"}"
            ;;
        esac
      fi
    done < "$file"
    
    # Apply mine filter
    if [[ "$show_mine" == "true" && "$author" != "$username" ]]; then
      continue
    fi
    
    # Create display string with status
    local display_string=""
    if [[ -n "$summary" ]]; then
      display_string="$summary"
    else
      display_string="$filename"
    fi
    
    # Add status prefix
    if [[ -n "$status" ]]; then
      display_string="[$status] $display_string"
    else
      display_string="[TODO] $display_string"
    fi
    
    # Add worktree/branch info
    if [[ "$worktree_name" != "$(basename "$(_gtr_get_main_worktree)")" ]]; then
      display_string="$display_string ($worktree_name/$current_branch)"
    else
      display_string="$display_string (main/$current_branch)"
    fi
    
    display_items+=("$display_string")
    file_paths+=("$file")
  done
  
  if [[ ${#display_items[@]} -eq 0 ]]; then
    echo "No ideas found matching criteria."
    return 0
  fi
  
  # Interactive selection
  local selected_index=0
  local max_index=$((${#display_items[@]} - 1))
  
  # Function to display menu
  display_menu() {
    clear
    echo "📋 Select idea to open:"
    echo ""
    
    for i in "${!display_items[@]}"; do
      if [[ $i -eq $selected_index ]]; then
        # Highlighted row with background color
        echo -e "\033[48;5;236m  ▶️  ${display_items[$i]}\033[0m"
      else
        echo "     ${display_items[$i]}"
      fi
    done
    
    echo ""
    echo "Use ↑/↓ arrows to navigate, Enter to select, q to quit"
  }
  
  # Function to handle key input
  handle_key() {
    local key
    read -rsn1 key
    
    case "$key" in
      $'\x1b')  # ESC sequence
        read -rsn2 key
        case "$key" in
          '[A')  # Up arrow
            if [[ $selected_index -gt 0 ]]; then
              selected_index=$((selected_index - 1))
            fi
            ;;
          '[B')  # Down arrow
            if [[ $selected_index -lt $max_index ]]; then
              selected_index=$((selected_index + 1))
            fi
            ;;
        esac
        ;;
      '')  # Enter
        return 0
        ;;
      'q')  # Quit
        echo "Cancelled."
        return 1
        ;;
    esac
    return 2
  }
  
  # Main selection loop
  while true; do
    display_menu
    handle_key
    local result=$?
    
    if [[ $result -eq 0 ]]; then
      # Selection made
      local selected_file="${file_paths[$selected_index]}"
      local editor="${_GTR_EDITOR:-cursor}"
      
      if command -v "$editor" >/dev/null 2>&1; then
        echo "🔧 Opening ${display_items[$selected_index]} in $editor..."
        "$editor" "$selected_file"
      else
        echo "💡 Open with: $editor \"$selected_file\""
      fi
      break
    elif [[ $result -eq 1 ]]; then
      # Quit
      break
    fi
    # Continue loop for other keys
  done
}

gtr_idea_clear() {
  # Get all worktree directories to find all idea files
  local worktree_dirs=($(_gtr_get_all_worktree_dirs))
  local idea_files=()
  local total_ideas=0
  
  # Search for idea files in all worktrees
  for worktree_dir in "${worktree_dirs[@]}"; do
    local ideas_dir="$worktree_dir/.gtr/ideas"
    if [[ -d "$ideas_dir" ]]; then
      while IFS= read -r -d '' file; do
        if [[ -f "$file" && "$file" == *.md ]]; then
          idea_files+=("$file")
          ((total_ideas++))
        fi
      done < <(find "$ideas_dir" -name "*.md" -type f -print0 2>/dev/null)
    fi
  done
  
  if [[ $total_ideas -eq 0 ]]; then
    echo "No ideas found to clear."
    return 0
  fi
  
  echo "🗑️  Found $total_ideas idea(s) across all worktrees:"
  echo ""
  
  # Show what will be deleted
  for file in "${idea_files[@]}"; do
    local filename=$(basename "$file")
    local worktree_name=$(basename "$(dirname "$(dirname "$file")")")
    local summary=""
    
    # Extract summary from YAML front matter
    local in_frontmatter=false
    while IFS= read -r line; do
      if [[ "$line" == "---" ]]; then
        if [[ "$in_frontmatter" == "false" ]]; then
          in_frontmatter=true
        else
          break
        fi
      elif [[ "$in_frontmatter" == "true" ]]; then
        case "$line" in
          summary:*)
            summary="${line#summary: }"
            summary="${summary%\"}"
            summary="${summary#\"}"
            break
            ;;
        esac
      fi
    done < "$file"
    
    if [[ -n "$summary" ]]; then
      echo "  📄 $filename: $summary"
    else
      echo "  📄 $filename"
    fi
  done
  
  echo ""
  echo "⚠️  This will permanently delete ALL idea files across all worktrees."
  echo ""
  
  # Ask for confirmation
  echo ""
  printf "Are you sure you want to clear all ideas? Type 'yes' to confirm: "
  read -r confirm
  
  if [[ "$confirm" != "yes" ]]; then
    echo "❌ Idea clearing cancelled."
    return 0
  fi
  
  # Delete all idea files
  local deleted_count=0
  for file in "${idea_files[@]}"; do
    if rm "$file" 2>/dev/null; then
      ((deleted_count++))
    else
      echo "⚠️  Failed to delete: $file"
    fi
  done
  
  echo "✅ Cleared $deleted_count idea(s) successfully."
  
  # Clean up empty ideas directories
  for worktree_dir in "${worktree_dirs[@]}"; do
    local ideas_dir="$worktree_dir/.gtr/ideas"
    if [[ -d "$ideas_dir" ]]; then
      # Check if directory is empty (only contains . and ..)
      if [[ -z "$(ls -A "$ideas_dir" 2>/dev/null)" ]]; then
        rmdir "$ideas_dir" 2>/dev/null && echo "📁 Removed empty ideas directory: $ideas_dir"
      fi
    fi
  done
}

gtr_idea() {
  local subcmd="${_GTR_ARGS[0]:-}"
  
  # Check for help flags first
  if [[ "$subcmd" == "--help" || "$subcmd" == "-h" ]]; then
    _gtr_idea_show_help
    return 0
  fi
  
  # Check if first argument is a known subcommand
  case "$subcmd" in
    c|create|l|list|o|open|clear)
      # Remove the subcommand from args
      if [[ ${#_GTR_ARGS[@]} -gt 0 ]]; then
        _GTR_ARGS=("${_GTR_ARGS[@]:1}")
      fi
      
      case "$subcmd" in
        c|create)
          gtr_idea_create
          ;;
        l|list)
          gtr_idea_list
          ;;
        o|open)
          gtr_idea_open
          ;;
        clear)
          gtr_idea_clear
          ;;
      esac
      ;;
    "")
      # Default to create when no subcommand provided
      gtr_idea_create
      ;;
    *)
      # If first argument doesn't look like a subcommand, treat it as a summary for create
      gtr_idea_create
      ;;
  esac
}
