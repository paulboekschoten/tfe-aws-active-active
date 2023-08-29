#cloud-config
packages:
- git 
- jq 
- vim 
- language-pack-en
- wget
- curl
- zip
- unzip
- ca-certificates
- gnupg
- lsb-release
write_files:
  - path: "/etc/replicated.conf"
    permissions: "0755"
    owner: "root:root"
    content: |
      {
        "DaemonAuthenticationType":     "password",
        "DaemonAuthenticationPassword": "${replicated_password}",
        "TlsBootstrapType":             "server-path",
        "TlsBootstrapHostname":         "${fqdn}",
        "TlsBootstrapCert":             "/tmp/tfe_server.crt",
        "TlsBootstrapKey":              "/tmp/tfe_server.key",
        "BypassPreflightChecks":        true,
        "ImportSettingsFrom":           "/etc/settings.json",
        "LicenseFileLocation":          "/tmp/license.rli"
      }
  - path: "/etc/settings.json"
    permissions: "0755"
    owner: "root:root"
    content: |
      {
        "hostname": {
            "value": "${fqdn}"
        },
        "enc_password": {
            "value": "${enc_password}"
        },
        "aws_instance_profile": {
           "value": "1"
        },
        "s3_bucket": {
            "value": "${s3tfe}"
        },
        "s3_region": {
            "value": "${region}"
        },
        "pg_dbname": {
            "value": "tfe"
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
            "value": "postgres"
        },
        "placement": {
            "value": "placement_s3"
        },
        "production_type": {
            "value": "external"
        }
      }
  - path: "/etc/tfe_initial_user.json"
    permissions: "0755"
    owner: "root:root"
    content: |
      {
        "username": "${admin_username}",
        "email": "${admin_email}",
        "password": "${admin_password}"
      }
  - path: "/tmp/install-tfe.sh"
    permissions: "0755"
    owner: "root:root"
    content: |
      #!/bin/bash -eux
      private_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
      public_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

      curl -sL https://install.terraform.io/ptfe/stable > /tmp/install.sh
      bash /tmp/install.sh release-sequence=${release_sequence} no-proxy private-address=$private_ip public-address=$public_ip
      
      while ! curl -kLsfS --connect-timeout 5 https://${fqdn}/_health_check &>/dev/null ; do
        echo "INFO: TFE has not been yet fully started"
        echo "INFO: sleeping 60 seconds"
        sleep 60
      done

      echo "INFO: TFE is up and running"

      if [ ! -f /etc/iact.txt ]; then
        initial_token=$(replicated admin --tty=0 retrieve-iact | tr -d '\r')
        echo $initial_token > /etc/iact.txt
      fi

      curl -k \
        --header "Content-Type: application/json" \
        --request POST \
        --data @/etc/tfe_initial_user.json \
        https://${fqdn}/admin/initial-admin-user?token=$initial_token | tee /etc/tfe_initial_user_token.json
runcmd: 
  - sudo apt-get -y update
  - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  - unzip /tmp/awscliv2.zip -d /tmp/
  - sudo /tmp/aws/install
  - aws s3 cp s3://${environment_name}-filesbucket/license.rli /tmp/
  - aws s3 cp s3://${environment_name}-filesbucket/tfe_server.crt /tmp/
  - aws s3 cp s3://${environment_name}-filesbucket/tfe_server.key /tmp/
  - bash /tmp/install-tfe.sh