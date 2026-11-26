# 🧪 Lab Sheet — Cloud/DevOps Day 04: Lambda Functions — Serverless Basics

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> 🔗 **Direct continuation of Day 03:** you already built `Day03LambdaExecutionRole`, a role whose trust policy specifically allows `lambda.amazonaws.com` to assume it. Today that role stops being theory — you'll actually attach it to a real Lambda function and invoke it.

---

## Step 0: Confirm LocalStack + Lambda are healthy, reuse Day 03's role

```bash
curl http://localhost:4566/_localstack/health
mkdir -p ~/Desktop/kali/day04-lambda && cd ~/Desktop/kali/day04-lambda

# confirm Day 03's role still exists
awslocal iam list-roles | grep -A 3 Day03LambdaExecutionRole
```
📸 Screenshot: `01-lambda-setup.png`

**Note down:**
- Is `lambda` listed as `available` in the health check?
- Did Day 03's role (`Day03LambdaExecutionRole`) still exist, or did you need to recreate it?

---

## Part A: write a minimal Lambda function (Python)

```bash
cat > handler.py << 'PYEOF'
def lambda_handler(event, context):
    name = event.get("name", "world")
    return {
        "statusCode": 200,
        "body": f"Hello, {name}! This ran inside a Lambda function."
    }
PYEOF
cat handler.py
zip function.zip handler.py
```
📸 Screenshot: `02-lambda-code.png`

**Note down:**
- What does `event` represent in a Lambda function — where does that data actually come from when the function is invoked?
- Why does Lambda need the code zipped up rather than just pointing at a `.py` file directly?

---

## Part B: create the Lambda function, using Day 03's role

```bash
awslocal lambda create-function \
  --function-name Day04HelloFunction \
  --runtime python3.12 \
  --handler handler.lambda_handler \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::000000000000:role/Day03LambdaExecutionRole

awslocal lambda list-functions
```
📸 Screenshot: `03-lambda-create.png`

**Note down:**
- What does `--handler handler.lambda_handler` actually tell Lambda to do (what's the `filename.function_name` format mean)?
- What State did `list-functions` show for your new function (e.g. `Active`, `Pending`)?

---

## Part C: invoke the function, with different inputs

```bash
awslocal lambda invoke \
  --function-name Day04HelloFunction \
  --payload '{"name": "Cloud Day 4"}' \
  --cli-binary-format raw-in-base64-out \
  response.json
cat response.json

awslocal lambda invoke \
  --function-name Day04HelloFunction \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  response2.json
cat response2.json
```
📸 Screenshot: `04-lambda-invoke.png`

**Note down:**
- Did the first invocation's response actually include "Cloud Day 4", matching what you sent in `--payload`?
- The second invocation sent an empty payload (`{}`) — what did the function return, and why (check `handler.py`'s `event.get("name", "world")` line)?

---

## Part D: check logs, then clean up

```bash
awslocal logs describe-log-groups | grep Day04HelloFunction

awslocal lambda delete-function --function-name Day04HelloFunction
awslocal lambda list-functions
```
📸 Screenshot: `05-lambda-logs-cleanup.png`

**Note down:**
- Did a CloudWatch-style log group get created automatically for your function? What's it named?
- Did the function actually disappear from `list-functions` after deletion?
- In one sentence: why is "serverless" a slightly misleading name for Lambda (hint: there IS still a server, you just don't manage it)?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
