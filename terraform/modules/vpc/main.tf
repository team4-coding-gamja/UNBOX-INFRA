data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 1. VPC 생성 (하드코딩 제거: var.vpc_cidr로 통일)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                        = "${var.project_name}-${var.env}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# 2. 인터넷 게이트웨이
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.env}-igw" }
}

# 3. Public 서브넷
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  # 환경(env) 변수와 EKS 필수 태그를 모두 포함
  tags = {
    Name                                        = "${var.env}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"      # 외부 ALB용
    "kubernetes.io/cluster/${var.cluster_name}" = "shared" # EKS 클러스터 식별용
  }
}

# 4. App 서브넷
resource "aws_subnet" "app" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  # Public 서브넷과 겹치지 않게 인덱스 조정 (예: + 10)
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.env}-private-${var.availability_zones[count.index]}"
    # 내부 로드밸런서(Internal ALB) 생성용 태그
    "kubernetes.io/role/internal-elb" = "1"
    # 이 서브넷을 사용할 EKS 클러스터 이름 명시
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# 5. DB 서브넷
resource "aws_subnet" "db" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 21)
  availability_zone = var.availability_zones[count.index]
  tags              = { Name = "${var.env}-db-${var.availability_zones[count.index]}" }
}

# 6. Public 라우트 테이블 및 연결
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-${var.env}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 1. EIP 생성 (PROD와 DEV 모두 생성되도록 count 수정)
resource "aws_eip" "nat" {
  # env에 상관없이 무조건 1개 생성 (PROD면 NAT GW용, DEV면 NAT Instance용)
  count  = 1
  domain = "vpc"
  tags   = { Name = "${var.env}-nat-eip" }
}

# 2. [추가] EIP를 NAT 인스턴스에 연결 (DEV 환경일 때만 작동)
resource "aws_eip_association" "nat_instance_assoc" {
  count         = var.env != "prod" ? 1 : 0
  instance_id   = aws_instance.nat_instance[0].id
  allocation_id = aws_eip.nat[0].id
}

# 3. [기존 유지] NAT Gateway 설정 (PROD 환경일 때만 작동)
resource "aws_nat_gateway" "main" {
  count         = var.env == "prod" ? 1 : 0
  allocation_id = aws_eip.nat[0].id # 위에서 만든 EIP 사용
  subnet_id     = aws_subnet.public[0].id

  tags       = { Name = "${var.env}-nat" }
  depends_on = [aws_internet_gateway.igw]
}

# 2. NAT Instance (DEV 전용)
resource "aws_instance" "nat_instance" {
  count         = var.env != "prod" ? 1 : 0
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.nano"

  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [var.nat_sg_id]
  source_dest_check      = false

  # 안정성이 검증된 ip route 기반 스크립트로 교체
  user_data = <<-EOF
              #!/bin/bash
              # 1. 포워딩 활성화
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

              # 2. 패키지 설치를 '먼저' 완료
              dnf install -y iptables-services
              systemctl enable iptables

              # 3. 실제 인터페이스 이름 가져오기 (잠시 대기 후 실행)
              sleep 5
              INTERFACE=$(ip route | awk '/default/ {print $5}')

              # 4. 규칙 적용
              iptables -t nat -F  # 기존 규칙 초기화
              iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
              iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1460

              # 5. [핵심] 현재 활성화된 규칙을 파일로 저장 (재부팅 시에도 유지)
              iptables-save > /etc/sysconfig/iptables
              systemctl start iptables
              EOF

  tags = { Name = "${var.env}-nat-instance" }
}

# 3. Private 라우트 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-${var.env}-private-rt" }
}

# 4. Private 라우트 설정 (에러 방지를 위해 count로 리소스 분리)
resource "aws_route" "private_to_nat_gw" {
  count                  = var.env == "prod" ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route" "private_to_nat_instance" {
  count                  = var.env != "prod" ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
}

# 5. Private 서브넷 연결
resource "aws_route_table_association" "app" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}
