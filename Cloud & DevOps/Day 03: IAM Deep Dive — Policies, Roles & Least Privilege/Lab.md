# 🧪 Lab Sheet — Cloud/DevOps Day 03: IAM Deep Dive — Policies, Roles & Least Privilege

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> 🔐 **Why this matters for where you're headed:** your own next-steps goal is "Common AWS Security Misconfigurations." Almost every real-world AWS security finding traces back to IAM — a policy that's too broad, a role trusted by the wrong principal, or a user with permissions nobody remembers granting. Today builds the IAM vocabulary needed to actually spot those problems later.

---

## Step 0: Confirm LocalStack is healthy, set up a workspace

```bash
docker ps | grep localstack
curl http://localhost:4566/_localstack/health
mkdir -p ~/Desktop/kali/day03-iam && cd ~/Desktop/kali/day03-iam
```
📸 Screenshot: `01-iam-setup.png`

**Note down:**
- Is `iam` still listed as `available`?

---

## Part A: write your own custom policy (JSON), don't use an AWS-managed one

```bash
cat > least-privilege-policy.json << 'POLICYEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::day03-bucket",
        "arn:aws:s3:::day03-bucket/*"
      ]
    }
  ]
}
POLICYEOF
cat least-privilege-policy.json
```
📸 Screenshot: `02-custom-policy-json.png`

**Note down:**
- What does `Effect: Allow` combined with only `s3:GetObject`/`s3:ListBucket` actually permit — and what does it NOT permit (e.g. can this policy delete or upload objects)?
- Why list the bucket ARN with AND without the trailing `/*`? (Hint: one covers the bucket itself, the other covers objects inside it.)

---

## Part B: create the policy in IAM, attach it to a user

```bash
awslocal iam create-user --user-name day03-least-priv-user

awslocal iam create-policy \
  --policy-name Day03LeastPrivilegePolicy \
  --policy-document file://least-privilege-policy.json

# copy the PolicyArn from the output above, then:
awslocal iam attach-user-policy \
  --user-name day03-least-priv-user \
  --policy-arn <paste-the-policy-arn-here>

awslocal iam list-attached-user-policies --user-name day03-least-priv-user
```
📸 Screenshot: `03-attach-custom-policy.png`

**Note down:**
- What's the PolicyArn LocalStack assigned your custom policy?
- How is creating your OWN policy (Part A/B) different from Day 01's `attach-user-policy` with an AWS-managed ARN?

---

## Part C: build an intentionally overly-permissive policy, and compare

```bash
cat > overly-permissive-policy.json << 'POLICYEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
POLICYEOF

awslocal iam create-user --user-name day03-overly-permissive-user

awslocal iam create-policy \
  --policy-name Day03OverlyPermissivePolicy \
  --policy-document file://overly-permissive-policy.json

awslocal iam attach-user-policy \
  --user-name day03-overly-permissive-user \
  --policy-arn <paste-the-second-policy-arn-here>
```
📸 Screenshot: `04-overly-permissive-policy.png`

**Note down:**
- In plain words, what can `day03-overly-permissive-user` do that `day03-least-priv-user` cannot?
- If you were auditing a real AWS account and found a user with `"Action": "s3:*", "Resource": "*"` attached, what would you flag this as, and why?

---

## Part D: IAM roles — what they're for, and how they differ from users

```bash
cat > trust-policy.json << 'POLICYEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICYEOF

awslocal iam create-role \
  --role-name Day03LambdaExecutionRole \
  --assume-role-policy-document file://trust-policy.json

awslocal iam list-roles
```
📸 Screenshot: `05-iam-roles.png`

**Note down:**
- What does the `trust-policy.json`'s `Principal` field actually control? Who/what is allowed to "become" this role?
- In your own words: what's the fundamental difference between an IAM **user** (Days 01-03 so far) and an IAM **role**?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
