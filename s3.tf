# ────────────────────────────────────────────────────────────────────────────
# S3 버킷 - 백엔드 파일 업로드/다운로드용
# ────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "app" {
  bucket = "${var.project_name}-${var.environment}-files-${data.aws_caller_identity.current.account_id}-mj"
  # account_id를 suffix로 붙여 전 세계 고유 버킷 이름 보장

  tags = {
    Name = "${var.project_name}-files"
  }
}

# 퍼블릭 액세스 전면 차단 (백엔드가 IRSA로 비공개 접근)
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}
# 현재 AWS 계정 ID 조회 (버킷 이름 suffix용)
data "aws_caller_identity" "current" {}
