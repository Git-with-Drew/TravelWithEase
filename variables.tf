variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
  
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket to create" // Change to a globally unique name
  type        = string

  
}

variable "website_source_directory" {
  description = "The directory containing website files to upload"
  type        = string
  default     = "frontend" // Adjust the path as necessary
  
}

#Backend variables
variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table for contact form submissions"
  type        = string
  default     = "TravelContactFormSubmissions"

}

variable "ses_sender_email" {
  description = "The verified SES sender email address"
  type        = string
}

variable "ses_recipient_email" {
  description = "The recipient email address for contact form submissions"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
} 

variable "api_gateway_stage_name" {
  description = "The name of the API Gateway stage"
  type        = string
  default     = "dev"
  
}
