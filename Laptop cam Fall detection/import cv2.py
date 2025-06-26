import cv2
from ultralytics import YOLO

# Load your trained model according to your file location
model = YOLO("C:/Users/xxxx/xxxx/xxxx/best.pt")

# Define custom colors for each class (BGR format)
class_colors = {
    'nofall': (0, 255, 0),       # Green
    'fall': (0, 0, 255),         # Red
    'sitting': (255, 255, 0)     # Light Blue
}

# Open webcam (you can change resolution here)
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 960)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 540)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Run YOLOv8 prediction
    results = model(frame)[0]

    for box in results.boxes:
        cls_id = int(box.cls[0])
        conf = float(box.conf[0])
        label = model.names[cls_id]
        color = class_colors.get(label, (255, 255, 255))  # Default white if class not found

        # Draw bounding box
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)

        # Put label and confidence
        cv2.putText(frame, f'{label} {conf:.2f}', (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

    # Show the result
    cv2.imshow("YOLOv8 - Custom Colors", frame)

    # Press 'q' to quit
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
