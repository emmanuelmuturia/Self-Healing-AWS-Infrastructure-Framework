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

