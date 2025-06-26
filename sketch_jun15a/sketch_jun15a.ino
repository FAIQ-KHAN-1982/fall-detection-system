#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <Wire.h>
#include <MPU6050.h>

const char* ssid = "Realme 6";
const char* password = "123456789";

ESP8266WebServer server(80);
MPU6050 mpu;
bool fallDetected = false;

void setup() {
  Serial.begin(115200);
  delay(1000);  // Allow time for serial monitor to connect
  Serial.println("Starting...");

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");

  int retryCount = 0;
  while (WiFi.status() != WL_CONNECTED && retryCount < 20) {
    delay(500);
    Serial.print(".");
    retryCount++;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n❌ Failed to connect to WiFi. Check SSID/Password or signal strength.");
    return;
  }

  Serial.println("\n✅ WiFi connected");
  Serial.print("📶 IP Address: ");
  Serial.println(WiFi.localIP());

  Wire.begin();
  mpu.initialize();

  if (!mpu.testConnection()) {
    Serial.println("❌ MPU6050 connection failed!");
    while (1);
  }

  Serial.println("✅ MPU6050 connected");

  server.on("/fall_status", HTTP_GET, []() {
    int16_t ax, ay, az;
    mpu.getAcceleration(&ax, &ay, &az);
    Serial.print("Z-axis: ");
    Serial.println(az);

    fallDetected = (az > 0);  // simplistic fall detection

    server.send(200, "text/plain", fallDetected ? "FALL DETECTED" : "NO FALL");
  });

  server.begin();
  Serial.println("🌐 Web server started");
}

void loop() {
  server.handleClient();
}
