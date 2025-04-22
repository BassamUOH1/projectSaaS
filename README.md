# Task Manager Pro 🚀

A cross-platform task management app built with **Flutter**, **AWS Lambda (Go)**, and **DynamoDB**.  

## Features ✨  
- 📝 Create tasks with titles, descriptions, and due dates.  
- ✅ Mark tasks as completed/incomplete.  
- 🗑️ Delete tasks with confirmation.  
- 🔄 Real-time sync with DynamoDB.  
- 📱 Responsive UI with multilingual support (Arabic/English).  

## Architecture 🛠️  
-Flutter frontend
-Go backend

## Tech Stack  
- **Frontend:** Flutter (Dart)  
- **Backend:** AWS Lambda (Go)  
- **Database:** Amazon DynamoDB  

## Setup Guide 📋  

### Prerequisites  
- Flutter SDK (v3.0+)  
- AWS Account with Lambda and DynamoDB access  
- Go (v1.20+)  

### Deployment Steps  
1. **Deploy Lambda Function:**  
   - Compile and deploy the Go code (`main.go`) to AWS Lambda.  
   - Ensure IAM roles have DynamoDB read/write permissions.  

2. **Configure Flutter App:**  
   - Update the Lambda URL in `APIdatabase.dart`:  
     ```dart
     Uri.parse('YOUR_LAMBDA_URL_HERE')
     ```  

3. **Run Flutter App:**  
   ```bash
   flutter pub get
   flutter run
