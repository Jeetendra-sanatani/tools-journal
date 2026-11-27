# 🧪 Lab Sheet — Cloud/DevOps Day 05: S3 Security Misconfigurations — Bucket Policies & Public Access

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> 🔐 **This is the single most common real-world AWS finding:** a misconfigured S3 bucket policy exposing data to the whole internet. Today you'll deliberately create that misconfiguration, confirm it's actually exploitable, then fix it properly — the same workflow as a real cloud security assessment, done safely on your own local bucket.

---

## Step 0: Confirm LocalStack + S3 are healthy, set up a workspace

```bash
curl http://localhost:4566/_localstack/health
mkdir -p ~/Desktop/kali/day05-s3-misconfig && cd ~/Desktop/kali/day05-s3-misconfig
```
📸 Screenshot: `01-s3-setup.png`

**Note down:**
- Is `s3` listed as `available`?

---

## Part A: create a bucket and put a "sensitive" file in it

```bash
awslocal s3 mb s3://day05-sensitive-bucket
echo "Customer SSNs: 123-45-6789, 987-65-4321 (fake test data)" > sensitive-data.txt
awslocal s3 cp sensitive-data.txt s3://day05-sensitive-bucket/
awslocal s3 ls s3://day05-sensitive-bucket/
```
📸 Screenshot: `02-s3-bucket-created.png`

**Note down:**
- By default, when you first create a bucket and upload an object, is it publicly readable or private?

---

## Part B: the misconfiguration — apply a public-read bucket policy

```bash
cat > public-read-policy.json << 'POLICYEOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::day05-sensitive-bucket/*"
    }
  ]
}
POLICYEOF
cat public-read-policy.json

awslocal s3api put-bucket-policy \
  --bucket day05-sensitive-bucket \
  --policy file://public-read-policy.json

awslocal s3api get-bucket-policy --bucket day05-sensitive-bucket
```
📸 Screenshot: `03-s3-public-policy-applied.png`

**Note down:**
- What does `"Principal": "*"` specifically mean in this policy? Who does it grant access to?
- This is the exact pattern behind real-world "exposed S3 bucket" breaches you may have read about — why is `Principal: *` + `s3:GetObject` + no other restriction so dangerous on a real AWS account?

---

## Part C: confirm it's actually exploitable — access it with NO credentials

```bash
# simulate an outside attacker: a plain HTTP request, no AWS credentials at all
curl http://localhost:4566/day05-sensitive-bucket/sensitive-data.txt
```
📸 Screenshot: `04-s3-public-access-confirmed.png`

**Note down:**
- Did the file's contents come back, even though you sent no AWS credentials with `curl`?
- If this were a real S3 bucket on the public internet (not LocalStack), who could have run this exact command against it?

---

## Part D: fix it — remove the policy, confirm access is blocked again

```bash
awslocal s3api delete-bucket-policy --bucket day05-sensitive-bucket
awslocal s3api get-bucket-policy --bucket day05-sensitive-bucket

# try the same unauthenticated request again
curl -i http://localhost:4566/day05-sensitive-bucket/sensitive-data.txt
```
📸 Screenshot: `05-s3-fixed-and-verified.png`

**Note down:**
- After removing the policy, what did the unauthenticated `curl` request return this time (status code/error)?
- On real AWS, what's the ONE setting (separate from bucket policies) that AWS itself recommends enabling to prevent this entire class of mistake? (Hint: it's called "Block Public Access")

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
