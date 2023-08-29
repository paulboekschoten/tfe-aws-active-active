# Manual installation of TFE (Airgapped), external services, valid certificate on AWS

Here it is described how to manually install Airgapped Terraform Enterpise (TFE) with external services (PostgreSql and S3) and a valid certificate on AWS.  

Official installation documentation can be found [here](https://www.terraform.io/enterprise/install/interactive/installer).  

# Prerequisites
- AWS account
- Airgapped installation file
- TFE license


# How to

## VPC
Go to `VPC` and click `Create VPC`.  
![](media/2022-11-22-11-26-14.png)  
Give it a name and an IPv4 CIDR range.  

## Subnets
Go to `Subnets`.  

### Public
For TFE  
Click on `Create subnet`.  
![](media/2022-11-22-11-30-07.png)  
Select your VPC.  

![](media/2022-11-22-11-32-17.png)    
Supply a name and an IPv4 CIDR block within the range of the VPC CIDR.  

Click `Create subnet`.  

### Private
For PostgreSQL  
Click on `Create subnet`.  
![](media/2022-11-22-11-30-07.png)  
Select your VPC.  

![](media/2022-11-22-11-33-41.png)      
Supply a name and an IPv4 CIDR block within the range of the VPC CIDR and not overlapping with other subnets.    

Click `Create subnet`. 

## Internet Gateway
Go to `Internet gateways`.  
Click `Create Internet gateway`.  
![](media/2022-11-22-11-35-52.png)  
Provide a name and click `Create internet gateway`.  

Click on `Actions` and then on `Attach to VPC`.  
![](media/2022-11-22-11-37-21.png)  
Select the VPC and click on `Attach internet gateway`.  

## Route table
Go to `Route tables` and select the new route table.  
![](media/2022-11-22-11-41-08.png)  

Click on `Edit routes`.  
![](media/2022-11-22-11-41-48.png)  
Add a route with destination `0.0.0.0/0` and target the created internet gateway.  

Click `Save changes`.  

## Key pair
To be able to login with ssh to your ec2 instance, you'll need a key pair.  
Go to `Key pairs` and click `Create key pair`.  
![](media/2022-11-22-11-45-06.png)    

Give it a useful name and click `Create key pair`.  

A pem file will be downloaded in the browser.  
Store this pem file in a secure location and change the permissions to only your user.  
On linux/mac:
```
chmod 0600 tfe_valid_cert_paul.pem
```

## Security group
Allow certain ports to connect to your TFE instance.  
Go to Security Groups and click Create security groups.  
![](media/2022-11-22-11-51-03.png)  
Supply a name, description and select the VPC.  

![](media/2022-11-22-11-54-58.png)  
Port 22, 443 and 8080 are accessible from anywhere.  
Port 5432 is accessible from anywhere within the VPC.  

![](media/2022-11-22-11-55-31.png)    
To simulate the no internet connectivity, use `My IP` instead of `0.0.0.0/0` under `Source`.  

Click `Create security group`.  


## EC2 instance
Create an EC2 instance to install TFE on.  
Go to EC2 instances and click `Launch instances`.  
![](media/2022-11-22-11-58-49.png)   
Provide a name.  

![](media/2022-11-22-11-59-23.png)    
Select `Ubuntu`.  

![](media/2022-11-22-12-00-35.png)    
Pick `m5.xlarge`  

![](media/2022-11-22-12-02-45.png)  
Select the key pair created in the previous step.  

![](media/2022-11-22-12-05-53.png)    
Under `Network Settings`, click on `Edit`.  
Select the VPC.  
Select the public subnet.  
Select the existing security group created in the previous step. 

![](media/2022-11-22-12-06-30.png)    
Set the size of the disk to 100GB.  

Click `Launch instance'.  


## EIP
Go to `Elastic IPs` and click `Allocate Elastic IP address`.  
![](media/2022-11-21-10-27-35.png)  
Click `Allocate`  

![](media/2022-11-21-10-31-33.png)  
Select the newly created IP, click on `Actions` and then on `Associate Elastic IP address`.  

![](media/2022-11-22-12-08-34.png)    
Select your instance.  

Click on `Associate`. 

# SSH login
You can login with the pem file and the public elastic ip.  
```
ssh -i tfe_airgap_manual_paul.pem ubuntu@15.236.118.150
```

## Create DNS record
Go to Route 53, Hosted Zones, tf-support.hashicorpdemo.com  
Click `Create record`.  
![](media/2022-11-22-13-36-19.png)    
- Enter a `Record name`, this will be the subdomain of the hosted zone.  
- Under `Value` enter the elastic ip address.  

## Certificate from Let's Encrypt
On a UNIX machine with certbot installed enter the following command  
```
sudo certbot -d tfe-airgap-manual-paul.tf-support.hashicorpdemo.com --manual --preferred-challenges dns certonly --register-unsafely-without-email
```

Create a DNS record as described  
![](media/2022-11-22-13-39-05.png)    
Click `Create records`.  

Click on `View status` and make sure it is `insync`.  

Hit `Enter` on the commandline.  

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/tfe-airgap-manual-paul.tf-support.hashicorpdemo.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/tfe-airgap-manual-paul.tf-support.hashicorpdemo.com/privkey.pem
This certificate expires on 2023-02-20.
...
```
Delete the created DNS TXT record.  

From the stored Let's Encrypt files, retrieve the `fullchain.pem` and `privkey.pem`.   
```
sudo cp /etc/letsencrypt/live/tfe-airgap-manual-paul.tf-support.hashicorpdemo.com/fullchain.pem ./
sudo cp /etc/letsencrypt/live/tfe-airgap-manual-paul.tf-support.hashicorpdemo.com/privkey.pem ./
sudo chown paulboekschoten:staff fullchain.pem privkey.pem
```

## S3 bucket
https://developer.hashicorp.com/terraform/enterprise/requirements/data-storage/operational-mode-requirements

Go to `Buckets`.  
Click `Create bucket`.  

![](media/2022-11-22-13-45-07.png)    
Enter a name and leave all defaults.  
![](media/2022-11-22-13-45-33.png)  
![](media/2022-11-22-13-45-52.png)  
![](media/2022-11-22-13-46-07.png)  

Click `Create bucket`.  

Allow instance to connect to S3 via IAM role.  
https://aws.amazon.com/premiumsupport/knowledge-center/ec2-instance-access-s3-bucket/

Go to `Identity and Access Management (IAM)` and then `Roles`.  
Click `Create role`.  

![](media/2022-11-23-13-35-13.png)  
Select `AWS service` as trusted entity type.  
Under Use cases, select `EC2` (common use cases).  
Click `Next: Permissions`.  

Click `Create policy`.  

![](media/2022-11-23-13-54-08.png)  
Under Service select `S3`.  

![](media/2022-11-23-13-54-50.png)  
Under Actions, select `All S3 actions (s3:*)`.  

![](media/2022-11-23-13-55-38.png)  
Under resources, click `Add ARN` in the `bucket` section.  

![](media/2022-11-23-13-57-39.png)    
Enter the bucket name and click `Add`.  

Click `Next: Tags`.  
Click `Next: Review`.  

![](media/2022-11-23-13-59-24.png)  
Provide a name and a description.  
Click `Create policy`.  

Close this tab and go back to the tab for Roles.  

Click the refresh button.  

![](media/2022-11-23-14-09-38.png)  
Select the newly created policy and click `Next`.  

![](media/2022-11-23-14-10-47.png)  
Provide a name for the role.  

![](media/2022-11-23-14-11-51.png)  
Click `Create role`.  

Go to the EC2 instances.  

![](media/2022-11-23-14-12-55.png)  
Select the tfe instance.  
Click on `Actions`.  
Click on `Security`.  
Click on `Modify IAM role`.  

![](media/2022-11-23-14-14-13.png)  
Select your IAM role, click `Update IAM role`.  


## PostgreSQL
https://developer.hashicorp.com/terraform/enterprise/requirements/data-storage/postgres-requirements

Go to `RDS`.  
Click `Create database`.  

![](media/2022-11-22-13-48-13.png)  
Select `Standard create`.  

![](media/2022-11-22-13-48-39.png)  
Select `PostgreSQL`.  
Select the version wanted. Here 14.5-R1.  

![](media/2022-11-22-13-50-57.png)  
Select the `Dev/test` template.  

![](media/2022-11-22-13-51-23.png)  
Select `Single DB instance`.  

![](media/2022-11-22-13-52-34.png)  
Provide a name for the database.  
Enter a password for the `Master` account.  

![](media/2022-11-22-13-53-57.png)  
Select the `db.m5.large` instance.  

![](media/2022-11-22-13-55-08.png)  
Select `General Purpose SSD (gp2)`.  
Set the `Allocated storage` to 50 GiB.  

![](media/2022-11-22-13-56-49.png)  
Select `Connect to an EC2 compute resource`.  
Select the EC2 instance.  
![](media/2022-11-22-13-59-41.png)  
Select the security group.  

![](media/2022-11-22-14-00-45.png)  

![](media/2022-11-22-14-01-37.png)  

![](media/2022-11-22-14-02-18.png)  
Expand `Additional configuration`.  
Provide an initial database name.  If none provided, no database will be created.  

![](media/2022-11-22-14-05-09.png)  

Click `Create database`.  

## Docker
Requirements: https://developer.hashicorp.com/terraform/enterprise/requirements/docker  

Install manual: https://docs.docker.com/engine/install/ubuntu/#install-from-a-package  

Go to: https://download.docker.com/linux/ubuntu/dists/jammy/pool/stable/amd64/  
Download and place in the folder `files`:
  - containerd.io_1.6.9-1_amd64.deb
  - docker-ce_20.10.21~3-0~ubuntu-jammy_amd64.deb 
  - docker-ce-cli_20.10.21~3-0~ubuntu-jammy_amd64.deb 
  - docker-compose-plugin_2.6.0~ubuntu-jammy_amd64.deb 

Copy these files to your TFE host.  
```
scp -i tfe_airgap_manual_paul.pem files/*.deb ubuntu@15.236.118.150:/tmp
```

Login with ssh to the EC2 instance.  
```
ssh -i tfe_airgap_manual_paul.pem ubuntu@15.236.118.150
```

Install Docker  
```
cd /tmp
sudo dpkg -i ./containerd.io_1.6.9-1_amd64.deb \
  ./docker-ce_20.10.21_3-0_ubuntu-jammy_amd64.deb \
  ./docker-ce-cli_20.10.21_3-0_ubuntu-jammy_amd64.deb \
  ./docker-compose-plugin_2.6.0_ubuntu-jammy_amd64.deb
```


## TFE
Download the `Installer bootstrapper`.  
https://install.terraform.io/airgap/latest.tar.gz  

Copy installer to the TFE instance.  
```
scp -i tfe_airgap_manual_paul.pem files/replicated.tar.gz ubuntu@15.236.118.150:/tmp
```

Copy your TFE airgap file to the TFE instance.  
```
scp -i tfe_airgap_manual_paul.pem files/tfe_660.airgap ubuntu@15.236.118.150:/tmp
```

Login with SSH to the TFE instance.  
Login with ssh to the EC2 instance.  
```
ssh -i tfe_airgap_manual_paul.pem ubuntu@15.236.118.150
```

Extract the installer
```
cd /tmp
tar xzf replicated.tar.gz
```

Run the installer
```
sudo ./install.sh airgap
```

```
Determining local address
The installer was unable to automatically detect the private IP address of this machine.
Please choose one of the following network interfaces:
[0] ens5 	10.100.0.198
[1] docker0	172.17.0.1
Enter desired number (0-1): 0
```
Select 0.  

```
Operator installation successful

To continue the installation, visit the following URL in your browser:

  http://<this_server_address>:8800
```

In a browser, go to http://tfe-airgap-manual-paul.tf-support.hashicorpdemo.com:8800

![](media/2022-11-23-11-13-39.png)  
Click `Continue to Setup`.  

![](media/2022-11-23-11-15-41.png)  
Enter the hostname.  
Select the private key and certificate in the corresponding boxes.  
Click `Upload & Continue`.  

![](media/2022-11-23-11-17-32.png)  
Upload your TFE license.  

![](media/2022-11-23-11-19-52.png)  
Select `Airgapped` and click `Continue`.  

![](media/2022-11-23-11-21-16.png)  
Provide the path to the airgap bundle on the server.  
Click `Continue`.  

Page kept loading, had to refresh to continue.  

![](media/2022-11-23-11-57-38.png)  
Provide a password and click `Continue`.  

![](media/2022-11-23-11-59-05.png)  
Click `Continue`.  

On the `Settings` page
![](media/2022-11-23-12-00-49.png)  
Provide an encryption password.  

![](media/2022-11-23-12-01-18.png)  
Select `External Services` for production type.  

![](media/2022-11-23-12-04-00.png)  
Provide the required fields.  
Hostname can be found in the AWS console.  

![](media/2022-11-23-15-15-29.png)  
Select `Use instance profile for access`.  
Provide the bucket name.  
Provide the region.  
(Edit the outbound rule for the security group from `My IP` to `Anywhere-IPv4` and save.)

Click `Save`.  

Click `Restart`.  

![](media/2022-11-23-15-20-08.png)  
Click on `Open`.  

![](media/2022-11-23-15-19-49.png)  
Provide an admin username, email and password.  
Click `Create an account`.  
