# Getting started

Two ways to run ClinicFlow. Start with the local one: it needs no AWS account.

## 1. Run it on your computer

Needs Git and Docker with Compose.

```bash
git clone https://github.com/Apoor-Tyagi/clinicflow-app.git
cd clinicflow-app
cp .env.example .env
docker compose up --build
```

Open <http://localhost:8000>. The sign-in screen asks for a clinic API key. Create a
clinic in a second terminal (the key is shown once):

```bash
cd clinicflow-app
source .env
curl -s -X POST localhost:8000/api/v1/admin/clinics -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{"name": "Demo Clinic"}'
```

Paste the `api_key` into the sign-in screen, add a patient with an email address, and
book an appointment. The reminder appears as a queued row; nothing is emailed locally
because sending needs AWS (section 2). API docs are at <http://localhost:8000/docs>.
`docker compose down -v` stops everything and deletes the local database.

Run the tests (Python 3.15 is what CI uses):

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest -q
```

Database-backed tests skip unless the `TENANT_TEST_*` variables are set; the app README
explains them. CI runs them on every pull request.

## 2. Run it on AWS (real emails)

This creates billable resources (EC2, RDS, EventBridge, SQS, SES, a Backup vault).
Every session in this project ended with `terraform destroy`. Needs an AWS account,
the AWS CLI signed in, Terraform, `gh`, and a Gmail or other mailbox you can verify.

1. **Once per account: bootstrap.** It creates the state bucket, the GitHub OIDC
   provider and roles, the ECR repository, CloudTrail and a budget. It uses local
   state, which lives only on the machine that ran it, so back up
   `bootstrap/terraform.tfstate` somewhere safe.

   ```bash
   cd bootstrap
   cp tfvars.example terraform.tfvars   # edit it
   terraform init && terraform apply
   ```

   Then change the `bucket` name in `envs/*/backend.tf` to the one it created.
2. **Publish the image.** Push to `main` in `clinicflow-app` (or run its workflow);
   CI builds and pushes the image to ECR. Put that image tag in
   `clinicflow-gitops/apps/clinicflow-api/overlays/aws-dev/kustomization.yaml`.
3. **Apply the dev environment.**

   ```bash
   cd envs/dev
   cp tfvars.example terraform.tfvars   # edit it
   terraform init && terraform apply
   ```

4. **Confirm the emails AWS sends you:** the SES sender verification, and the alarm
   subscription. While SES is in sandbox mode, every recipient address must also be
   a verified SES identity.
5. **Wait about 5 minutes** for the node to boot, then open the UI through Session
   Manager (nothing is public). Use the command in the `k3s_ssm_connect_command`
   output, and forward the node's port 8000 to your computer. Create a clinic as in
   section 1, using the admin token from the node's configuration.
6. **Book an appointment** with a verified recipient. The dispatcher creates a
   schedule, the worker sends the email about a minute later, and the audit record
   lands in DynamoDB. The measured timeline is in
   [ADR 0016](adr/0016-reminder-dispatcher.md).
7. **Tear down:** `terraform destroy` in `envs/dev`. The node also shuts itself
   down after 4 hours, but RDS keeps billing until destroyed.

Section 2 was run end to end during the build, but not again from a fresh clone.
Treat it as a guide and check it against the ADRs if a step differs.
