# Web & DB servers on AWS in two separate environments

## About The Project

The project provides two environments hosted in AWS, managed by terraform with terragrunt. Enviornments are split into QA and Prod. Main differences between those enviornments are instance types and the number of web server instances.

|  |QA|Prod|
|------|-----|-----|
|Web server Instance Type|t3.small|t3.xlarge|
|Web server replicas | 1 | 3|
|DB server Instance Type|t3.medium|t3.2xlarge|
|DB server replicas |1|1|

All these parameters can be modified within the enviornment *terragrunt.hcl* configuration files at environments/\*/app directories. Where \* stands for QA/Prod.

```
.
.
├── Modules
│   ├── app-custom-module
│   │   ├── main.tf
│   │   └── variables.tf
│   └── app-with-external-modules
│       ├── main.tf
│       └── variables.tf
├── environments
│   ├── Prod
│   │   └── app
│   │       └── terragrunt.hcl
│   ├── QA
│   │   └── app
│   │       └── terragrunt.hcl
│   └── terragrunt.hcl
└── README.md
```

Environments are separated with AWS Profiles. Different accounts are set for both environments, what is configured with the AWS CLI profiles and used accordingly in the Terragrunt config files. However, the enviornments can be split with regions. You can use the same AWS account in AWS and split environment with target region in provider configuration.

### Built With

- Terraform
- Terragrunt
- Terraform Modules

## Architecture

Architecture is different per module.

**app-with-external-modules:** This module provides a highly available (2 AZs and auto scalling group) deployment with the use of external modules.

**app-custom-module:** This module deployes the infrastructure in a single AZ without the auto scalling group.

### app-with-external-modules

This scenario deploys web-servers and db server with auto scalling groups and uses external modules from HashiCorp Public Registry:

- terraform-aws-modules/vpc/aws
- terraform-aws-modules/autoscaling/aws

High-level architecture for this scenario:

![HLD-HA-ASG](./images/hld-ha-asg.svg)

### app-custom-module

This scenario deploys web-servers and db server within one AZ and without any ASG.

High-level architecture for this scenario:

![HLD-CUSTOM](./images/hld-custom.svg)

## Getting Started

How to set up the project locally.

### Prerequisites

- Terraform >= 1.8.2
- Terragrunt >= 0.57.13
- AWS CLI >= 2.15.34
- AWS CLI authentication:
  - profiles saved in ~/.aws/credentials
  - exported ACCESS KEYS in the console
  - ACCESS KEYS in Vault
  - or other

### Installation

1. Clone the repo
    ```sh
    git clone https://github.com/osialek/terraform-AWS.git
    ```
2. Update terragrunt.hcl file in environments directory (root terragrunt file)

    - specify backend config details

        ```json
        remote_state {
        backend = "s3"
        generate = {
            path = "backend.tf"
            if_exists = "overwrite_terragrunt"
        }

        config = {
            bucket         = "[YOUR-BUCKET-NAME]"
            key            = "${path_relative_to_include()}/terraform.tfstate"
            region         = "[REGION YOU WANT TO USE]"
        }
        }
        ```
    - you can change the backend type and/or add DynamoDB table for state locking.
3. Update terragrunt.hcl files in each of the envioronments directories

    - specify module you want to use
        - "../../../Modules/app-with-external-modules/"
        - "../../../Modules/app-custom-module/"
    Both of them work with the same inputs
    - edit provider configuration (credentials and region)
4. Go to environment directory and its app folder
5. Run `` Terragrunt apply```

## Notes

- Deployed web and db servers are empty imaged running latest Ubuntu 22.04 image
- No dependencies or services are being installed within this configuration
- Further work need to be done
- This is just a base for hosting a simple web application
