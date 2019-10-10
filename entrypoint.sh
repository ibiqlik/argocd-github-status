#!/bin/sh

# Required environment variables:
#     ARGOCD_SERVER
#     ARGOCD_ADMIN_PASS or ARGOCD_TOKEN
#     ARGOCD_APP
#     ARGOCD_HOOKSTATE
#     GITHUB_TOKEN

if [ -z "$ARGOCD_SERVER" ] || [ -z "$ARGOCD_APP" ] || [ -z "$ARGOCD_HOOKSTATE" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo 'One or more of the required variables are not set'
  exit 1
fi

# Determine if Admin pass or Token was provided
if [ -z "$ARGOCD_TOKEN" ] && [ -z "$ARGOCD_ADMIN_PASS" ]; then
    echo "Missing ARGOCD_TOKEN or ARGOCD_ADMIN_PASS"
    exit 1
fi

if [ ! -z "$ARGOCD_ADMIN_PASS" ]; then
    ARGOCD_TOKEN=$(curl -s $ARGOCD_SERVER/api/v1/session -d "{\"username\": \"admin\", \"password\": \"$ARGOCD_ADMIN_PASS\"}" | jq -r .token)
fi

if [ -z "$ARGOCD_TOKEN" ]; then
    echo "ARGOCD_TOKEN is empty"
    exit 1
fi

# Get token, or simply use it if it was provided as env var
# curl -s $ARGOCD_SERVER/api/v1/applications -H "Authorization: Bearer $ARGOCD_TOKEN" > tmp.json
curl -s $ARGOCD_SERVER/api/v1/applications --cookie "argocd.token=$ARGOCD_TOKEN" > tmp.json

# Set app url to include in the message
ARGOCD_APP_URL="$ARGOCD_SERVER/applications/$ARGOCD_APP"

# Get revision a.k.a sha commit
REVISION=$(jq -r '.items[] | select( .metadata.name == "'$ARGOCD_APP'") | .status.operationState.operation.sync.revision' tmp.json)

# Get information about git repo
REPO_URL=$(jq -r '.items[] | select( .metadata.name == "'$ARGOCD_APP'") | .spec.source.repoURL' tmp.json)
REPO_URL=${REPO_URL%.git*}
REPO_OWNER=$(echo ${REPO_URL##http**.com} | cut -d '/' -f2)
REPO=$(echo ${REPO_URL##http**.com} | cut -d '/' -f3)

case $ARGOCD_HOOKSTATE in
    PreSync)
        GITHUB_STATE="pending"
    ;;
    SyncFail)
        GITHUB_STATE="error"
    ;;
    PostSync)
        GITHUB_STATE="success"
    ;;
    *)
        GITHUB_STATE="failure" # Not sure how to deal here
    ;;
esac

echo $GITHUB_STATE
echo $REVISION

if [ -z "$GITHUB_STATE" ] && [ -z "$REVISION" ]; then
    echo "Missing GITHUB_STATE and/or REVISION"
    exit 1
fi

curl https://api.github.com/repos/$REPO_OWNER/$REPO/statuses/$REVISION?access_token=$GITHUB_TOKEN \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"state\": \"$GITHUB_STATE\", \"description\": \"ArgoCD\", \"target_url\": \"$ARGOCD_APP_URL\", \"context\": \"continuous-delivery/$ARGOCD_APP\"}"
