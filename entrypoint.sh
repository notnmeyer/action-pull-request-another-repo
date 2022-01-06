#!/bin/sh
set -ex

CLONE_DIR=$(mktemp -d)

main() {
    verify
    git_configure
    git_clone_destination_repo
    git_prepare_destination_branch
    create_pull_request
}

# verify env is set
verify() {
    [ -z "$INPUT_SOURCE_FOLDER" ] && echo "Source folder must be defined" && exit 1
    [ -z "$INPUT_PR_TITLE" ] && echo "PR title must be defined" && exit 1
    [ -z "$INPUT_PR_DESCRIPTION" ] && echo "PR description must be defined" && exit 1
    [ -n "$INPUT_PULL_REQUEST_REVIEWERS" ] && PULL_REQUEST_REVIEWERS="-r $INPUT_PULL_REQUEST_REVIEWERS"

    if [ "$INPUT_DESTINATION_HEAD_BRANCH" = "main" ] || [ "$INPUT_DESTINATION_HEAD_BRANCH" = "master" ]; then
        echo "Destination head branch cannot be 'main' or 'master'"
        exit 1
    fi
}

# initial git client config
git_configure() {
    echo "Setting git variables"
    export GITHUB_TOKEN="$API_TOKEN_GITHUB"
    git config --global user.email "$INPUT_USER_EMAIL"
    git config --global user.name "$INPUT_USER_NAME"
}

# clone the destination repo
git_clone_destination_repo() {
    echo "Cloning destination git repository"
    git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

}

# copy the files between repos and create a destination branch
git_prepare_destination_branch() {
    echo "Copying contents to git repo"
    mkdir -p "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"

    # `--delete` removes any files in the destination not present in the source folder
    # `--exclude=.git/` prevents the destination's .git dir from being deleted
    rsync \
        -a "$INPUT_SOURCE_FOLDER/" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/" \
        --delete \
        --exclude ".git/"

    cd "$CLONE_DIR"
    git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"
    git add .

    # commit changes
    if git status | grep -q "Changes to be committed"; then
        git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
        echo "Pushing git commit"
        git push -u origin "HEAD:$INPUT_DESTINATION_HEAD_BRANCH"
    else
        echo "No changes detected"
        exit 0
    fi
}

create_pull_request() {
    echo "Creating a pull request"
    gh pr create \
        --title "$INPUT_PR_TITLE" \
        --body "$INPUT_PR_DESCRIPTION" \
        --base "$INPUT_DESTINATION_BASE_BRANCH" \
        --head "$INPUT_DESTINATION_HEAD_BRANCH" \
        $PULL_REQUEST_REVIEWERS
}

main
