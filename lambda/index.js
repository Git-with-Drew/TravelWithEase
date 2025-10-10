// Initialize AWS Services
const AWS = require("aws-sdk");
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const ses = new AWS.SES();

// FIXED: Environment variables to match backend.tf configuration
const TABLE_NAME = process.env.TABLE_NAME || process.env.DYNAMODB_TABLE_NAME;
const FROM_EMAIL = process.env.FROM_EMAIL || process.env.SES_SENDER;
const TO_EMAIL = process.env.BUSINESS_EMAIL || process.env.SES_RECIPIENT;

// FIXED: Generate simple ID without uuid package
function generateId() {
  return `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

exports.handler = async (event) => {
  try {
    // Log the incoming event for debugging
    console.log("Received event:", JSON.stringify(event));

    // Check environment variables
    console.log("Environment check:", {
      TABLE_NAME: TABLE_NAME ? "configured" : "MISSING",
      FROM_EMAIL: FROM_EMAIL ? "configured" : "MISSING",
      TO_EMAIL: TO_EMAIL ? "configured" : "MISSING"
    });

    // Parse the request body
    const body = JSON.parse(event.body);
    console.log("Parsed body:", body);

    // Validate required fields including message
    if (!body.name || !body.email || !body.message) {
      return formatResponse(400, {
        message: "Missing required fields: name, email, and message are required",
      });
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(body.email)) {
      return formatResponse(400, {
        message: "Invalid email address format",
      });
    }

    // Generate a unique ID for the submission
    const submissionId = generateId();
    const timestamp = new Date().toISOString();

    // Prepare item for DynamoDB
    const item = {
      id: submissionId,
      name: body.name,
      email: body.email.toLowerCase().trim(),
      phone: body.phone || null,
      destination: body.destination || null,
      travelDateStart: body.travelDateStart || null,
      travelDateEnd: body.travelDateEnd || null,
      travelers: body.travelers || null,
      message: body.message || null,
      submittedAt: timestamp,
      status: "new"
    };

    console.log("Saving to DynamoDB:", item);

    // Save to DynamoDB
    await dynamoDB
      .put({
        TableName: TABLE_NAME,
        Item: item,
      })
      .promise();

    console.log("Successfully saved to DynamoDB");

    // Send emails (don't fail the submission if emails fail)
    try {
      if (FROM_EMAIL && body.email) {
        await sendCustomerConfirmation(item);
        console.log("Customer confirmation email sent");
      } else {
        console.warn("Skipping customer email - FROM_EMAIL not configured");
      }

      if (FROM_EMAIL && TO_EMAIL) {
        await sendBusinessNotification(item);
        console.log("Business notification email sent");
      } else {
        console.warn("Skipping business email - FROM_EMAIL or TO_EMAIL not configured");
      }
    } catch (emailError) {
      console.error("Email sending failed, but form was saved:", emailError);
      // Continue - don't fail the submission because of email issues
    }

    // Return success response
    return formatResponse(200, {
      success: true,
      message: "Form submitted successfully! We'll get back to you within 24 hours.",
      submissionId,
      timestamp,
    });
  } catch (error) {
    console.error("Error processing submission:", error);
    console.error("Error stack:", error.stack);
    
    return formatResponse(500, {
      success: false,
      message: "Error processing submission. Please try again later.",
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
};

/**
 * Format API Gateway response
 */
function formatResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*", // Allow requests from any origin (CORS)
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
    },
    body: JSON.stringify(body),
  };
}

/**
 * Send confirmation email to customer
 */
async function sendCustomerConfirmation(formData) {
  const params = {
    Destination: {
      ToAddresses: [formData.email],
    },
    Message: {
      Body: {
        Html: {
          Charset: "UTF-8",
          Data: `
            <html>
              <head>
                <style>
                  body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                  .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #fff; }
                  .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
                  h1 { color: white; margin: 0; font-size: 28px; }
                  .content { padding: 30px; border: 1px solid #e0e0e0; border-top: none; }
                  .highlight { background: #f8f9ff; padding: 15px; margin: 20px 0; border-left: 4px solid #667eea; border-radius: 4px; }
                  .footer { margin-top: 30px; padding: 20px; font-size: 12px; color: #7f8c8d; background: #f8f9fa; text-align: center; border-radius: 0 0 8px 8px; }
                  ul { padding-left: 20px; }
                  li { margin: 10px 0; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <h1>🌍 Travel with Ease</h1>
                    <p style="margin: 10px 0 0 0;">Thank You for Your Travel Inquiry</p>
                  </div>
                  <div class="content">
                    <p>Dear ${escapeHtml(formData.name)},</p>
                    <p>We have received your travel inquiry and are excited to help you plan your journey! Here's a summary of the information you provided:</p>
                    
                    
                    
                    <ul>
                      ${formData.destination ? `<li><strong>Destination:</strong> ${escapeHtml(formData.destination)}</li>` : ""}
                      ${formData.travelDateStart ? `<li><strong>Travel Dates:</strong> ${escapeHtml(formData.travelDateStart)} to ${escapeHtml(formData.travelDateEnd || "TBD")}</li>` : ""}
                      ${formData.travelers ? `<li><strong>Number of Travelers:</strong> ${escapeHtml(formData.travelers)}</li>` : ""}
                      ${formData.phone ? `<li><strong>Phone:</strong> ${escapeHtml(formData.phone)}</li>` : ""}
                    </ul>
                    
                    <p><strong>Your Message:</strong></p>
                    <div style="background: #fafafa; padding: 15px; border: 1px solid #e0e0e0; border-radius: 4px;">
                      ${escapeHtml(formData.message || "No additional message").replace(/\n/g, '<br>')}
                    </div>
                    
                    <p>A member of our travel team will review your inquiry and get back to you within 24 hours.</p>

                    <div class="highlight">
                      <strong>📋 Your Reference Number:</strong> ${formData.id}
                    </div>
                    
                    <p>Best regards,<br><strong>The Travel with Ease Team</strong> ✈️</p>
                  </div>
                  <div class="footer">
                    <p>This is an automated message. Please do not reply to this email.</p>
                    <p>© ${new Date().getFullYear()} Travel with Ease. All rights reserved.</p>
                  </div>
                </div>
              </body>
            </html>
          `,
        },
        Text: {
          Charset: "UTF-8",
          Data: `
Thank You for Your Travel Inquiry

Dear ${formData.name},

We have received your travel inquiry and are excited to help you plan your journey!

Your Reference Number: ${formData.id}

Summary of your inquiry:
${formData.destination ? `Destination: ${formData.destination}` : ""}
${formData.travelDateStart ? `Travel Dates: ${formData.travelDateStart} to ${formData.travelDateEnd || "TBD"}` : ""}
${formData.travelers ? `Number of Travelers: ${formData.travelers}` : ""}
${formData.phone ? `Phone: ${formData.phone}` : ""}

Your Message:
${formData.message || "No additional message"}

A member of our travel team will review your inquiry and get back to you within 24 hours.

Best regards,
The Travel with Ease Team ✈️

---
This is an automated message. Please do not reply to this email.
© ${new Date().getFullYear()} Travel with Ease. All rights reserved.
          `,
        },
      },
      Subject: {
        Charset: "UTF-8",
        Data: "Thank You for Your Travel Inquiry - Travel with Ease",
      },
    },
    Source: FROM_EMAIL,
  };

  return ses.sendEmail(params).promise();
}

/**
 * Send notification to business
 */
async function sendBusinessNotification(formData) {
  const params = {
    Destination: {
      ToAddresses: [TO_EMAIL],
    },
    Message: {
      Body: {
        Html: {
          Charset: "UTF-8",
          Data: `
            <html>
              <head>
                <style>
                  body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                  .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                  .header { background: #2c5282; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                  h1 { color: white; margin: 0; }
                  table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                  table, th, td { border: 1px solid #ddd; }
                  th, td { padding: 12px; text-align: left; }
                  th { background-color: #f2f2f2; font-weight: bold; width: 30%; }
                  .priority { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <h1>🆕 New Travel Inquiry</h1>
                  </div>
                  <div style="padding: 20px; border: 1px solid #ddd; border-top: none;">
                    <div class="priority">
                      <strong>⚡ Action Required:</strong> New customer inquiry received. Please respond within 24 hours.
                    </div>
                    
                    <table>
                      <tr>
                        <th>Reference ID</th>
                        <td>${escapeHtml(formData.id)}</td>
                      </tr>
                      <tr>
                        <th>Name</th>
                        <td>${escapeHtml(formData.name)}</td>
                      </tr>
                      <tr>
                        <th>Email</th>
                        <td><a href="mailto:${escapeHtml(formData.email)}">${escapeHtml(formData.email)}</a></td>
                      </tr>
                      ${formData.phone ? `<tr><th>Phone</th><td><a href="tel:${escapeHtml(formData.phone)}">${escapeHtml(formData.phone)}</a></td></tr>` : ""}
                      ${formData.destination ? `<tr><th>Destination</th><td>${escapeHtml(formData.destination)}</td></tr>` : ""}
                      ${formData.travelDateStart ? `<tr><th>Travel Dates</th><td>${escapeHtml(formData.travelDateStart)} to ${escapeHtml(formData.travelDateEnd || "TBD")}</td></tr>` : ""}
                      ${formData.travelers ? `<tr><th>Travelers</th><td>${escapeHtml(formData.travelers)}</td></tr>` : ""}
                      <tr>
                        <th>Message</th>
                        <td>${escapeHtml(formData.message || "No message provided").replace(/\n/g, '<br>')}</td>
                      </tr>
                      <tr>
                        <th>Submitted At</th>
                        <td>${new Date(formData.submittedAt).toLocaleString()}</td>
                      </tr>
                    </table>
                  </div>
                </div>
              </body>
            </html>
          `,
        },
        Text: {
          Charset: "UTF-8",
          Data: `
🆕 NEW TRAVEL INQUIRY

⚡ Action Required: New customer inquiry received. Please respond within 24 hours.

Reference ID: ${formData.id}
Name: ${formData.name}
Email: ${formData.email}
${formData.phone ? `Phone: ${formData.phone}` : ""}
${formData.destination ? `Destination: ${formData.destination}` : ""}
${formData.travelDateStart ? `Travel Dates: ${formData.travelDateStart} to ${formData.travelDateEnd || "TBD"}` : ""}
${formData.travelers ? `Travelers: ${formData.travelers}` : ""}

Message:
${formData.message || "No message provided"}

Submitted At: ${new Date(formData.submittedAt).toLocaleString()}
          `,
        },
      },
      Subject: {
        Charset: "UTF-8",
        Data: `New Travel Inquiry - ${formData.id}`,
      },
    },
    Source: FROM_EMAIL,
  };

  return ses.sendEmail(params).promise();
}

/**
 * Helper function to escape HTML
 */
function escapeHtml(text) {
  if (!text) return '';
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}