#!/bin/bash

# setup logging and begin
set -e -u -o pipefail
NOW=$(date +"%FT%T")
echo "[$NOW]  Beginning TFE user_data script."

# update packages and install prereqs
sudo yum update -y
sudo yum install -y jq

# set up file paths and directories
tfe_installer_dir="/opt/tfe/installer"
tfe_config_dir="/opt/tfe/config"
tfe_settings_path="$tfe_config_dir/tfe-settings.json"
tfe_license_path="$tfe_config_dir/tfe-license.rli"
repl_conf_path="/etc/replicated.conf"

sudo mkdir -p $tfe_installer_dir
sudo mkdir -p $tfe_config_dir

# ingest and write TFE Replicated license file
cat > /tmp/tfe-license.rli.base64 <<EOF
${tfe_license_file}
EOF
base64 --decode /tmp/tfe-license.rli.base64 > $tfe_license_path

# retrieve TFE install bits
sudo curl -o $tfe_installer_dir/install.sh https://install.terraform.io/ptfe/stable

# configure Replicated
cat > $repl_conf_path <<EOF
{
  "DaemonAuthenticationType": "password",
  "DaemonAuthenticationPassword": "${console_password}",
  "TlsBootstrapType": "self-signed",
  "TlsBootstrapHostname": "${tfe_hostname}",
  "TlsBootstrapCert": "",
  "TlsBootstrapKey": "",
  "BypassPreflightChecks": true,
  "ImportSettingsFrom": "$tfe_settings_path",
  "LicenseFileLocation": "$tfe_license_path",
  "LicenseBootstrapAirgapPackagePath": ""
}
EOF

# configure TFE app settings
cat > $tfe_settings_path <<EOF
{
    "aws_access_key_id": {},
    "aws_instance_profile": {
        "value": "1"
    },
    "aws_secret_access_key": {},
    "ca_certs": {},
    "capacity_concurrency": {
        "value": "20"
    },
    "capacity_memory": {
        "value": "512"
    },
    "enable_metrics_collection": {
        "value": "1"
    },
    "enc_password": {
        "value": "${enc_password}"
    },
    "extern_vault_addr": {},
    "extern_vault_enable": {
        "value": "0"
    },
    "extern_vault_path": {},
    "extern_vault_propagate": {},
    "extern_vault_role_id": {},
    "extern_vault_secret_id": {},
    "extern_vault_token_renew": {},
    "extra_no_proxy": {},
    "hostname": {
        "value": "${tfe_hostname}"
    },
    "iact_subnet_list": {},
    "iact_subnet_time_limit": {
        "value": "60"
    },
    "installation_type": {
        "value": "production"
    },
    "pg_dbname": {
        "value": "${pg_dbname}"
    },
    "pg_extra_params": {
        "value": "sslmode=require"
    },
    "pg_netloc": {
        "value": "${pg_netloc}"
    },
    "pg_password": {
        "value": "${pg_password}"
    },
    "pg_user": {
        "value": "${pg_user}"
    },
    "placement": {
        "value": "placement_s3"
    },
    "production_type": {
        "value": "external"
    },
    "s3_bucket": {
        "value": "${s3_app_bucket_name}"
    },
    "s3_endpoint": {},
    "s3_region": {
        "value": "${s3_app_bucket_region}"
    },
    "s3_sse": {
        "value": "aws:kms"
    },
    "s3_sse_kms_key_id": {
        "value": "${kms_key_arn}"
    },
    "tbw_image": {
        "value": "default_image"
    },
    "tls_vers": {
        "value": "tls_1_2_tls_1_3"
    }
}
EOF

# collect AWS EC2 instance metadata
EC2_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# run the TFE installer script passing in EC2 metadata arguements
cd $tfe_installer_dir
bash ./install.sh \
    no-proxy \
    release-sequence=${tfe_release_sequence} \
    private-address=$EC2_PRIVATE_IP \
    public-address=$EC2_PRIVATE_IP

# make Docker automatically start
sudo systemctl enable docker.service

# sleep at beginning of TFE install
NOW=$(date +"%FT%T")
echo "[$NOW]  Sleeping for 2 minutes while TFE initializes..."
sleep 120

# poll install status against TFE health check endpoint
while ! curl -ksfS --connect-timeout 5 https://$EC2_PRIVATE_IP/_health_check; do
    sleep 5
done

# build payload for initial TFE admin user
cat > $tfe_config_dir/initial_admin_user.json <<EOF
{
	"username": "${tfe_initial_admin_username}",
	"email": "${tfe_initial_admin_email}",
	"password": "${tfe_initial_admin_pw}"
}
EOF

# retrieve Initial Admin Creation Token
iact=$(replicated admin --tty=0 retrieve-iact)

# HTTP POST to retrieve Initial Admin User Token
iaut=$(curl --header "Content-Type: application/json" --request POST --data @/opt/tfe/config/initial_admin_user.json "https://${tfe_hostname}/admin/initial-admin-user?token=$iact" | jq -r '.token')

# build payload for initial TFE Organization creation
cat > $tfe_config_dir/initial_org.json <<EOF
{
  "data": {
    "type": "organizations",
    "attributes": {
      "name": "${tfe_initial_org_name}",
      "email": "${tfe_initial_org_email}"
    }
  }
}
EOF

# HTTP POST to create initial TFE Organization
curl  --header "Authorization: Bearer $iaut" --header "Content-Type: application/vnd.api+json" --request POST --data @/opt/tfe/config/initial_org.json "https://${tfe_hostname}/api/v2/organizations"

# end script
NOW=$(date +"%FT%T")
echo "[$NOW]  Finished TFE user_data script."
