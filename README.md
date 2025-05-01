# The Self-Healing AWS Infrastructure

![The Self-Healing AWS Infrastructure  The Conceptual Framework](https://github.com/user-attachments/assets/e9c752de-f04a-443c-bd50-78ec0c62ee53)

The Self Healing AWS Infrastructure is a Site Reliability Engineering [SRE]-based project. It consists of a Python Script and Terraform configuration which work together with an AWS EC2 Instance to "heal" the EC2 Instance during downtime by re-deploying it with the pre-existing configurations...

## Table of Contents

1. [Background](#Background)
2. [Architecture](#Architecture)
3. [Setup](#Setup)
4. [Screenshots](#Screenshots)
5. [Credits](#Credits)
6. [Trivia](#Trivia)
7. [Future](#Future)

## Background

- The Self-Healing AWS Infrastructure was conceived by my curiosity to integrate an AWS Infrastructure with a custom Terraform configuration and Monitoring & Visualisation Tools: Prometheus, Node Exporter, and Grafana...

## Architecture

- Here is The Architectural Diagram that represents the project's architecture:

![The Self-Healing AWS Infrastructure  The Architecture Diagram](https://github.com/user-attachments/assets/c91f41f1-57b3-47fe-b575-2cface9a1bed)

## Setup

- To set up and reproduce this project, please follow these steps:

### Pre-Requisites

- Python3
- Terraform
- AWS CLI

### Step 1 [AWS, Python and Terraform]

This section outlines the steps to set up the monitoring project from scratch using Terraform for Infrastructure Provisioning and a Python script for the "healing functionality". This assumes a Linux-based system [like Ubuntu on EC2]:

- It is highly recommended you install AWS CLI to easily interact with your AWS Resources via the command-line. To do that, follow [this guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)

- Install Terraform, Python, and Pip as shown:

```bash
# Install Terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

# Install Python 3 and pip
sudo yum install python3 -y
```

- Next, create a `main.tf` file as this is where you will be configuring your AWS Infrastructure...
- Here is an example of an AWS Infrastructure:

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "monitoring_ec2" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = var.key_name
  security_groups = [aws_security_group.monitoring_sg.name]

  tags = {
    Name = "MonitoringInstance"
  }
}

resource "aws_security_group" "monitoring_sg" {
  name        = "monitoring_sg"
  description = "Allow ports for Prometheus, Grafana, Node Exporter"

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Prometheus
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Node Exporter
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

- For SSH, you can store your Key/Pair using a separate `variables.tf` file as shown:

```hcl
variable "key_name" {
  type        = string
  description = "The name of the existing AWS key pair"
}
```

- Once done, run the following commands to deploy your AWS Infrastructure:

```bash
terraform init
terraform apply
```

- If you are using SSH to log into your EC2 Instance, provide the key pair name when prompted...

### Step 2 [Prometheus, Node Exporter, and Grafana]

- This step assumes your EC2 instance is already running and your key pair is saved locally as `<Name of Key.pem>`...
- SSH into your EC2 Instance using the following commands:

```bash
chmod 400 your-key.pem
ssh -i your-key.pem ec2-user@<public-ip>
```

- Once you have successfully logged in, install Node Exporter as shown:

```bash
# Download Node Exporter (change version as needed)
NODE_EXPORTER_VERSION="1.7.0"
curl -LO https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

# Extract and move
tar -xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

# Create a systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=ec2-user
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF

# Start and enable service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

- Next, install Prometheus as shown:

```bash
# Download Prometheus
PROM_VERSION="2.52.0"
curl -LO https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz

# Extract and move
tar -xvzf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64
sudo mv prometheus promtool /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp -r consoles console_libraries /etc/prometheus/
```

- Create the configuration file for Prometheus:

```bash
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
```

- Create the Prometheus service:

```bash
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
After=network.target

[Service]
User=ec2-user
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

- Finally, install Grafana as shown:

```bash
# Add repo and install
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
EOF

sudo yum install grafana -y

# Enable and start
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

- Test the installation of the 3 tools using these commands:

```bash
curl http://<public-ip>:9100/metrics      # Node Exporter
curl http://<public-ip>:9090/targets      # Prometheus Targets
curl http://<public-ip>:3000/login        # Grafana Login Page
```

- Alternatively, you can use the URLs in your browser. Do not forget to include the ports in your AWS Security Groups...

- Log into Grafana using the following URL: http://<your-ec2-public-ip>:3000...

- Use "admin" as both your username and password. You will be prompted to reset your password...

- From the left sidebar, click "Settings" > "Data Sources"...

- Click "Add data source"...

- Choose "Prometheus"...

- In the URL field, enter: http://localhost:9090

- Click "Save & Test"...

- You should see a green "Success" message...

- From the left sidebar, click the "+" icon > Import...

- In the "Import via grafana.com" field, paste: 1860

- This is a popular Node Exporter dashboard [Node Exporter Full]...

- Click "Load"...

- Under "Prometheus", make sure your data source [Prometheus] is selected...

- Click "Import"...

- Voilà! You now have a beautiful dashboard showing CPU, Memory, Disk, and Network stats among others...

### Step 3 [Python]

- Now that you have your AWS Infrastructure set up, it is time to write the Python script...

- Here is an example of the script:

```python3
#!/usr/bin/env python3

import boto3
import subprocess
import time

# Clients
ec2 = boto3.client('ec2')
sns = boto3.client('sns')

TOPIC_ARN = "arn:aws:sns:us-east-1:447145157493:self-healing-alerts"

def remediate(instance_id):
    print(f"[!] Remediating {instance_id}")
    # 1. Terminate the bad instance
    ec2.terminate_instances(InstanceIds=[instance_id])
    waiter = ec2.get_waiter('instance_terminated')
    waiter.wait(InstanceIds=[instance_id])

    # 2. Re-run Terraform to recreate it
    subprocess.run(["terraform", "apply", "-auto-approve"], check=True)

    # 3. Send an SNS alert
    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="Self-Healing Alert",
        Message=f"Instance {instance_id} was impaired and has been remediated."
    )

def main():
    while True:
        statuses = ec2.describe_instance_status(
            IncludeAllInstances=True
        )['InstanceStatuses']
        for s in statuses:
            iid = s['InstanceId']
            sys_stat = s['SystemStatus']['Status']
            inst_stat = s['InstanceStatus']['Status']

            if sys_stat != 'ok' or inst_stat != 'ok':
                remediate(iid)

        # Wait 5 minutes between checks
        time.sleep(300)

if __name__ == "__main__":
    main()
```

- Run the script using the following command:

```bash
python3 <file_name>.py
```

- The cursor should blink which indicates that it is running...

- For the sake of Automation, you can have your script run continuously in the background:

```bash
crontab -e
# Add this line:
@reboot cd /your/project/directory && nohup python3 <filename>.py > <name_of_log_file_you_can_create>.log 2>&1 &
```

- If you prefer fixed intervals:

```bash
# Every 7 minutes:
*/7 * * * * cd /your/project/directory && python3 <filename>.py >> <name_of_log_file_you_can_create>.log 2>&1
```

- Simulate a failure in your EC2 Instance using the following command after you SSH into your EC2 Instance if you had logged out:

```bash
sudo systemctl stop amazon-ssm-agent
```

- Manually run the Python script...

- It should detect the broken instance...

- It will: Terminate it, Run `terraform apply` to recreate it, and Send a notification via AWS SNS...

- That is all...

## Credits

- The Self-Healing AWS Infrastructure was made possible thanks to the following Tools & Technologies:

### 1. Python

- To execute [and automate if you wish to] the project's "healing" functionality, a [Python](https://www.python.org/) script was utilised...
- The script uses [Boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) which is an AWS SDK that is used to create, configure, and manage AWS services via Python...

### 2. Terraform

- While this project could also be successfully deployed using the AWS Console, [Terraform](https://developer.hashicorp.com/terraform) was the default option as it allowed for easier configuration of the instracture along with automated deployment capabilities...

### 3. Monitoring & Visualisation Tools

- [Prometheus](https://prometheus.io/) served as the project's Data Source, in that it collected the EC2 Instance's stats that would then be used for visualisation...
- [Node Exporter](https://prometheus.io/docs/guides/node-exporter/) was also used alongside Prometheus as the EC2 Instance was Linux-based and this meant that it would be easier to expose a wide variety of hardware and kernel-related metrics through it for Prometheus to aggregate...
- [Grafana](https://grafana.com/) used the [Node Exporter Full](https://grafana.com/grafana/dashboards/1860-node-exporter-full/) dashboard to visualise the data being collected by Prometheus and Node Exporter...

## Trivia

- This project mimics an SRE environment and can be used to simulate the tasks that would be typically encountered in a similar role...

## Future

- Further developments will be implemented as the project is still a work in progress...
- Feel free to customise it to your preferences and get your hands dirty...
