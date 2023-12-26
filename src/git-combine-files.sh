#!/bin/bash

check_arguments() {
  if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <source_file1> <source_file2> ... <target_file>"
    exit 1
  fi
}

extract_file_names() {
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
}

checkout_to_combined_branch() {
  local branch_name="combine-files-to-$target_file"
  git checkout -b "$branch_name"
  echo "$branch_name"
}

create_branch_and_move_file() {
  local file="$1"
  local source_branch="combine-${file%.*}-to-${target_file%.*}"

  git checkout -b "$source_branch" "$combined_branch"
  git mv "$file" "$target_file"
  git commit -m "combine $file to $target_file"

  source_branches+=("$source_branch")
}

combine_files() {
  for file in "${source_files[@]}"; do
    cat "$file" >>"$target_file"
    echo >>"$target_file"
  done

  git rm "${source_files[@]}"
  git add "$target_file"
}

commit_combined_file() {
  local commit_args=()
  local message="Combine ${source_files[*]} into $target_file"

  for source_branch in "${source_branches[@]}"; do
    commit_args+=(-p "$source_branch")
  done
  commit_hash=$(git commit-tree "$(git write-tree)" -p HEAD "${commit_args[@]}" -m "$message")
}

merge_into_combined_branch() {
  git merge --ff-only "$commit_hash"
}

remove_intermediate_branches() {
  for source_branch in "${source_branches[@]}"; do
    git branch -D "$source_branch"
  done
}

main() {
  check_arguments "$@"
  extract_file_names "$@"

  combined_branch="$(checkout_to_combined_branch)"
  source_branches=()

  for file in "${source_files[@]}"; do
    create_branch_and_move_file "$file"
    git checkout "$combined_branch"
  done

  combine_files
  commit_combined_file
  merge_into_combined_branch

  remove_intermediate_branches

  echo "Merging of ${source_files[*]} into $target_file completed successfully."
}

main "$@"
