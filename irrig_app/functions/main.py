# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import functions_framework
from flask import jsonify, Request
import firebase_admin
from firebase_admin import auth, credentials, db
import requests
from flask import make_response
import openmeteo_requests
import pandas as pd
import requests_cache
from retry_requests import retry
import time

cred = credentials.Certificate("scmu-6f1b8-firebase-adminsdk-fbsvc-bc6b3767d5.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://scmu-6f1b8-default-rtdb.europe-west1.firebasedatabase.app/'
})


def generate_token(request: Request):
    request_json = request.get_json(silent=True)
    request_args = request.args

    uid = None
    if request_json and 'uid' in request_json:
        uid = request_json['uid']
    elif request_args and 'uid' in request_args:
        uid = request_args['uid']

    if not uid:
        return jsonify({"error": "Missing 'uid' in request"}), 400

    try:
        # Generate token for the provided UID
        custom_token = auth.create_custom_token(uid)
        return jsonify({
            "token": custom_token.decode('utf-8')
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@functions_framework.http
def assign_crop_admin(request):
    # Marks user as a crop admin.
    if request.method != 'POST':
        return jsonify({"error": "Only POST allowed"}), 405

    data = request.get_json(silent=True) or {}
    uid = data.get("uid")
    if not uid:
        return jsonify({"error": "Missing 'uid' in request body"}), 400

    try:
        auth.set_custom_user_claims(uid, {"cropAdmin": True})
        return jsonify({"message": f"User {uid} is now a crop admin."}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@functions_framework.http
def make_meteo_request(request):
    request_json = request.get_json(silent=True)
    if not request_json or "address" not in request_json:
        return make_response("Missing 'address' parameter", 400)
    address = request_json["address"]

    # Query Nominatim
    geocode_url = "https://nominatim.openstreetmap.org/search"
    geocode_params = {
        "q": address,
        "format": "json",
        "limit": 1
    }
    headers = {
        "User-Agent": "Irrigo APP"
    }

    try:
        time.sleep(1)
        geocode_response = requests.get(geocode_url, params=geocode_params, headers=headers)
        geocode_response.raise_for_status()
        location = geocode_response.json()
        if not location:
            return make_response("Address not found", 404)
        lat = float(location[0]["lat"])
        lon = float(location[0]["lon"])
    except requests.exceptions.RequestException as e:
        return make_response(f"Geocoding error: {str(e)}", 500)

    # Query Open-Meteo API https://open-meteo.com/en/docs?hourly=precipitation,precipitation_probability&forecast_days=1
    cache_session = requests_cache.CachedSession('.cache', expire_after=3600)
    retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
    openmeteo = openmeteo_requests.Client(session=retry_session)

    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lon,
        "daily": "precipitation_probability_max",
        "forecast_days": 1
    }

    try:
        responses = openmeteo.weather_api(url, params=params)
        response = responses[0]

        daily = response.Daily()
        daily_precipitation_probability_max = daily.Variables(0).ValuesAsNumpy()

        daily_data = {"date": pd.date_range(
            start = pd.to_datetime(daily.Time(), unit = "s", utc = True),
            end = pd.to_datetime(daily.TimeEnd(), unit = "s", utc = True),
            freq = pd.Timedelta(seconds = daily.Interval()),
            inclusive = "left"
        )}

        daily_data["precipitation_probability_max"] = daily_precipitation_probability_max

        daily_dataframe = pd.DataFrame(data = daily_data)
        print(daily_dataframe)

        return make_response(daily_dataframe.to_json(orient="records"), 200)

    except Exception as e:
        return make_response(f"Weather API error: {str(e)}", 500)


def list_filtered_users(request):
    filtered_users = []
    excluded_domain = "@irrigo.com"
    page_token = None

    auth_header = request.headers.get('Authorization')

    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({'error': 'Missing or malformed Authorization header'}), 401

    id_token = auth_header.split("Bearer ")[1]

    try:
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token['uid']
        print(f"Authenticated UID: {uid}")
    except Exception as e:
        return jsonify({'error': f'Invalid token: {str(e)}'}), 403

    try:
        while True:
            result = auth.list_users(page_token=page_token)

            for user in result.users:
                email = user.email or ""
                display_name = user.display_name or ""
                claims = user.custom_claims or {}

                if email.endswith(excluded_domain):
                    continue

                if claims.get("cropAdmin") is True:
                    continue

                crops_ref = db.reference(f'users/{user.uid}/crops')
                crops_snapshot = crops_ref.get()
                if crops_snapshot is None:
                    crops_list = []
                else:
                    if isinstance(crops_snapshot, dict):
                        crops_list = list(crops_snapshot.values())

                    elif isinstance(crops_snapshot, list):
                        crops_list = crops_snapshot
                    else:
                        crops_list = []

                filtered_users.append({
                    "uid": user.uid,
                    "email": email,
                    "displayName": display_name,
                    "crops": crops_list,
                })

            if not result.next_page_token:
                break
            page_token = result.next_page_token

        return jsonify({"users": filtered_users}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


