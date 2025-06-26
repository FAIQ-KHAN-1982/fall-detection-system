# fall-detection-system
A smart fall detection system using YOLOv8, IP camera, and ESP8266+MPU6050 to send alerts via a Flutter app.
# Fall Detection System using YOLOv8 + Flutter App

## 📱 Description
This system connects an IP camera to a mobile app. The YOLOv8 model runs on a local server to detect human falls. If a person falls and doesn't get up for a minute, the app sends an alert to the caretaker's phone. Also, ESP8266 + MPU6050 combined will act as a backup 

> "Camera detects falls, app sends alerts to caretaker’s phone."

## ⚙️ Technologies Used
- YOLOv8 (Ultralytics)
- Python (Flask for backend)
- Flutter (for the mobile app)
- ESP8266 + MPU6050 (hardware sensor)

## 📂 Project Structure
- `model/` – YOLOv8 trained models on RTX 4060 8GB and training results
- `dataset/` – Sample dataset used for training
- `yolov8_inference/` – Scripts to test the model
- `flask_server/` – Backend server code
- `esp8266_mpu6050/` – Arduino code for hardware sensor
- `flutter_app/` – Flutter mobile app


## 👨‍💻 Authors
- Muhammad Faiq (Final Year Project 2025)
- Hashir Ahmad Khan
- Umar Bin Muslim
