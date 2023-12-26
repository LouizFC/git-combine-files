#!/bin/bash

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <source_file1> <source_file2> ... <target_file>"
  exit 1
fi

source_files=()
target_file=""
for ((i = 1; i <= $#; i++)); do
  file="${!i}"
  if [ "$i" -eq $# ]; then
    target_file="$file"
  else
    source_files+=("$file")
  fi
done

# Create a branch instead of manipulating the main branch directly
branch_name="combine-files-to-$target_file"
git checkout -b "$branch_name"

# Create a new branch for each source file to target file combination
source_branches=()
for file in "${source_files[@]}"; do
  source_branch="combine-${file%.*}-to-$target_file"
  source_branches+=("$source_branch")
  git checkout -b "$source_branch" "$branch_name"
  git mv "$file" "$target_file"
  git commit -m "$file to $target_file"
  git checkout "$branch_name"
done

for file in "${source_files[@]}"; do
  cat "$file" >>"$target_file"
  echo >>"$target_file"
done

git rm "${source_files[@]}"
git add "$target_file"

# Create a commit using Raymond Chen write-tree + commit-tree technique
tree_hash=$(git write-tree)
commit_args=()
for source_branch in "${source_branches[@]}"; do
  commit_args+=(-p "$source_branch")
done
commit_hash=$(git commit-tree "$tree_hash" -p HEAD "${commit_args[@]}" -m "Combine ${source_files[*]} into $target_file")

# Fast-forward merge the combined changes to the final commit
git merge --ff-only "$commit_hash"

# Remove intermediate branches
for source_branch in "${source_branches[@]}"; do
  git branch -D "$source_branch"
done

echo "Merging of ${source_files[*]} into $target_file completed successfully."
