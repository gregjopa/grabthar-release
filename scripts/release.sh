#!/bin/bash

set -e;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
$DIR/grabthar-validate;

if npm whoami &> /dev/null; then
    echo "npm username: $(npm whoami)"
else
    echo "You must be logged in to publish a release. Running 'npm login'"
    npm login
fi

org=$(node --eval "
    const PACKAGE = './package.json';
    let pkg = require(PACKAGE);
    if (pkg.name.indexOf('@') === 0) {
        console.log(pkg.name.split('/')[0].slice(1));
    }
")

if [ "$org" ]; then
    USER_ROLE=$(npm org ls $org "$(npm whoami)" --json)

    PERMISSION=$(node --eval "
        let userRole = $USER_ROLE;
        console.log(userRole['$(npm whoami)']);
    " "$USER_ROLE")

    if [ ! "$PERMISSION" = "developer" ]; then
        if [ ! "$PERMISSION" = "owner" ]; then
            echo "ERROR: You must be assigned the developer or owner role in the npm $org org to publish";
            exit 1;
        fi
    fi
fi;

if [ -z "$DIST_TAG" ]; then
    DIST_TAG="latest";
fi;

npm version patch;

git push;
git push --tags;
npm run flatten;
npm publish --tag $DIST_TAG;
git checkout package.json;
git checkout package-lock.json;

sleep 5;

$DIR/grabthar-cdnify --recursive --cdn="$CDN" --disttag="$DIST_TAG";
