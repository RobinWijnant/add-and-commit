#!/bin/bash
set -u

cd $INPUT_CWD
echo "Running in $PWD."

# Set up .netrc file with GitHub credentials
git_setup() {
    cat <<-EOF >$HOME/.netrc
        machine github.com
        login $GITHUB_ACTOR
        password $GITHUB_TOKEN

        machine api.github.com
        login $GITHUB_ACTOR
        password $GITHUB_TOKEN
EOF
    chmod 600 $HOME/.netrc
    git config --global user.email "$INPUT_AUTHOR_EMAIL"
    git config --global user.name "$INPUT_AUTHOR_NAME"
}

add() {
    if $INPUT_FORCE; then f=-f; else f=; fi
    git add $INPUT_ADD $f
}

remove() {
    if [ -n "$INPUT_REMOVE" ]; then git rm $INPUT_REMOVE; fi
}

# This is needed to make the check work for untracked files
echo "Staging files..."
add
remove

echo "Checking for uncommitted changes in the git working tree..."
# This section only runs if there have been file changes
if ! git diff --cached --quiet --exit-code; then
    git_setup

    git fetch

    # Verify if the branch needs to be created
    if ! git rev-parse --verify --quiet "${GITHUB_REF:11}"; then
        echo "Creating branch..."
        git branch "${GITHUB_REF:11}"
    fi

    # Switch to branch from current workflow run
    echo "Switching branch..."
    git checkout "${GITHUB_REF:11}"

    echo "Pulling from remote..."
    git fetch && git pull

    echo "Resetting files..."
    git reset

    echo "Adding files..."
    add

    echo "Removing files..."
    remove

    echo "Creating commit..."
    git commit -m "$INPUT_MESSAGE" --author="$INPUT_AUTHOR_NAME <$INPUT_AUTHOR_EMAIL>"

    echo "Pushing to repo..."
    git push --set-upstream origin "${GITHUB_REF:11}"
else
    echo "Working tree clean. Nothing to commit."
fi
