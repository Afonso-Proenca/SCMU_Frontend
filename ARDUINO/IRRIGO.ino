#include <Arduino.h>
#include <WiFiS3.h>
#include <WiFiSSLClient.h>
#include <FirebaseClient.h>
#include "arduino_secrets.h"

FirebaseApp app;
UserAuth    user_auth(WEB_API_KEY, ESP_MAIL, ESP_PASS);
WiFiSSLClient ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);
RealtimeDatabase Database;

void processData(AsyncResult &aResult) {
  if (aResult.isEvent()) {
    Serial.print("Event: ");
    Serial.println(aResult.eventLog().message());
  }
  if (aResult.isError()) {
    Serial.print("Error: ");
    Serial.println(aResult.error().message());
  }
  if (aResult.available()) {
    Serial.print("Data: ");
    Serial.println(aResult.c_str());
  }
}

const int tempPin   = A0;
const int lightPin  = A1;
const int humidPin  = A5;
const int buzzerPin = 2;

const float MAX_TEMP  = 30.0;
const float MIN_TEMP  = 0.0;
const float MAX_LIGHT = 100.0;
const float MIN_LIGHT = 0.0;
float MAX_HUMID = 80.0;
float MIN_HUMID = 0.0;

String type = "corn";

float tempHistory[15]  = {0};
float lightHistory[15] = {0};
float humidHistory[15] = {0};

int nElemsT = 0;
int nElemsL = 0;
int nElemsH = 0;

float currentMeanT = -1;
float currentMeanL = -1;
float currentMeanH = -1;

unsigned long lastSendTime = 0;
const unsigned long sendInterval = 10000;

float  updateTempHistory(float reading);
float  updateLightHistory(float reading);
float  updateHumidityHistory(float reading);
float  computeMean(float array[], int size);
void   sendSensorData();
void   setupWiFiAndFirebase();

void setup() {
  Serial.begin(9600);

  pinMode(buzzerPin, OUTPUT);
  noTone(buzzerPin);

  setupWiFiAndFirebase();
  fetchHumidityThresholds();
}

void setupWiFiAndFirebase() {
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.print("Wi-Fi connected, IP = ");
  Serial.println(WiFi.localIP());
  initializeApp(aClient, app, getAuth(user_auth), processData, "auth");
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);
  Serial.println("Firebase initialized");
}

void fetchHumidityThresholds() {
  String minPath = "/crops/" + type + "/min_humidity";
  String maxPath = "/crops/" + type + "/max_humidity";

  Database.get(aClient, minPath.c_str(), processData, "min_hum");
  while (!aClient.ready()) app.loop();
  if (aClient.available()) {
    MIN_HUMID = aClient.to<float>();
    Serial.print("MIN_HUMID = "); Serial.println(MIN_HUMID);
  }

  Database.get(aClient, maxPath.c_str(), processData, "max_hum");
  while (!aClient.ready()) app.loop();
  if (aClient.available()) {
    MAX_HUMID = aClient.to<float>();
    Serial.print("MAX_HUMID = "); Serial.println(MAX_HUMID);
  }
}

void loop() {
  fetchHumidityThresholds();
  app.loop();

  unsigned long now = millis();
  if (now - lastSendTime > sendInterval) {
    lastSendTime = now;
    sendSensorData();
  }
}

void sendSensorData() {
  float adcTemp    = analogRead(tempPin);
  float voltageT   = adcTemp * (5.0 / 1023.0);
  float temperature = voltageT / 0.01;

  float meanT = updateTempHistory(temperature);
  if (meanT > 0) {
    currentMeanT = meanT;
    if (app.ready()) {
      Database.set<float>(aClient, "/sensors/temperature", currentMeanT, processData, "temperature");
      Serial.print("Firebase → temperature: ");
      Serial.println(currentMeanT);
    }
  }

  float lightRaw = analogRead(lightPin);
  float meanL    = updateLightHistory(lightRaw);
  if (meanL > 0) {
    currentMeanL = meanL;
    if (app.ready()) {
      Database.set<float>(aClient, "/sensors/light", currentMeanL, processData, "light");
      Serial.print("Firebase → light: ");
      Serial.println(currentMeanL);
    }
  }

  int rawHumid = analogRead(humidPin);
  Serial.print("Raw humidity (ADC): ");
  Serial.println(rawHumid);

  int humidityPercent = map(rawHumid, 1023, 0, 0, 100);
  float meanH = updateHumidityHistory(humidityPercent);
  if (meanH > 0) {
    currentMeanH = meanH;
    if (app.ready()) {
      Database.set<float>(aClient, "/sensors/humidity", currentMeanH, processData, "humidity");
      Serial.print("Firebase → humidity: ");
      Serial.println(currentMeanH);
    }
  }

  if (currentMeanL > MAX_LIGHT && currentMeanT > MAX_TEMP) {
    if(currentMeanH < MIN_HUMID)
      tone(buzzerPin, 7000);
      Database.set<bool>(aClient, "/status/pump", true, processData, "TurnOnPump");
  } else {
      Database.get(aClient, "/meteo", processData, "meteo");
      while (!aClient.ready()) app.loop();
      bool meteo = false;
      if (aClient.available()) {
        meteo = aClient.to<bool>();
        Serial.print("METEOROLOGY PREDICTION = "); Serial.println(meteo);
      }

      if (meteo == false){
        Database.set<bool>(aClient, "/status/pump", true, processData, "TurnOnPump");
      }
  }
  delay(4000);
  noTone(buzzerPin);
}

float updateTempHistory(float reading) {
  tempHistory[nElemsT++] = reading;
  Serial.print("Temperature Debug: ");
  Serial.println(reading);

  if (nElemsT == 15) {
    float m = computeMean(tempHistory, 15);
    Serial.print("Computed avg. Temperature: ");
    Serial.print(m);
    Serial.println(" °C");
    nElemsT = 0;
    memset(tempHistory, 0, sizeof(tempHistory));
    return m;
  }
  return -1;
}

float updateLightHistory(float reading) {
  lightHistory[nElemsL++] = reading;
  Serial.print("Light Debug: ");
  Serial.println(reading);

  if (nElemsL == 15) {
    float m = computeMean(lightHistory, 15);
    Serial.print("Computed avg. Light: ");
    Serial.println(m);
    nElemsL = 0;
    memset(lightHistory, 0, sizeof(lightHistory));
    return m;
  }
  return -1;
}

float updateHumidityHistory(float reading) {
  humidHistory[nElemsH++] = reading;
  Serial.print("Humid Debug: ");
  Serial.println(reading);

  if (nElemsH == 15) {
    float m = computeMean(humidHistory, 15);
    Serial.print("Computed avg. Humidity: ");
    Serial.println(m);
    nElemsH = 0;
    memset(humidHistory, 0, sizeof(humidHistory));
    return m;
  }
  return -1;
}

float computeMean(float array[], int size) {
  float sum = 0;
  for (int i = 0; i < size; i++) {
    sum += array[i];
  }
  return sum / size;
}
