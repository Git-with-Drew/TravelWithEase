# TravelEase Contact Form - Serverless AWS Solution

A production-ready, serverless contact form system built with AWS services and Terraform. This project demonstrates secure cloud architecture, Infrastructure as Code best practices, and full-stack development capabilities.

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![JavaScript](https://img.shields.io/badge/javascript-%23323330.svg?style=for-the-badge&logo=javascript&logoColor=%23F7DF1E)
![Node.js](https://img.shields.io/badge/node.js-6DA55F?style=for-the-badge&logo=node.js&logoColor=white)

## 🎯 Project Overview

This project solves a common business problem: professional customer inquiry management for small businesses. Built for a travel company transitioning from basic mailto links to a scalable, automated contact form system.

**Key Features:**
- ✅ Instant customer confirmation emails with reference numbers
- ✅ Automated business notifications for new inquiries
- ✅ Secure data storage with searchable indexes
- ✅ Real-time form validation
- ✅ Mobile-responsive design
- ✅ Complete Infrastructure as Code (Terraform)
- ✅ Cost-effective serverless architecture (<$2/month)

## 🏗️ Architecture

```
┌─────────────┐
│   S3 Bucket │  (Static Website Hosting)
│  (Frontend) │
└──────┬──────┘
       │
       ↓
┌─────────────────┐
│  API Gateway    │  (REST API + CORS)
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Lambda Function│  (Node.js 20.x)
│  (Form Handler) │
└────┬────────┬───┘
     │        │
     ↓        ↓
┌─────────┐  ┌──────────┐
│DynamoDB │  │   SES    │
│(Storage)│  │ (Email)  │
└─────────┘  └──────────┘
```

### AWS Services Used

- **Amazon S3**: Static website hosting for frontend
- **API Gateway**: RESTful API endpoint with CORS support
- **AWS Lambda**: Serverless function for form processing (Node.js 20.x)
- **DynamoDB**: NoSQL database for inquiry storage with GSI for email lookups
- **Amazon SES**: Email service for confirmations and notifications
- **Terraform**: Infrastructure as Code for reproducible deployments

## 🔒 Security Features

As a security-focused implementation, this project includes:

- **IAM Least Privilege**: Lambda execution role with minimal required permissions
- **Input Validation**: Server-side validation of all form fields
- **HTML Escaping**: XSS prevention in email templates
- **CORS Configuration**: Properly scoped cross-origin resource sharing
- **API Rate Limiting**: Built-in API Gateway throttling
- **Error Handling**: Graceful degradation and comprehensive logging
- **Email Validation**: Regex-based validation to prevent invalid submissions

## 📁 Project Structure

```
travelease-contact/
├── frontend/
│   ├── index.html           # Contact form interface
│   ├── styles.css           # Responsive styling
│   └── script.js.tpl        # Form validation & API integration (Terraform template)
├── lambda/
│   ├── index.js             # Lambda function handler
│   ├── package.json         # Node.js dependencies
│   └── package_lambda.sh    # Lambda packaging script
├── main.tf                  # S3 and website configuration
├── backend.tf               # Lambda, API Gateway, DynamoDB, SES
├── variables.tf             # Terraform variable definitions
├── terraform.tfvars         # Environment-specific values (not included)
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- [Terraform](https://www.terraform.io/downloads) (v1.0+)
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- Node.js 18+ (for local Lambda development)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/travelease-contact.git
   cd travelease-contact
   ```

2. **Configure Terraform variables**
   
   Create a `terraform.tfvars` file:
   ```hcl
   aws_region              = "us-east-1"
   s3_bucket_name          = "your-unique-bucket-name"
   ses_sender_email        = "noreply@yourdomain.com"
   ses_recipient_email     = "business@yourdomain.com"
   environment             = "dev"
   api_gateway_stage_name  = "dev"
   ```

3. **Verify SES Email Addresses**
   
   Before deployment, verify your sender and recipient emails in AWS SES:
   ```bash
   aws ses verify-email-identity --email-address noreply@yourdomain.com
   aws ses verify-email-identity --email-address business@yourdomain.com
   ```
   
   Check your inbox and click the verification links.

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Review the deployment plan**
   ```bash
   terraform plan
   ```

6. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```
   
   Type `yes` when prompted.

7. **Note the outputs**
   
   After deployment, Terraform will output:
   - S3 website endpoint
   - API Gateway invoke URL
   
   Your contact form will be live at the S3 website endpoint!

## 📊 Cost Breakdown

Based on 100 form submissions per month:

| Service | Usage | Cost |
|---------|-------|------|
| S3 | Storage + Requests | ~$0.50 |
| API Gateway | 100 API calls | ~$0.35 |
| Lambda | Execution time | $0.00 (free tier) |
| DynamoDB | On-demand writes/reads | $0.00 (free tier) |
| SES | 200 emails | ~$0.20 |
| **Total** | | **~$1.05/month** |

*Costs scale linearly with usage. Free tier covers most small business needs.*

## 🧪 Testing

### Test the API endpoint directly

```bash
curl -X POST https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/submit \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1-555-0100",
    "destination": "europe",
    "travelDateStart": "2025-06-15",
    "travelDateEnd": "2025-06-30",
    "travelers": "2",
    "message": "Interested in a European tour package"
  }'
```

### Expected Response

```json
{
  "success": true,
  "message": "Form submitted successfully! We'll get back to you within 24 hours.",
  "submissionId": "sub_1234567890_abc123",
  "timestamp": "2025-10-09T12:34:56.789Z"
}
```

## 📧 Email Templates

The system sends two types of emails:

### Customer Confirmation Email
- Professional HTML template with company branding
- Includes submission reference number
- Summarizes all provided information
- Plain text fallback for compatibility

### Business Notification Email
- Urgent notification styling
- Complete customer information in table format
- Clickable email and phone links
- Submission timestamp

## 🔧 Configuration

### Environment Variables (Lambda)

The Lambda function uses the following environment variables (automatically set by Terraform):

- `TABLE_NAME`: DynamoDB table name
- `FROM_EMAIL`: SES verified sender email
- `BUSINESS_EMAIL`: Recipient email for notifications

### Terraform Variables

All configurable values are in `variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Globally unique S3 bucket name"
}

variable "ses_sender_email" {
  description = "Verified SES sender email address"
}

variable "ses_recipient_email" {
  description = "Business email for notifications"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)"
  default     = "dev"
}
```

## 🐛 Troubleshooting

### Common Issues

**1. Email not sending**
- Verify both sender and recipient emails in SES
- Check CloudWatch Logs for Lambda errors
- Ensure SES is out of sandbox mode for production use

**2. CORS errors in browser**
- Verify API Gateway CORS configuration
- Check that frontend is making requests to correct API endpoint
- Ensure OPTIONS method is properly configured

**3. Form submissions not saving**
- Check Lambda execution role permissions
- Review DynamoDB table name in environment variables
- Check CloudWatch Logs for detailed error messages

**4. Terraform apply fails**
- Ensure S3 bucket name is globally unique
- Verify AWS credentials are properly configured
- Check that required providers are installed

### Viewing Logs

```bash
# View Lambda function logs
aws logs tail /aws/lambda/TravelWithEase_ContactFormHandler --follow

# View API Gateway execution logs (if enabled)
aws logs tail API-Gateway-Execution-Logs_<api-id>/<stage> --follow
```

## 🔄 Updates and Maintenance

### Updating the Lambda Function

1. Modify `lambda/index.js`
2. Run `terraform apply` - Terraform automatically detects changes and redeploys

### Updating the Frontend

1. Modify files in `frontend/`
2. Run `terraform apply` - Files are automatically uploaded to S3

### Destroying the Infrastructure

To remove all AWS resources:

```bash
terraform destroy
```

**⚠️ Warning**: This will permanently delete all data in DynamoDB.

## 📈 Monitoring

### Key Metrics to Monitor

- Lambda invocation count and errors
- API Gateway 4xx/5xx error rates
- DynamoDB read/write capacity
- SES bounce and complaint rates

### Setting Up CloudWatch Alarms

```bash
# Example: Lambda error alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "TravelContactLambdaErrors" \
  --alarm-description "Alert on Lambda function errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

## 🎓 Key Learning Outcomes

This project demonstrates:

- ✅ **Infrastructure as Code**: Complete Terraform implementation
- ✅ **Serverless Architecture**: Event-driven, auto-scaling design
- ✅ **Security Best Practices**: IAM, input validation, XSS prevention
- ✅ **Full-Stack Development**: Frontend + backend integration
- ✅ **Production Readiness**: Error handling, logging, monitoring
- ✅ **Cost Optimization**: Pay-per-use serverless economics
- ✅ **API Design**: RESTful endpoints with proper CORS
- ✅ **Email Deliverability**: SES configuration and templating

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

**Your Name** - [Your LinkedIn](https://linkedin.com/in/yourprofile)

Project Link: [https://github.com/yourusername/travelease-contact](https://github.com/yourusername/travelease-contact)

---

**Built with ☁️ by a security professional expanding into cloud engineering**