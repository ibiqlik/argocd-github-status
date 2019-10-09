#!/bin/sh

# Required environment variables:
#     ARGOCD_SERVER
#     ARGOCD_ADMIN_PASS
#     ARGOCD_APP
#     ARGOCD_APP_URL
#     ARGOCD_HOOKSTATE
#     GITHUB_OWNER
#     GITHUB_REPO
#     GITHUB_TOKEN

# TODO:
#     Check that all required variables are available
#     Get version of ArgoCD to determine which api auth method to use (cookie vs bearer)

# Get token
ARGOCD_TOKEN=$(curl -s $ARGOCD_SERVER/api/v1/session -d $'{"username":"admin","password":"'$ARGOCD_ADMIN_PASS'"}' | jq -r .token)

# Get applications
# curl -s $ARGOCD_SERVER/api/v1/applications -H "Authorization: Bearer $ARGOCD_TOKEN" > tmp.json
curl -s $ARGOCD_SERVER/api/v1/applications --cookie "argocd.token=$ARGOCD_TOKEN" > tmp.json

# Get revision a.k.a sha commit
REVISION=$(jq -r '.items[] | select( .metadata.name == "'$ARGOCD_APP'") | .status.operationState.operation.sync.revision' tmp.json)

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

curl https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/statuses/$REVISION?access_token=$GITHUB_TOKEN \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"state\": \"$GITHUB_STATE\", \"description\": \"ArgoCD\", \"target_url\": \"$ARGOCD_APP_URL\", \"context\": \"continuous-delivery/$ARGOCD_APP\"}"
