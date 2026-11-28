# 🧪 Lab Sheet — Cloud/DevOps Day 06: S3 Event-Driven Lambda — Connecting the Dots

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

> 🔗 **This day ties Days 04 and 05 together:** instead of manually `invoke`-ing a Lambda function (Day 04) or manually uploading to S3 (Day 05), today a file landing in a bucket **automatically** triggers a Lambda function — no manual invoke needed. This is one of the most common real-world serverless patterns (e.g. auto-processing uploaded images, auto-scanning uploaded files).

---

## Step 0: Confirm LocalStack is healthy, set up a workspace

```bash
curl http://localhost:4566/_localstack/health
mkdir -p ~/Desktop/kali/day06-s3-lambda && cd ~/Desktop/kali/day06-s3-lambda
```
📸 Screenshot: `01-trigger-setup.png`

**Note down:**
- Are both `s3` and `lambda` listed as `available`?

---

## Part A: write a Lambda function that reads WHICH file triggered it

```bash
cat > trigger_handler.py << 'PYEOF'
import json

def lambda_handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        print(f"File uploaded: s3://{bucket}/{key}")
    return {"statusCode": 200, "body": "processed"}
PYEOF
cat trigger_handler.py
zip trigger_function.zip trigger_handler.py
```
📸 Screenshot: `02-trigger-code.png`

**Note down:**
- Unlike Day 04's `event` (which you built yourself with `--payload`), where does THIS event's structure (`Records`, `s3.bucket.name`, `s3.object.key`) actually come from?
- Why does the function loop over `event.get("Records", [])` instead of assuming there's always exactly one record?

---

## Part B: create the function and a bucket to watch

```bash
awslocal lambda create-function \
  --function-name Day06TriggerFunction \
  --runtime python3.12 \
  --handler trigger_handler.lambda_handler \
  --zip-file fileb://trigger_function.zip \
  --role arn:aws:iam::000000000000:role/Day03LambdaExecutionRole

awslocal s3 mb s3://day06-trigger-bucket
```
📸 Screenshot: `03-trigger-function-bucket.png`

**Note down:**
- Did reusing Day 03's IAM role work again here, same as Day 04?

---

## Part C: wire the bucket to the function (the actual "trigger")

```bash
# get the function's ARN first
FUNC_ARN=$(awslocal lambda get-function --function-name Day06TriggerFunction --query 'Configuration.FunctionArn' --output text)
echo "$FUNC_ARN"

# allow S3 to invoke the function
awslocal lambda add-permission \
  --function-name Day06TriggerFunction \
  --statement-id s3invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::day06-trigger-bucket

# configure the actual notification: "when an object is created, call this Lambda"
cat > notification.json << 'NOTIFEOF'
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "REPLACE_WITH_FUNC_ARN",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
NOTIFEOF
sed -i "s|REPLACE_WITH_FUNC_ARN|$FUNC_ARN|" notification.json

awslocal s3api put-bucket-notification-configuration \
  --bucket day06-trigger-bucket \
  --notification-configuration file://notification.json
```
📸 Screenshot: `04-trigger-wired.png`

**Note down:**
- What does `add-permission` actually do here — why would S3 need explicit permission to call a function that already has an execution role?
- What event type did you subscribe to (`s3:ObjectCreated:*`)? What other event types might exist (think: what happens to an object besides being created)?

---

## Part D: upload a file and confirm the function ran WITHOUT being invoked manually

```bash
echo "this upload should trigger the function" > trigger-test.txt
awslocal s3 cp trigger-test.txt s3://day06-trigger-bucket/

# give it a second, then check the function's logs for the print() output
sleep 3
awslocal logs describe-log-groups | grep Day06TriggerFunction
awslocal logs tail /aws/lambda/Day06TriggerFunction 2>/dev/null || \
  awslocal logs describe-log-streams --log-group-name /aws/lambda/Day06TriggerFunction
```
📸 Screenshot: `05-trigger-confirmed.png`

**Note down:**
- Did the log output show your `print()` line with the actual bucket/key that was uploaded — WITHOUT you ever running `lambda invoke` yourself?
- In one sentence: what's the real difference between Day 04's workflow (manual `invoke`) and today's (automatic trigger)?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md` and help you write `notes.txt`.
