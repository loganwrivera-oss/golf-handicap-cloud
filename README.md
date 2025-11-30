# ⛳ Serverless Golf Handicap Calculator

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)
![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)

## 📖 Project Overview

This is a full-stack, cloud-native application designed to calculate a golfer's handicap index based on the World Handicap System (WHS).

Unlike traditional web apps hosted on a single server, this project is entirely **Serverless**. It uses **AWS Lambda** for compute, **Amazon S3** for static hosting, and **DynamoDB** for data persistence. The entire infrastructure is provisioned using **Terraform** (IaC) and deployed via a **GitHub Actions** CI/CD pipeline.

**[🔗 Live Demo Here](golf-app-texas-logan.s3-website-us-east-1.amazonaws.com)**

---

## 🏗 Architecture

The application follows a 3-Tier Serverless Architecture:

```mermaid
graph TD
    User[User / Browser] -->|HTTPS Request| S3[Amazon S3 (Frontend Hosting)]
    User -->|POST Score Data| API[Amazon API Gateway]
    API -->|Triggers| Lambda[AWS Lambda (Python Logic)]
    Lambda -->|Persists Data| DB[(Amazon DynamoDB)]
