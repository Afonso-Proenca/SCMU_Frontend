import firebase_admin
from firebase_admin import auth, credentials

cred = credentials.Certificate("scmu-6f1b8-firebase-adminsdk-fbsvc-bc6b3767d5.json")
firebase_admin.initialize_app(cred)

uid = ""
auth.set_custom_user_claims(uid, {"cropAdmin": True})
print(f"{uid} is now a crop admin")
