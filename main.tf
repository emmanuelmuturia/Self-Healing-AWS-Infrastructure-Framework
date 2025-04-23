terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sre-self-healing-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "public-subnet-b" }
}

resource "aws_security_group" "ssh_monitor" {
  name        = "ssh-monitor-sg"
  description = "Allow SSH and ICMP for health checks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ssh-monitor-sg" }
}

resource "aws_instance" "monitor" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2 in us-east-1 (change if needed)
  instance_type          = "t3.micro"
  key_name		 = "emmanuelmuturia"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.ssh_monitor.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y amazon-cloudwatch-agent
              cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << 'EAGENT'
              {
                "metrics": {
                  "metrics_collected": {
                    "cpu": {
                      "measurement": ["cpu_usage_idle","cpu_usage_iowait"],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              EAGENT
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 \
                -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
              EOF

  tags = {
    Name = "self-healing-monitor"
  }
}

# 6a. SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "self-healing-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "science@emmanuelmuturia.com"
}

# 6c. CloudWatch Alarm on StatusCheckFailed_System
resource "aws_cloudwatch_metric_alarm" "sys_check" {
  alarm_name          = "EC2-SystemCheckFailed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Fires if system status check fails"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    InstanceId = aws_instance.monitor.id
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
