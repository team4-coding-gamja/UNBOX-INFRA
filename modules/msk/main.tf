# 1. PROD 환경일 때만 생성되는 일반 MSK (Provisioned)
resource "aws_msk_cluster" "provisioned" {
  count = var.env == "prod" ? 1 : 0 # prod일 때만 1개 생성

  cluster_name           = "${var.project_name}-${var.env}-msk"
  kafka_version          = "3.8.x.kraft"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = var.private_db_subnet_ids
    security_groups = [var.msk_sg_id]

    storage_info {
      ebs_storage_info { volume_size = 10 }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }
}

# 2. DEV 환경일 때만 생성되는 Serverless MSK
resource "aws_msk_serverless_cluster" "serverless" {
  count = var.env == "dev" ? 1 : 0 # dev일 때만 1개 생성

  cluster_name = "${var.project_name}-${var.env}-msk-serverless"

  vpc_config {
    subnet_ids         = var.private_db_subnet_ids
    security_group_ids = [var.msk_sg_id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }
}
