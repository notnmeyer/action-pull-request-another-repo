#!/bin/sh

set -e
set -x

verify

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
rsync --delete --exclude ".git/" -a $INPUT_SOURCE_FOLDER/ "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
    git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
    echo "Pushing git commit"
    git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH --force
    echo "Creating a pull request"
    gh pr create \
    --title "$INPUT_PR_TITLE" \
    --body "$INPUT_PR_DESCRIPTION" \
    --base $INPUT_DESTINATION_BASE_BRANCH \
    --head $INPUT_DESTINATION_HEAD_BRANCH \
    $PULL_REQUEST_REVIEWERS
else
    echo "No changes detected"
fi

function verify {
    [ -z "$INPUT_SOURCE_FOLDER" ] && echo "Source folder must be defined" && exit 1
    [ -z "$INPUT_PR_TITLE" ] && echo "PR title must be defined" && exit 1
    [ -z "$INPUT_PR_DESCRIPTION" ] && echo "PR description must be defined" && exit 1
    [ -n "$INPUT_PULL_REQUEST_REVIEWERS" ] && PULL_REQUEST_REVIEWERS="-r $INPUT_PULL_REQUEST_REVIEWERS"

    if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master" ]
    then
        echo "Destination head branch cannot be 'main' or 'master'"
        exit 1
    fi
}
