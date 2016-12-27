#!/usr/bin/env bash
#
# Script to upload a release asset using the GitHub API v3.
# https://gist.github.com/stefanbuck/ce788fee19ab6eb0b4447a85fc99f447
# Author: Stefan Buck
#
# Example:
# upload-github-release-asset.sh github_api_token=TOKEN owner=stefanbuck repo=playground tag=v0.1.0 filename=./build.zip
#

# Check dependencies.
set -e
xargs=$(which gxargs || which xargs)

# Validate settings.
[ "$TRACE" ] && set -x

CONFIG=$@

for line in $CONFIG; do
  eval "$line"
done

# Check if current tag is correct
#assembly_version_validator='^v[0-9]{2}.(0[1-9]|1[0-2]).(0[1-9]|[1-2][0-9]|3[0-1])$'
#if [[ ! $tag =~ $assembly_version_validator ]];
#then
#	WriteLine "Tag $tag not matching regex "
#	exit 1
#fi

# Remove "v" from tag
version="${tag/v/}" # TODO doesn't work with tag "LATEST" for the moment

# git tag -a
git tag -a $tag -m "Release of version $version"

#TODO: search token in file on V: or I:

# Define variables.
GH_API="https://api.github.com"
GH_REPO="$GH_API/repos/$owner/$repo"
GH_TAGS="$GH_REPO/releases/tags/$tag"
AUTH="Authorization: token $github_api_token"
WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
CURL_ARGS="-LJO#"

if [[ "$tag" == 'LATEST' ]]; then
  GH_TAGS="$GH_REPO/releases/latest"
fi


# Validate token.
curl -o /dev/null -sH "$AUTH" $GH_REPO || { echo "Error: Invalid repo, token or network issue!";  exit 1; }

# create release
API_JSON=$(printf '{"tag_name": "v%s","target_commitish": "master","name": "v%s","body": "Release of version %s","draft": false,"prerelease": false}' $version $version $version)
curl --data "$API_JSON" https://api.github.com/repos/$owner/$repo/releases?access_token=$github_api_token

# Read asset tags.
response=$(curl -sH "$AUTH" $GH_TAGS)

# Get ID of the asset based on given filename.
eval $(echo "$response" | grep -m 1 "id.:" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')
[ "$id" ] || { echo "Error: Failed to get release id for tag: $tag"; echo "$response" | awk 'length($0)<100' >&2; exit 1; }

# Upload asset
echo "Uploading asset... $filename" >&2

# Construct url
GH_ASSET="https://uploads.github.com/repos/$owner/$repo/releases/$id/assets?name=$(basename $filename)"

curl "$GITHUB_OAUTH_BASIC" --data-binary @"$filename" -H "Authorization: token $github_api_token" -H "Content-Type: application/zip" $GH_ASSET

echo "Done."

