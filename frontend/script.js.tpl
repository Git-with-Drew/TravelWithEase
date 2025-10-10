class TravelFormValidator {
    constructor(formId, apiUrl) {
        this.form = document.getElementById(formId);
        this.apiUrl = apiUrl;
        this.fields = {
            firstName: { required: true, minLength: 2 },
            lastName: { required: true, minLength: 2 },
            email: { required: true, pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/ },
            phone: { required: false, pattern: /^[\+]?[\d\s\-\(\)]{10,}$/ },
            destination: { required: true },
            travelType: { required: true },
            travelers: { required: true, min: 1, max: 20 },
            budget: { required: true }
        };
        this.init();
    }

    init() {
        this.form.addEventListener('submit', this.handleSubmit.bind(this));
        
        // Real-time validation
        Object.keys(this.fields).forEach(fieldName => {
            const field = document.getElementById(fieldName);
            if (field) {
                field.addEventListener('blur', () => this.validateField(fieldName));
                field.addEventListener('input', () => this.clearError(fieldName));
            }
        });

        // Set minimum date to today for travel date fields
        const today = new Date().toISOString().split('T')[0];
        const departureDateField = document.getElementById('departureDate');
        const returnDateField = document.getElementById('returnDate');
        if (departureDateField) departureDateField.setAttribute('min', today);
        if (returnDateField) returnDateField.setAttribute('min', today);

        // Add event listener for date validation
        if (departureDateField && returnDateField) {
            departureDateField.addEventListener('change', () => {
                this.validateTravelDates();
            });

            returnDateField.addEventListener('change', () => {
                this.validateTravelDates();
            });
        }

        // Log API configuration
        console.log('Form initialized with API:', this.apiUrl);
    }

    validateTravelDates() {
        const departureDate = document.getElementById('departureDate').value;
        const returnDate = document.getElementById('returnDate').value;
        
        if (departureDate && returnDate) {
            if (new Date(returnDate) < new Date(departureDate)) {
                this.showFieldError('travelDates', 'Return date must be after departure date.');
                return false;
            }
        }
        this.clearError('travelDates');
        return true;
    }

    validateField(fieldName) {
        const field = document.getElementById(fieldName);
        const fieldConfig = this.fields[fieldName];
        const value = field.value.trim();
        
        let isValid = true;
        let errorMessage = '';

        if (fieldConfig.required && (!value || (field.type === 'checkbox' && !field.checked))) {
            isValid = false;
            errorMessage = `$${this.getFieldLabel(fieldName)} is required.`;
        }

        if (isValid && value && fieldConfig.pattern && !fieldConfig.pattern.test(value)) {
            isValid = false;
            errorMessage = this.getPatternErrorMessage(fieldName);
        }

        if (isValid && value && fieldConfig.minLength && value.length < fieldConfig.minLength) {
            isValid = false;
            errorMessage = `$${this.getFieldLabel(fieldName)} must be at least $${fieldConfig.minLength} characters.`;
        }

        if (isValid && value && fieldConfig.min !== undefined) {
            const numValue = parseInt(value);
            if (numValue < fieldConfig.min) {
                isValid = false;
                errorMessage = `$${this.getFieldLabel(fieldName)} must be at least $${fieldConfig.min}.`;
            }
        }

        if (isValid && value && fieldConfig.max !== undefined) {
            const numValue = parseInt(value);
            if (numValue > fieldConfig.max) {
                isValid = false;
                errorMessage = `$${this.getFieldLabel(fieldName)} must be no more than $${fieldConfig.max}.`;
            }
        }

        this.showFieldError(fieldName, isValid ? '' : errorMessage);
        return isValid;
    }

    validateAllFields() {
        let isFormValid = true;
        Object.keys(this.fields).forEach(fieldName => {
            if (!this.validateField(fieldName)) {
                isFormValid = false;
            }
        });

        if (!this.validateTravelDates()) {
            isFormValid = false;
        }

        return isFormValid;
    }

    showFieldError(fieldName, message) {
        const field = document.getElementById(fieldName);
        const errorElement = document.getElementById(`$${fieldName}Error`);
        
        if (message) {
            if (field) field.classList.add('error');
            if (errorElement) {
                errorElement.textContent = message;
                errorElement.classList.add('show');
            }
        } else {
            if (field) field.classList.remove('error');
            if (errorElement) {
                errorElement.textContent = '';
                errorElement.classList.remove('show');
            }
        }
    }

    clearError(fieldName) {
        const field = document.getElementById(fieldName);
        const errorElement = document.getElementById(`$${fieldName}Error`);
        
        if (field && field.classList.contains('error')) {
            setTimeout(() => this.validateField(fieldName), 300);
        }
    }

    getFieldLabel(fieldName) {
        const labels = {
            firstName: 'First Name',
            lastName: 'Last Name',
            email: 'Email Address',
            phone: 'Phone Number',
            destination: 'Destination',
            travelType: 'Travel Type',
            travelers: 'Number of Travelers',
            budget: 'Budget Range'
        };
        return labels[fieldName] || fieldName;
    }

    getPatternErrorMessage(fieldName) {
        const messages = {
            email: 'Please enter a valid email address.',
            phone: 'Please enter a valid phone number.'
        };
        return messages[fieldName] || 'Invalid format.';
    }

    async handleSubmit(e) {
        e.preventDefault();
        
        if (!this.validateAllFields()) {
            this.showSubmitError('Please correct the errors above.');
            return;
        }

        this.showLoading(true);
        
        try {
            await this.submitForm();
            this.showSuccess();
        } catch (error) {
            console.error('Form submission error:', error);
            this.showSubmitError(error.message || 'Something went wrong. Please try again.');
        } finally {
            this.showLoading(false);
        }
    }

    async submitForm() {
        // Collect form data
        const formData = {
            name: `$${document.getElementById('firstName').value.trim()} $${document.getElementById('lastName').value.trim()}`,
            email: document.getElementById('email').value.trim(),
            phone: document.getElementById('phone').value.trim() || null,
            destination: document.getElementById('destination').value.trim() || null,
            travelDateStart: document.getElementById('departureDate')?.value || null,
            travelDateEnd: document.getElementById('returnDate')?.value || null,
            travelers: document.getElementById('travelers')?.value || null,
            message: this.buildMessage()
        };

        console.log('Submitting to API:', this.apiUrl);
        console.log('Form data:', formData);

        const response = await fetch(this.apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(formData)
        });

        console.log('Response status:', response.status);

        const result = await response.json();
        console.log('Response data:', result);

        if (!response.ok) {
            const errorMessage = result.message || result.errors?.join(', ') || 'Failed to submit form';
            throw new Error(errorMessage);
        }

        return result;
    }

    buildMessage() {
        const travelType = document.getElementById('travelType')?.value || 'Not specified';
        const budget = document.getElementById('budget')?.value || 'Not specified';
        const specialRequests = document.getElementById('specialRequests')?.value || 'None';

        return `
Travel Type: $${travelType}
Budget Range: $${budget}

Special Requests:
$${specialRequests}
        `.trim();
    }

    showLoading(show) {
        const submitBtn = document.getElementById('submitBtn');
        const spinner = document.getElementById('loadingSpinner');
        const submitText = document.getElementById('submitText');
        
        if (show) {
            submitBtn.disabled = true;
            if (spinner) spinner.style.display = 'inline-block';
            if (submitText) submitText.textContent = 'Planning Your Journey...';
        } else {
            submitBtn.disabled = false;
            if (spinner) spinner.style.display = 'none';
            if (submitText) submitText.textContent = 'Plan My Journey';
        }
    }

    showSuccess() {
        const successMessage = document.getElementById('successMessage');
        if (successMessage) {
            successMessage.style.display = 'block';
        } else {
            const successDiv = document.createElement('div');
            successDiv.id = 'successMessage';
            successDiv.style.cssText = `
                background: #d4edda;
                color: #155724;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
                border: 1px solid #c3e6cb;
                text-align: center;
            `;
            successDiv.innerHTML = `
                <h3>✅ Thank You!</h3>
                <p>Your travel inquiry has been submitted successfully. We'll get back to you within 24 hours!</p>
            `;
            this.form.parentNode.insertBefore(successDiv, this.form);
        }
        
        this.form.style.display = 'none';
        
        if (successMessage) {
            successMessage.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    showSubmitError(message) {
        const existingErrors = document.querySelectorAll('.submit-error-message');
        existingErrors.forEach(el => el.remove());

        const errorDiv = document.createElement('div');
        errorDiv.className = 'submit-error-message';
        errorDiv.style.cssText = `
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
            border: 1px solid #f5c6cb;
            text-align: center;
        `;
        errorDiv.textContent = message;
        
        const submitBtn = document.getElementById('submitBtn');
        submitBtn.parentNode.insertBefore(errorDiv, submitBtn.nextSibling);
        
        errorDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        
        setTimeout(() => {
            errorDiv.remove();
        }, 7000);
    }
}

// Initialize the form validator when the page loads
// API URL is automatically injected by Terraform during deployment
document.addEventListener('DOMContentLoaded', () => {
    const API_URL = '${api_gateway_url}/submit';
    console.log('✅ Form initialized with API URL:', API_URL);
    new TravelFormValidator('travelForm', API_URL);
});