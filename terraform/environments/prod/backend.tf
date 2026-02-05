terraform {
  backend "s3" {
    bucket         = "unbox-terraform-state-bucket-1" # 부트스트랩에서 성공한 그 이름
    key            = "prod/terraform.tfstate"           # 이 경로에 장부가 저장됩니다
    region         = "ap-northeast-2"
    dynamodb_table = "unbox-terraform-locks"           # 아까 만든 테이블 이름
    encrypt        = true
  }
}