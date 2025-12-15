#!/usr/bin/env bash

# Skip if we're already in an amend operation (prevents double-running)
if [ -n "$BORZOI_AMENDING" ]; then
    exit 0
fi

# Get the commit message
commit_msg=$(git log -1 --pretty=%B)

# Pattern to match issue IDs (4-digit hex after "fix:" or "close:")
# Matches: fix: ABCD, close: 1a2b, etc.
pattern='(fix|close|closes|fixed):? ?([0-9a-fA-F]{4})'

# Track if any issues were closed
issues_closed=false

# Find all matches in the commit message
while [[ $commit_msg =~ $pattern ]]; do
    issue_id="${BASH_REMATCH[2]^^}"
    
    echo "Found issue reference: $issue_id"
    echo "Closing issue $issue_id..."
    
    # Run borzoi close command
    if borzoi close "$issue_id"; then
        echo "Successfully closed issue $issue_id"
        issues_closed=true
        
        # Stage the changed issue file
        git add ".borzoi/$issue_id.md" 2>/dev/null || git add issues/ 2>/dev/null
    else
        echo "Warning: Failed to close issue $issue_id"
    fi
    
    # Remove the matched part to find next occurrence
    commit_msg="${commit_msg#*${BASH_REMATCH[0]}}"
done

# If issues were closed, amend the commit to include the changes
if [ "$issues_closed" = true ]; then
    echo "Amending commit to include closed issues..."
    BORZOI_AMENDING=1 git commit --amend --no-edit --no-verify
fi

exit 0
