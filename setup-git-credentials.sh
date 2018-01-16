# Passthrough git credentials
if [ -z "$GHUSERNAME" ]
then
  read -p "Github Username (application account): " GHUSERNAME
fi
if [ -z "$GHTOKEN" ]
then
  read -s -p "Github Personal Access Token (invisible while typing): " GHTOKEN
fi
echo "Clearing and setting up .git-credentials..."
GIT_CRED_DIR="$HOME/.config/git"
GIT_CRED_PATH="$GIT_CRED_DIR/credentials"
echo "${GIT_CRED_PATH}"
rm -rf "${GIT_CRED_PATH}"
mkdir -p "${GIT_CRED_DIR}"
echo "https://${GHUSERNAME}:${GHTOKEN}@github.com" > "${GIT_CRED_PATH}"
cat "${GIT_CRED_PATH}"
git config --global credential.helper  "store --file ${GIT_CRED_PATH}"
