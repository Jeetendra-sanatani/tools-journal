# 🧪 Lab Sheet — Cloud/DevOps Day 01: LocalStack Setup + AWS CLI Basics (S3 + IAM)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> 💰 **Why LocalStack:** no credit card, no AWS account, no real cloud cost or risk — everything runs in a Docker container on your own machine. The AWS CLI commands you practice here are the *same* commands you'd run against real AWS; only the `--endpoint-url` differs.
> 📝 **Carried over from the Pentesting phase's last lesson (Day 25):** before this phase grows, decide on ONE folder/numbering convention and stick to it — this kit assumes `Cloud-DevOps/Day-01-...` fresh numbering, matching the Pentesting phase's own folder style.

---

## Step 0: Confirm Docker, install LocalStack and the AWS CLI

```bash
docker --version
sudo systemctl status docker --no-pager

pip install localstack --break-system-packages
sudo apt install awscli -y

which localstack aws
localstack --version
aws --version
```
📸 Screenshot: `01-localstack-install.png`

**Note down:**
- Is Docker already running, or did you need to start it?
- What versions of LocalStack and the AWS CLI do you have?

---

## Part A: start LocalStack and confirm it's healthy

```bash
localstack start -d
# give it ~10-20 seconds to fully start, then:
localstack status services
docker ps   # confirm a localstack container is actually running
```
📸 Screenshot: `02-localstack-start.png`

**Note down:**
- Which services does `localstack status services` list as `available` / `running`? (S3 and IAM are the two you need today.)
- What's the container's name/image, from `docker ps`?

---

## Part B: configure the AWS CLI with dummy credentials

```bash
aws configure
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region name: us-east-1
# Default output format: json

cat ~/.aws/config
cat ~/.aws/credentials

# create a shortcut so you don't retype --endpoint-url every time
echo "alias awslocal='aws --endpoint-url=http://localhost:4566'" >> ~/.bashrc
source ~/.bashrc
```
📸 Screenshot: `03-aws-cli-configure.png`

**Note down:**
- Why does LocalStack accept literally any Access Key/Secret (unlike real AWS)?
- What does the `awslocal` alias actually save you from doing every time?

---

## Part C: S3 basics — create a bucket, upload and download a file

```bash
awslocal s3 mb s3://day01-test-bucket
awslocal s3 ls

echo "hello from localstack" > test-file.txt
awslocal s3 cp test-file.txt s3://day01-test-bucket/
awslocal s3 ls s3://day01-test-bucket/

mkdir -p downloaded
awslocal s3 cp s3://day01-test-bucket/test-file.txt downloaded/
cat downloaded/test-file.txt
```
📸 Screenshot: `04-s3-basics.png`

**Note down:**
- Did the downloaded file's content match exactly what you uploaded?
- What real-world AWS concept does a "bucket" map to — is it more like a folder, a drive, or something else?

---

## Part D: IAM basics — create a user and a policy, locally

```bash
awslocal iam create-user --user-name day01-practice-user
awslocal iam list-users

# attach a simple, read-only S3 policy (AWS-managed policy ARN works in LocalStack too)
awslocal iam attach-user-policy \
  --user-name day01-practice-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

awslocal iam list-attached-user-policies --user-name day01-practice-user
```
📸 Screenshot: `05-iam-basics.png`

**Note down:**
- What did `list-attached-user-policies` show after attaching the policy?
- In real AWS, why would you NEVER want to do your daily work as the root account, based on what you just created here?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
