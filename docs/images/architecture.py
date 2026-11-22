"""Generates docs/images/architecture.png with official AWS icons.
Run from the repo root:  python docs/images/architecture.py
Needs: pip install diagrams  and  brew install graphviz
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2, ECR
from diagrams.aws.database import RDS, Dynamodb
from diagrams.aws.integration import Eventbridge, SQS
from diagrams.aws.engagement import SES
from diagrams.aws.security import KMS, IAM, SecretsManager
from diagrams.aws.management import SystemsManager
from diagrams.aws.storage import S3
from diagrams.aws.cost import Budgets
from diagrams.onprem.vcs import Github
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.gitops import Argocd
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.k8s.compute import Pod

graph = {"splines": "spline", "fontsize": "22", "pad": "0.5",
         "nodesep": "0.6", "ranksep": "1.1", "compound": "true"}
dashed = {"style": "dashed", "color": "#777777"}

with Diagram("ClinicFlow architecture", filename="docs/images/architecture",
             outformat="png", show=False, direction="LR", graph_attr=graph):

    with Cluster("Delivery"):
        gh = Github("GitHub\n3 repos")
        ci = GithubActions("Actions\ncheckov, tflint,\nTrivy, tests")
        oidc = IAM("OIDC role\nno stored keys")
        gh >> ci >> oidc

    with Cluster("Local (free)"):
        local = Argocd("k3d + Argo CD")
        prom = Prometheus("Prometheus")
        graf = Grafana("Grafana\nSLO alerts")
        local >> prom >> graf

    with Cluster("AWS us-east-1"):
        ecr = ECR("ECR\nmulti-arch images")

        with Cluster("VPC 10.0.0.0/16, no NAT"):
            with Cluster("Public subnet"):
                node = EC2("k3s node\nt3.medium")
                api = Pod("API pods")
                argo = Argocd("Argo CD")
                worker = EC2("Worker\n(systemd)")
            with Cluster("Data subnets"):
                rds = RDS("PostgreSQL 17\nRLS + TLS")

        with Cluster("Reminder pipeline"):
            sched = Eventbridge("Scheduler")
            queue = SQS("SQS + DLQ")
            ses = SES("SES")
            audit = Dynamodb("Audit table")

        secret = SecretsManager("RDS master secret")

        with Cluster("Shared services"):
            kms = KMS("KMS keys")
            ssm = SystemsManager("Session Manager")
            state = S3("Terraform state")
            budget = Budgets("Budgets")

        # delivery
        ci >> Edge(label="push") >> ecr
        oidc >> Edge(label="plan role", **dashed) >> state
        ecr >> Edge(label="pull") >> node

        # cluster internals
        node >> Edge(arrowhead="none") >> argo
        node >> Edge(arrowhead="none") >> api
        node >> Edge(arrowhead="none") >> worker
        api >> Edge(label="SQL") >> rds
        secret >> Edge(label="bootstrap", **dashed) >> node

        # reminder flow, left to right
        sched >> queue >> Edge(label="poll") >> worker
        worker >> Edge(label="send") >> ses
        worker >> Edge(label="audit") >> audit

    with Cluster("AWS us-west-2 (DR, on demand)"):
        kms_dr = KMS("KMS key (DR)")
        snap = RDS("Snapshot copy\n1 min 35 s")
        restored = RDS("Restored RDS\n10 min 25 s")
        kms_dr >> snap >> restored

    rds >> Edge(label="cross-region copy", **dashed) >> snap
