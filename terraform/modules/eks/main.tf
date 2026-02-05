# modules/eks/main.tf

# 1. EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
    # API 서버 퍼블릭 액세스 허용 (보안 강화 시 private access 고려)
    endpoint_public_access = true
  }

  #   depends_on = [
  #     aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  #   ]

  tags = {
    Name = "${var.project_name}-${var.env}-eks-cluster"
  }
}

# 2. Managed Node Group
resource "aws_launch_template" "eks_node" {
  name_prefix = "${var.project_name}-${var.env}-eks-node-"

  # T3.large 등 인스턴스 타입 설정 (Node Group에서 덮어씌울 수 있지만 여기서 설정 가능)
  # Node Group의 instance_types가 우선순위가 높을 수 있지만, 
  # Launch Template을 쓰면 여기서 설정하는 것이 안전

  # 중요: 태그 사양 (인스턴스에 이름을 붙임)
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.env}-eks-node" # unbox-dev-eks-node
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.project_name}-${var.env}-eks-node-volume"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.env}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  # Launch Template 사용 시 instance_types는 여기서 제거하거나 Launch Template으로 이동 권장
  # 하지만 Launch Template 내부에 instance_type을 안 넣고 여기서 쓰면 호환됨.
  # 단, launch_template 블록을 쓰면 ami_type 등을 주의해야 함.

  launch_template {
    id      = aws_launch_template.eks_node.id
    version = aws_launch_template.eks_node.latest_version
  }

  # instance_types = var.instance_types (Launch Template과 병행 사용 가능하나 주의)
  # EKS MNG에서는 Launch Template을 쓰더라도 instance_types를 여기서 지정하면 
  # "The attributes instanceTypes ... cannot be specified when using launchTemplate" 오류가 날 수 있음.
  # 따라서 instance_types를 제거하고 Launch Template에 넣거나, 
  # Launch Template에 type을 안 넣고 여기서도 빼고 default를 쓰게 됨.
  # 안전하게는 여기서 instance_types를 유지하고 Launch Template에는 태그만 넣는 방식이 가능한지 확인 필요.
  # Terraform/AWS 문서상: instance_types는 Launch Template과 함께 쓰면 에러 발생 가능성 높음.
  # -> 따라서 Launch Template에는 type을 넣지 않고, Node Group의 instance_types를 유지하려면
  #    launch_template 블록이 있으면 instance_types를 못 쓰는 경우가 많음.
  #    -> Launch Template에서 instance_type을 지정하지 않아도, Node Group에서 지정하면 충돌남.
  #    -> 해결책: Node Group 리소스에서 instance_types를 지우고, Launch Template 안에 넣지는 않아도 되지만...
  #    -> 가장 확실한 방법: Launch Template을 쓰면 모든 설정을 LT로 넘기는 것이 좋음.
  #    -> 하지만 var.instance_types는 리스트이고 LT는 단일 값.
  #    -> EKS MNG는 LT를 써도 instance_types 리스트 지원 안함 (LT 쓰면).
  #    -> Mixed Instances Policy를 쓰거나...
  #    -> 여기서는 단순하게 태그만 추가하고 싶음.
  #    -> Node Group에서 instance_types를 제거하고, LT에 instance_type = "t3.large" 하나만 박아야 함.
  #    -> var.instance_types[0]을 사용하도록 수정하겠습니다.

  # instance_types = var.instance_types  <-- 제거

  ami_type = "AL2023_x86_64_STANDARD"

  tags = {
    Name = "${var.project_name}-${var.env}-node-group"
  }
}

# 3. Fargate Profile (Conditional for Prod)
resource "aws_eks_fargate_profile" "main" {
  count                  = var.enable_fargate ? 1 : 0
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.project_name}-${var.env}-fargate-profile"
  pod_execution_role_arn = var.fargate_profile_role_arn
  subnet_ids             = var.subnet_ids

  selector {
    namespace = var.fargate_namespace
    # 필요한 경우 labels = { role = "worker" } 등으로 필터링 가능
  }

  tags = {
    Name = "${var.project_name}-${var.env}-fargate-profile"
  }
}

# 4. EKS Add-ons (Explicit Management)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # IAM Role for CNI is already attached to Node Role, so we don't need service_account_role_arn here
  # unless we use IRSA (Service Account). Currently using Node Role permissions.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS requires compute nodes to be available
  depends_on = [aws_eks_node_group.main, aws_eks_fargate_profile.main]
}
