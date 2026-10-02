#!/usr/bin/env bash

# Exit on error, undefined var or pipe error
set -euo pipefail

###############################################################################
# aws-sso-login.sh
#
# Logs in via AWS SSO and writes temporary credentials to ~/.aws/credentials
# so that tools expecting static credentials (Terraform, SDK, etc.) work
# without manual copy-paste from the SSO portal.
#
# Supports two environments via -e/--env, each an account + role pair read
# from the environment (defined in ~/.secrets):
#   dev  (default) → AWS_SSO_DEV_ACCOUNT_ID  / AWS_SSO_DEV_ROLE
#   prod           → AWS_SSO_PROD_ACCOUNT_ID / AWS_SSO_PROD_ROLE
# plus AWS_SSO_START_URL and, optionally, AWS_SSO_REGION (default eu-west-1).
###############################################################################

# --- Defaults ----------------------------------------------------------------
ENV="dev"
SSO_PROFILE="sso"
SSO_START_URL="${AWS_SSO_START_URL:?Set AWS_SSO_START_URL in ~/.secrets}"
SSO_REGION="${AWS_SSO_REGION:-eu-west-1}"
DEFAULT_REGION="$SSO_REGION"
CRED_FILE="$HOME/.aws/credentials"
CONFIG_FILE="$HOME/.aws/config"
# -----------------------------------------------------------------------------

usage() {
	cat <<EOF
Usage: $(basename "$0") [-e|--env dev|prod]

Options:
  -e, --env   Target environment: 'dev' (default) or 'prod'. Account and role
              come from AWS_SSO_<ENV>_ACCOUNT_ID / AWS_SSO_<ENV>_ROLE.
  -h, --help  Show this help.
EOF
}

fail() {
	echo "[ERROR] $1" >&2
	exit 1
}

info() {
	echo "[INFO] $1"
}

# --- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
	case "$1" in
		-e|--env)
			[[ $# -ge 2 ]] || fail "Missing value for $1"
			ENV="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			fail "Unknown argument: $1"
			;;
	esac
done

# --- Resolve env-specific configuration --------------------------------------
case "$ENV" in
	dev)
		SSO_ACCOUNT_ID="${AWS_SSO_DEV_ACCOUNT_ID:?Set AWS_SSO_DEV_ACCOUNT_ID in ~/.secrets}"
		SSO_ROLE_NAME="${AWS_SSO_DEV_ROLE:?Set AWS_SSO_DEV_ROLE in ~/.secrets}"
		TARGET_PROFILE="default"
		;;
	prod)
		SSO_ACCOUNT_ID="${AWS_SSO_PROD_ACCOUNT_ID:?Set AWS_SSO_PROD_ACCOUNT_ID in ~/.secrets}"
		SSO_ROLE_NAME="${AWS_SSO_PROD_ROLE:?Set AWS_SSO_PROD_ROLE in ~/.secrets}"
		TARGET_PROFILE="prod"
		;;
	*)
		fail "Invalid env '$ENV'. Use 'dev' or 'prod'."
		;;
esac

info "Target environment: $ENV (account $SSO_ACCOUNT_ID, role $SSO_ROLE_NAME)"

# 1) Ensure AWS CLI v2 is available
command -v aws >/dev/null 2>&1 || fail "AWS CLI is not installed."

# 2) Write config file first so `aws sso login` uses the right profile
mkdir -p "$(dirname "$CONFIG_FILE")"
cat >"$CONFIG_FILE" <<EOF
[default]
region = $DEFAULT_REGION

[profile sso]
sso_start_url = $SSO_START_URL
sso_region = $SSO_REGION
sso_account_id = $SSO_ACCOUNT_ID
sso_role_name = $SSO_ROLE_NAME
region = $DEFAULT_REGION
EOF

# 3) Run SSO login (opens browser for authentication if session expired)
info "Starting AWS SSO login (profile: $SSO_PROFILE)..."
if ! aws sso login --profile "$SSO_PROFILE"; then
	fail "AWS SSO login failed."
fi

info "SSO login successful."

# 4) Find the cached SSO access token
#    AWS CLI v2 stores SSO tokens in ~/.aws/sso/cache/*.json
#    We need the most recent file that contains an accessToken.
SSO_CACHE_DIR="$HOME/.aws/sso/cache"
if [[ ! -d "$SSO_CACHE_DIR" ]]; then
	fail "SSO cache directory not found at $SSO_CACHE_DIR"
fi

# Find the newest cache file that has an accessToken field
ACCESS_TOKEN=""
CACHE_FILE=""
for f in $(ls -t "$SSO_CACHE_DIR"/*.json 2>/dev/null); do
	# Skip files that don't have accessToken (e.g., client registration files)
	if python3 -c "import json,sys; d=json.load(open('$f')); sys.exit(0 if 'accessToken' in d else 1)" 2>/dev/null; then
		ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$f'))['accessToken'])")
		CACHE_FILE="$f"
		break
	fi
done

if [[ -z "$ACCESS_TOKEN" ]]; then
	fail "Could not find SSO access token in cache. Try logging in again."
fi

info "Found SSO access token from cache."

# 5) Get role credentials via SSO API
info "Fetching role credentials for account $SSO_ACCOUNT_ID, role $SSO_ROLE_NAME..."

CREDS_JSON=$(aws sso get-role-credentials \
	--account-id "$SSO_ACCOUNT_ID" \
	--role-name "$SSO_ROLE_NAME" \
	--access-token "$ACCESS_TOKEN" \
	--region "$SSO_REGION" \
	--output json 2>&1) || fail "Failed to get role credentials: $CREDS_JSON"

# 6) Extract credentials from JSON
AWS_ACCESS_KEY_ID=$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d['roleCredentials']['accessKeyId'])" <<<"$CREDS_JSON")
AWS_SECRET_ACCESS_KEY=$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d['roleCredentials']['secretAccessKey'])" <<<"$CREDS_JSON")
AWS_SESSION_TOKEN=$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d['roleCredentials']['sessionToken'])" <<<"$CREDS_JSON")

if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_SESSION_TOKEN" ]]; then
	fail "Failed to extract credentials from SSO response."
fi

info "Credentials fetched successfully."

# 7) Ensure .aws directory exists
mkdir -p "$(dirname "$CRED_FILE")"

# 8) Write credentials to file (merging into the target profile, preserving others)
python3 <<PYEOF
import configparser, os

cred_path = os.path.expanduser("$CRED_FILE")
creds = configparser.ConfigParser()
creds.read(cred_path)

section = "$TARGET_PROFILE"
if not creds.has_section(section):
    creds.add_section(section)
creds.set(section, "aws_access_key_id", "$AWS_ACCESS_KEY_ID")
creds.set(section, "aws_secret_access_key", "$AWS_SECRET_ACCESS_KEY")
creds.set(section, "aws_session_token", "$AWS_SESSION_TOKEN")

with open(cred_path, "w") as f:
    creds.write(f)
PYEOF

info "AWS credentials written to $CRED_FILE under [$TARGET_PROFILE]"

# 9) Quick verification (use the profile we just wrote, not whatever [default] currently is)
info "Verifying credentials..."
CALLER_ID=$(aws --profile "$TARGET_PROFILE" sts get-caller-identity --output json 2>&1) || fail "Credential verification failed: $CALLER_ID"

ACCOUNT=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['Account'])" <<<"$CALLER_ID")
ARN=$(python3 -c "import json,sys; print(json.loads(sys.stdin.read())['Arn'])" <<<"$CALLER_ID")

echo ""
echo "AWS credentials updated successfully."
echo "  Env:     $ENV"
echo "  Profile: $TARGET_PROFILE"
echo "  Account: $ACCOUNT"
echo "  ARN:     $ARN"
echo "  Region:  $DEFAULT_REGION"
