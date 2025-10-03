#!/bin/bash

# gtr-commands.sh - Command dispatcher
# This file contains the main command dispatcher that routes to individual command files

# Note: Individual command implementations are now in separate files:
# - gtr-create.sh: Create worktree command
# - gtr-remove.sh: Remove worktree command  
# - gtr-cd.sh: Change directory command
# - gtr-list.sh: List worktrees command
# - gtr-claude.sh: Run claude in worktree command
# - gtr-cursor.sh: Run cursor in worktree command
# - gtr-prune.sh: Prune merged worktrees command
# - gtr-init.sh: Initialize configuration command
# - gtr-doctor.sh: Check and fix worktree files command
# - gtr-generate.sh: Generate hooks and resources command
# - gtr-ideas.sh: Idea management commands

# All command functions are now defined in their respective files and sourced
# by the main gtr script. This file serves as documentation and could contain
# shared command utilities if needed in the future.