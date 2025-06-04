#include <Arduino.h>
#include <WiFiS3.h>
#include <WiFiSSLClient.h>
#include <FirebaseClient.h>
#include "arduino_secrets.h"

// ──────────────────────────────────────────────────────────────────────────
// 1) Your credentials go in arduino_secrets.h, for example:
//
//    #define WIFI_SSID       "your-ssid"
//    #define WIFI_PASSWORD   "your-pass"
//    #define WEB_API_KEY     "AIza…"
//    #define ESP_MAIL        "youremail@example.com"
//    #define ESP_PASS        "yourEmaillPassword"
//    #define DATABASE_URL    "your-project.firebaseio.com"
// ──────────────────────────────────────────────────────────────────────────

// These globals and flags must be declared before processData():
bool   gotMinHum = false;
float  minHumVal = 0.0;

bool   gotMaxHum = false;
float  maxHumVal = 0.0;

bool   gotMeteo  = false;
bool   meteoVal  = false;

FirebaseApp       app;
UserAuth         user_auth(WEB_API_KEY, ESP_MAIL, ESP_PASS);
WiFiSSLClient    ssl_client;
using AsyncClient = AsyncClientClass;  // from WiFiS3
AsyncClient      aClient(ssl_client);
RealtimeDatabase Database;

// ──────────────────────────────────────────────────────────────────────────
// Callback for all asynchronous Firebase events. Whenever a “get” or “set”
// finishes, aResult.available()==true. We inspect aResult.c_str() to convert
// it to float/bool, and we look at aResult.eventLog().message() to know which
// path just returned.
// ──────────────────────────────────────────────────────────────────────────
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
    String tag = aResult.eventLog().message();
    const char* payload = aResult.c_str();  // raw string from Firebase

    // Convert the payload string to float or bool as needed:
    if (tag == "min_hum") {
      // Example payload might be "42.5" or "30"
      minHumVal = atof(payload);
      gotMinHum = true;
    }
    else if (tag == "max_hum") {
      maxHumVal = atof(payload);
      gotMaxHum = true;
    }
    else if (tag == "meteo") {
      // Payload might be "true" or "false"
      if (strcmp(payload, "true") == 0) meteoVal = true;
      else                                     meteoVal = false;
      gotMeteo = true;
    }
    // If you have other tags to watch for, add more else‐ifs here
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 2) Pin & threshold definitions
// ──────────────────────────────────────────────────────────────────────────
const int tempPin   = A0;
const int lightPin  = A1;
const int humidPin  = A5;
const int buzzerPin = 2;

const float MAX_TEMP  = 30.0;
const float MIN_TEMP  = 0.0;
const float MAX_LIGHT = 100.0;
const float MIN_LIGHT = 0.0;

float  MAX_HUMID = 80.0;
float  MIN_HUMID = 0.0;

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

unsigned long lastSendTime    = 0;
const unsigned long sendInterval = 10000;  // every 10 seconds


float updateTempHistory(float reading);
float updateLightHistory(float reading);
float updateHumidityHistory(float reading);
float computeMean(float array[], int size);

void fetchHumidityThresholds();
void sendSensorData();
void setupWiFiAndFirebase();

void setup() {
  Serial.begin(9600);
  pinMode(buzzerPin, OUTPUT);
  noTone(buzzerPin);

  setupWiFiAndFirebase();
  // Fetch the initial humidity thresholds from Firebase
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

  // Initialize Firebase with our processData callback
  initializeApp(aClient, app, getAuth(user_auth), processData, "auth");
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);
  Serial.println("Firebase initialized");
}

void fetchHumidityThresholds() {
  // Build the two database paths based on “type”
  String minPath = "/crops/" + type + "/min_humidity";
  String maxPath = "/crops/" + type + "/max_humidity";

  // ─────── Fetch MIN_HUMID ───────
  gotMinHum = false;
  Database.get(aClient, minPath.c_str(), processData, "min_hum");
  // Wait until processData() sets gotMinHum = true
  while (!gotMinHum) {
    app.loop();
  }
  MIN_HUMID = minHumVal;
  Serial.print("MIN_HUMID = ");
  Serial.println(MIN_HUMID);

  // ─────── Fetch MAX_HUMID ───────
  gotMaxHum = false;
  Database.get(aClient, maxPath.c_str(), processData, "max_hum");
  while (!gotMaxHum) {
    app.loop();
  }
  MAX_HUMID = maxHumVal;
  Serial.print("MAX_HUMID = ");
  Serial.println(MAX_HUMID);
}

void loop() {
  // Keep Firebase’s background tasks running
  app.loop();

  unsigned long now = millis();
  if (now - lastSendTime > sendInterval) {
    lastSendTime = now;
    sendSensorData();
  }
}

void sendSensorData() {
  // ─────── 1) Read and convert temperature ───────
  float adcTemp     = analogRead(tempPin);
  float voltageT    = adcTemp * (5.0 / 1023.0);
  float temperature = voltageT / 0.01;  // assumes 10 mV/°C sensor

  float meanT = updateTempHistory(temperature);
  if (meanT > 0) {
    currentMeanT = meanT;
    if (app.ready()) {
      Database.set<float>(
        aClient,
        "/sensors/temperature",
        currentMeanT,
        processData,
        "temperature"
      );
      Serial.print("Firebase → temperature: ");
      Serial.println(currentMeanT);
    }
  }

  // ─────── 2) Read raw light value, compute mean ───────
  float lightRaw = analogRead(lightPin);
  float meanL    = updateLightHistory(lightRaw);
  if (meanL > 0) {
    currentMeanL = meanL;
    if (app.ready()) {
      Database.set<float>(
        aClient,
        "/sensors/light",
        currentMeanL,
        processData,
        "light"
      );
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
      Database.set<float>(
        aClient,
        "/sensors/humidity",
        currentMeanH,
        processData,
        "humidity"
      );
      Serial.print("Firebase → humidity: ");
      Serial.println(currentMeanH);
    }
  }

  if (currentMeanL > MAX_LIGHT && currentMeanT > MAX_TEMP) {
    if (currentMeanH < MIN_HUMID) {
      tone(buzzerPin, 7000);
      Database.set<bool>(aClient, "/status/pump", true, processData, "TurnOnPump");
    }
  } else {
    gotMeteo = false;
    Database.get(aClient, "/meteo", processData, "meteo");
    while (!gotMeteo) {
      app.loop();
    }
    Serial.print("METEOROLOGY PREDICTION = ");
    Serial.println(meteoVal);

    if (meteoVal == false) {
      Database.set<bool>(aClient, "/status/pump", true, processData, "TurnOnPump");
    }
  }

  delay(4000);
  noTone(buzzerPin);
}

// ──────────────────────────────────────────────────────────────────────────
// Rolling‐window helpers (compute average every 15 samples)
// ──────────────────────────────────────────────────────────────────────────
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
