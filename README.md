# The Self-Healing AWS Infrastructure

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


## Setup

- To set up and reproduce this project, please follow these steps:


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
