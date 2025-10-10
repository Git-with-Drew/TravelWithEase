provider "aws" {
  region = var.aws_region
}

#S3 bucket for hosting static website
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.s3_bucket_name

}

#Bucket public access to the bucket
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.website_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}   

#Bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


#Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id
  depends_on = [ aws_s3_bucket_public_access_block.public_access_block ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "PublicReadGetObject"
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

#S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

#Uploading website files to S3 bucket
resource "aws_s3_object" "website_files" {
  for_each = fileset(var.website_source_directory, "**")

  bucket = aws_s3_bucket.website_bucket.id
  key    = each.value
  source = "${var.website_source_directory}/${each.value}"
  content_type = lookup({
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
  }, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}

#Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}
output "s3_bucket_website_endpoint" {
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
  description = "S3 Bucket Website Endpoint"
