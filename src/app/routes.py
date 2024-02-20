from flask_sqlalchemy import SQLAlchemy
from flask import Blueprint, request, jsonify, Response, stream_with_context
from .models import db, Question, Answer, CorrectExplanation, UserGeographicDetails, UserDetails
import json
import requests
users_bp = Blueprint('users', __name__)



@users_bp.route('/ip_details/<ip_address>', methods=['GET'])
def get_ip_details(ip_address):
    try:
        # Make a request to the BigDataCloud API to get IP details
        response = requests.get(f'https://api.bigdatacloud.net/data/reverse-geocode-client?ip={ip_address}')

        # Check if the request was successful
        if response.status_code == 200:
            # Extract IP details from the response
            ip_details = response.json()
            print("API Response:", ip_details)  # Print API response for troubleshooting

            # Set a default value for device_data_json
            device_data_json = json.dumps(ip_details.get('device_data_json', {}))

            # Save IP details to the database
            geo_details = UserGeographicDetails(user_ip=ip_address, device_data_json=device_data_json, user_geo_details=json.dumps(ip_details))
            db.session.add(geo_details)
            db.session.commit()

            # Return IP details as JSON response
            return jsonify({
                'message': 'IP details saved successfully',
                'ip_details': ip_details
            }), 200
        else:
            # Return an error message if the request failed
            return jsonify({
                'error': 'Failed to fetch IP details from the third-party API'
            }), 500
    except Exception as e:
        # Log the exception
        print(f"An error occurred: {e}")

        # Return an error message
        return jsonify({
            'error': 'An unexpected error occurred while processing the request'
        }), 500
    

@users_bp.route('/user_details', methods=['POST'])
def save_user_details():
    # Get data from request JSON
    data = request.json

    # Extract user details
    name = data.get('name')
    age = data.get('age')
    email = data.get('email')
    phone_number = data.get('phone_number')

    # Save user details to database
    user_details = UserDetails(name=name, age=age, email=email, phone_number=phone_number)
    db.session.add(user_details)
    db.session.commit()

    # Return saved data as JSON response
    return jsonify({
        'message': 'User details saved successfully',
        'data': data
    }), 200


@users_bp.route('/geo_details', methods=['POST'])
def save_geo_details():
    # Get data from request JSON
    data = request.json

    # Extract user IP and device data
    user_ip = data.get('user_ip')
    device_data = data.get('device_data')

    # Save IP and device details to database
    geo_details = UserGeographicDetails(user_ip=user_ip, device_data_json=json.dumps(device_data))
    db.session.add(geo_details)
    db.session.commit()

    # Return saved data as JSON response
    return jsonify({
        'message': 'User geographic details saved successfully',
        'data': data
    }), 200