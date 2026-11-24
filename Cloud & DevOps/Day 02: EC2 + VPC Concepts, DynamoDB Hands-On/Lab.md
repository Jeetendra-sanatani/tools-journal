# 🧪 Lab Sheet — Cloud/DevOps Day 02: EC2 + VPC Concepts, DynamoDB Hands-On

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> ⚠️ **Important constraint, learned the hard way on Day 01:** LocalStack's free **Community edition does NOT emulate EC2** (it's a Pro-only feature). Don't spend time troubleshooting `awslocal ec2 run-instances` failing — it's not a config mistake, it's a licensing limit. Today covers EC2 and VPC as **concepts** (Part A/B, no hands-on needed) and does **real hands-on with DynamoDB** instead (Part C), which IS fully supported in the free Community edition.

---

## Step 0: Confirm LocalStack is still up, add DynamoDB to the running services

```bash
docker ps | grep localstack
curl http://localhost:4566/_localstack/health
```
If `dynamodb` isn't listed as available in that health check, restart the container with it enabled:
```bash
docker rm -f localstack
docker run -d --name localstack \
  -p 4566:4566 -p 4510-4559:4510-4559 \
  -e SERVICES=s3,iam,dynamodb \
  localstack/localstack:3.4
sleep 10
curl http://localhost:4566/_localstack/health
```
📸 Screenshot: `01-dynamodb-setup.png`

**Note down:**
- Was DynamoDB already available, or did you need to restart the container?
- From yesterday's health check, which other services does LocalStack Community list as available?

---

## Part A: EC2 concepts (read, don't try to run commands)

Read AWS's own EC2 overview, then write a short summary in your own words covering:
- What an EC2 **instance** actually is (a virtual server)
- What an **AMI** (Amazon Machine Image) is, and how it relates to an instance
- What an **instance type** (e.g. `t2.micro`, `t3.small`) controls
- Why EC2 is the service most likely to actually cost money if left running on real AWS

```bash
mkdir -p ~/Desktop/kali/day02-ec2-vpc && cd ~/Desktop/kali/day02-ec2-vpc
nano ec2-concepts.txt
```
📸 Screenshot: `02-ec2-concepts.png` (your written notes file)

**Note down:**
- In your own words: what's the difference between an AMI and an instance?
- If you forgot to stop/terminate an EC2 instance on real AWS, what would actually happen to your bill?

---

## Part B: VPC concepts (read, don't try to run commands)

Write a short summary covering:
- What a **VPC** is (an isolated virtual network inside AWS)
- What a **subnet** is, and the difference between a public and a private subnet
- What a **Security Group** actually controls (stateful, instance-level firewall rules)
- What a **Route Table** does

```bash
nano vpc-concepts.txt
```
📸 Screenshot: `03-vpc-concepts.png` (your written notes file)

**Note down:**
- Why would a database server typically sit in a private subnet, while a web server sits in a public one?
- What's the difference between a Security Group and a traditional firewall rule, in terms of direction (stateful vs stateless)?

---

## Part C: DynamoDB — real hands-on

```bash
# C1 - create a table
awslocal dynamodb create-table \
  --table-name Day02Practice \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

awslocal dynamodb list-tables
```
```bash
# C2 - put an item into it
awslocal dynamodb put-item \
  --table-name Day02Practice \
  --item '{"id": {"S": "item1"}, "message": {"S": "hello from dynamodb"}}'

# C3 - read it back
awslocal dynamodb get-item \
  --table-name Day02Practice \
  --key '{"id": {"S": "item1"}}'
```
```bash
# C4 - scan the whole table, then clean up
awslocal dynamodb scan --table-name Day02Practice
awslocal dynamodb delete-table --table-name Day02Practice
awslocal dynamodb list-tables
```
📸 Screenshot: `04-dynamodb-hands-on.png`

**Note down:**
- Did the item you read back (`get-item`) match exactly what you put in?
- What's the AWS equivalent of a DynamoDB "table" and "item" in a traditional SQL database (table/row, or something else)?
- Did the table actually disappear from `list-tables` after deleting it?

---

## Part D: tie it together

📸 Screenshot: `05-day02-summary.png` (your own short write-up comparing today's theory vs hands-on)

**Note down:**
- Why did EC2/VPC stay theory-only today while DynamoDB got real hands-on? What does that tell you about planning which AWS services to practice on a free/local setup?
- If you had a real AWS free-tier account tomorrow, what would be the very first EC2 safety step you'd take before launching anything (hint: Day 01's billing-safety conversation)?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text / your notes)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
