# MERN-stack-infra
Terraform infrastructure for mern-stack project



[Abstract](#abstract) | [Objective](#objective) | [Tech Stack](#Tech-Stack) | [Improvements](#improvements)



## Abstract

DevConnector - A social media site for developers to network on. Users can register, log in, generate a profile, add experience, skills, social links to their profile and view other developers' profiles.

Currently hosted at https://prod.t.useyourbra.in/

## Objectives


I created this app as a way to learn how to host a simple three tier application using Terraform, Docker, AWS EC2, ECR and Route 53, and create deployment pipelines so that the infrastructure could be automatically spun up upon merge of code.
/
/
/
* Host a simple three tier application on AWS infrastructure

* Use terraform so that the infrastructure and app can be spun up and run with a single command.

* Create development and prod environments to simulate the deployment and transition of application code from test environments to live environments.

* Create CI/CD pipelines to automate infrastructure deployments upon changes to code in the infrastructure repository, and to pull and run the application container image upon changes to the application repository.
/
/
/


## How it works

The server is an AWS EC2 instance sitting behind a load balancer which receives traffic from the internet directed to it by AWS Route 53, which handles the domain routing. The SSL certificate for the application was generated using Lets Encrypt.

The docker container, which has already been pushed to AWS ECR for storage, is pulled by the server during the user data script, and any IP whitelisting required for the application to run using external sources is done at this point too. The container is run on the server as part of a linux service.

All of the cloud infrastructure is created using terraform code, and is split using terraform workspaces to separate out the state files for the two environments that are stored in an s3 bucket. 

For CI/CD, Travis CI was first used to implement the pipeline for deploying to both dev and prod environments, before swapping to Gitlab CI. A pipeline has been set up so that upon merging to master branch, the production environment is deployed, and merges to non master branches result in deployment of the dev environment.


**If you'd like to see the code for the application itself please see the [repo for Devconnector](https://github.com/Mnargh/MERN-stack "Devconnector").**


## Tech-Stack

[Terraform](https://www.terraform.io/)  

[Travis CI](https://travis-ci.org/)

[Gitlab CI](https://docs.gitlab.com/ee/ci/)

[Docker](https://www.docker.com/) 

[AWS EC2](https://aws.amazon.com/ec2/) 

The application is hosted on a docker container running on an AWS EC2 instance using Terraform. Take a look at the [repo for the hosting infrastructure](https://github.com/Mnargh/MERN-stack-infra "MERN-stack-infra") to see the code for this.


## Improvements to implement in future given more time

1. Refactor the terraform code to split out into more readable files.

2. Implement pipeline to automatically pull and run the latest docker image without having to completely spin up the infrastructure from scratch

3. Integrate testing stage into the gitlab pipeline 


