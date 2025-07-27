from flask import Flask, jsonify, send_file
import cv2
import requests
from ultralytics import YOLO
import threading
import time
from datetime import datetime
import os
import numpy as np

app = Flask(__name__)

# Configuration
WEBCAM_URL = "http://192.168.xxx.xxx:8080/video"  # Your IP-Webcam URL
MODEL_PATH = "D:/xxxxxxxxx/xxxxxxxxxxxx/best.pt"  # Path to your YOLOv8 model
FALL_DURATION_THRESHOLD = 3  # 3 seconds for testing

# Global variables
current_status = "NO_FALL"
fall_start_time = None
fall_screenshot_path = None
fall_timestamp = None
model = None

def initialize_model():
    """Load the YOLOv8 model"""
    global model
    try:
        model = YOLO(MODEL_PATH)
        print("✅ YOLOv8 model loaded successfully!")
        return True
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return False

def detect_fall_in_frame(frame):
    """
    Run YOLOv8 detection on frame
    Returns True if fall detected, False otherwise
    """
    global model
    
    try:
        results = model(frame)
        
        # Debug: Print all detected classes
        detected_classes = []
        
        # Check detections
        for result in results:
            for box in result.boxes:
                # Get class ID and name from model
                class_id = int(box.cls[0])
                confidence = float(box.conf[0])
                
                # Get actual class name from model
                class_name = model.names[class_id]
                
                detected_classes.append(f"{class_name}({confidence:.2f})")
                
                # Check if fall detected with good confidence
                if class_id == 0 and confidence > 0.3:  # class_id 0 = fall
                    print(f"🚨 FALL DETECTED: Class {class_id} ({class_name}) with confidence {confidence:.2f}")
                    return True
        
        # Print detected classes for debugging
        if detected_classes:
            print(f"🔍 Detected: {', '.join(detected_classes)}")
        else:
            print("👁️ No objects detected")
        
        return False
    except Exception as e:
        print(f"❌ Error in detection: {e}")
        return False

def save_fall_screenshot(frame):
    """Save screenshot when fall confirmed"""
    global fall_screenshot_path, fall_timestamp
    
    try:
        # Set the specific directory path
        screenshot_dir = "C:/Users/xxxx/Desktop/FLASK"
        
        # Generate filename with timestamp
        timestamp = datetime.now()
        filename = f"fall_{timestamp.strftime('%Y%m%d_%H%M%S')}.jpg"
        filepath = os.path.join(screenshot_dir, filename)
        
        # Save the frame
        cv2.imwrite(filepath, frame)
        
        fall_screenshot_path = filepath
        fall_timestamp = timestamp.strftime('%Y-%m-%d %H:%M:%S')
        
        print(f"📸 Fall screenshot saved: {filepath}")
        return True
        
    except Exception as e:
        print(f"❌ Error saving screenshot: {e}")
        return False

def camera_monitoring_thread():
    """Main thread for camera monitoring"""
    global current_status, fall_start_time, fall_screenshot_path, fall_timestamp
    
    print("🎥 Starting camera monitoring...")
    
    # Use OpenCV to capture from IP camera
    cap = cv2.VideoCapture(WEBCAM_URL)
    
    if not cap.isOpened():
        print(f"❌ Failed to open camera stream: {WEBCAM_URL}")
        current_status = "CAMERA_ERROR"
        return
    
    print("✅ Camera stream opened successfully!")
    
    while True:
        try:
            # Read frame from camera
            ret, frame = cap.read()
            
            if ret and frame is not None:
                print("📷 Frame captured successfully")
                
                # Detect fall in current frame
                fall_detected = detect_fall_in_frame(frame)
                
                if fall_detected:
                    if fall_start_time is None:
                        # First time detecting fall
                        fall_start_time = time.time()
                        current_status = "FALL_DETECTED_MONITORING"
                        print("⚠️ Fall detected! Starting timer...")
                    
                    else:
                        # Check if fall duration exceeded threshold
                        elapsed_time = time.time() - fall_start_time
                        print(f"⏱️ Fall duration: {elapsed_time:.1f}s / {FALL_DURATION_THRESHOLD}s")
                        
                        if elapsed_time >= FALL_DURATION_THRESHOLD:
                            if current_status != "FALL_CONFIRMED":
                                # Confirmed fall - save screenshot
                                save_fall_screenshot(frame)
                                current_status = "FALL_CONFIRMED"
                                print("🚨 FALL CONFIRMED! Screenshot saved.")
                
                else:
                    # No fall detected - reset
                    if fall_start_time is not None:
                        print("✅ Person recovered. Resetting timer.")
                    
                    fall_start_time = None
                    if current_status != "FALL_CONFIRMED":
                        current_status = "NO_FALL"
            
            else:
                print("❌ Failed to read frame from camera")
                current_status = "CAMERA_ERROR"
        
        except Exception as e:
            print(f"❌ Camera monitoring error: {e}")
            current_status = "CAMERA_ERROR"
        
        # Wait before next frame
        time.sleep(2)  # Check every 2 seconds
    
    cap.release()

# Flask API Endpoints

@app.route('/fall_status')
def get_fall_status():
    """Return current fall detection status"""
    return jsonify({
        "status": current_status,
        "timestamp": fall_timestamp,
        "has_screenshot": fall_screenshot_path is not None
    })

@app.route('/fall_screenshot')
def get_fall_screenshot():
    """Return the fall screenshot image"""
    global fall_screenshot_path
    
    if fall_screenshot_path and os.path.exists(fall_screenshot_path):
        return send_file(fall_screenshot_path, mimetype='image/jpeg')
    else:
        return jsonify({"error": "No screenshot available"}), 404

@app.route('/reset_fall')
def reset_fall():
    """Reset fall detection (for testing purposes)"""
    global current_status, fall_start_time, fall_screenshot_path, fall_timestamp
    
    current_status = "NO_FALL"
    fall_start_time = None
    fall_screenshot_path = None
    fall_timestamp = None
    
    return jsonify({"message": "Fall detection reset"})

@app.route('/status')
def server_status():
    """Check if server is running"""
    return jsonify({
        "server": "running",
        "model_loaded": model is not None,
        "webcam_url": WEBCAM_URL
    })

if __name__ == '__main__':
    print("🚀 Starting Fall Detection Server...")
    
    # Initialize model
    if not initialize_model():
        print("❌ Failed to load model. Exiting...")
        exit(1)
    
    # Start camera monitoring in background thread
    camera_thread = threading.Thread(target=camera_monitoring_thread, daemon=True)
    camera_thread.start()
    
    # Start Flask server
    # give your own device (Laptop/PC) network IP 
    print("🌐 Starting Flask server on http://192.168.xxxx.xxxx:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)