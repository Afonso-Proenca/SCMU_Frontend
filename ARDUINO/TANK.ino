#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <FirebaseClient.h>
#include "arduino_secrets.h"

FirebaseApp app;
UserAuth user_auth(WEB_API_KEY, ESP_MAIL, ESP_PASS);
WiFiClientSecure ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);
RealtimeDatabase Database;

const int greenLed = 14;
const int yellowLed = 27;
const int redLed = 26;

const int echoPin = 13;
const int trigPin = 12;
const int pumpPin = 25;

const int WATER_TANK_CAPACITY_HIGH = 3;
const int WATER_TANK_CAPACITY_MEDIUM = 8;
const int WATER_TANK_CAPACITY_LOW = 12;

float history[15] = {0};
int nElems = 0;
float duration, distance;

unsigned long lastSendTime = 0;
const unsigned long sendInterval = 10000;

void processData(AsyncResult &aResult) {
  if (!aResult.isResult()) return;
  if (aResult.isEvent()) Serial.printf("Event: %s\n", aResult.eventLog().message().c_str());
  if (aResult.isError()) Serial.printf("Error: %s\n", aResult.error().message().c_str());
  if (aResult.available()) Serial.printf("Data: %s\n", aResult.c_str());
}

void setupWiFiAndFirebase() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED && (millis() - startTime < 10000)) {
    Serial.print(".");
    delay(500);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi connected: " + WiFi.localIP().toString());
    ssl_client.setInsecure();
    initializeApp(aClient, app, getAuth(user_auth), processData, "auth");
    app.getApp<RealtimeDatabase>(Database);
    Database.url(DATABASE_URL);
  } else {
    Serial.println("\nWi-Fi failed.");
  }
}

void setup() {
  Serial.begin(9600);
  pinMode(greenLed, OUTPUT);
  pinMode(yellowLed, OUTPUT);
  pinMode(redLed, OUTPUT);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  pinMode(pumpPin, OUTPUT);
  digitalWrite(pumpPin, HIGH);
  setupWiFiAndFirebase();
}

void loop() {
  loopSonar();
  duration = pulseIn(echoPin, HIGH);
  distance = (duration * .0343) / 2;
  if (distance > 1000) distance = 0;
  updateHistory(distance);

  app.loop();

  unsigned long now = millis();

  Database.get<bool>(aClient, "/status/pump", processData, "checkPump", [](AsyncResult &aResult) {
        if (aResult.available()) {
          bool isPumping = aResult.to<bool>();
          if (isPumping) {
            Serial.println("Activating pump for 5 seconds...");

            digitalWrite(pumpPin, LOW);
            delay(5000);
            digitalWrite(pumpPin, HIGH);

            Database.set<bool>(aClient, "/status/pump", false, processData, "resetPump");
          }
        }
      });

  delay(4000);
}

void loopSonar() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
}

void setLedPin(int pinOn) {
  int pins[] = {greenLed, yellowLed, redLed};
  for (int i = 0; i < 3; i++) {
    digitalWrite(pins[i], (pins[i] == pinOn) ? HIGH : LOW);
  }
}

void updateHistory(int distance) {
  history[nElems++] = distance;
  if (nElems == 15) {
    float mean = calculateMean(history, 15);
    Serial.print("Water Level: ");
    Serial.println(mean);

    if (mean < WATER_TANK_CAPACITY_MEDIUM) {
      setLedPin(greenLed);
    } else if (mean < WATER_TANK_CAPACITY_LOW) {
      setLedPin(yellowLed);
    } else {
      setLedPin(redLed);
    }

    nElems = 0;
    memset(history, 0, sizeof(history));
  }
}

int calculateMean(float array[], int size) {
  float sum = 0;
  for (int i = 0; i < size; ++i) sum += array[i];
  return sum / size;
}
