from flask_sqlalchemy import SQLAlchemy
from flask import Blueprint, request, jsonify, Response, stream_with_context
from .models import db, Question, Answer, CorrectExplanation, UserGeographicDetails, UserDetails
import json
import requests
import base64

users_bp = Blueprint('users', __name__)


@users_bp.route('/user_details', methods=['POST'])
def save_user_details():
    # Get data from request JSON
    data = request.json
    print('Received data:', data)
    # Extract user details
    user_ip = data.get('user_ip')
    name = data.get('name')
    email = data.get('email')
    phn_no = data.get('phn_no')
    address = data.get('address')
    dob = data.get('dob')
    image_base64 = data.get('image')
        
    # Ensure proper padding for base64 string
    padded_base64 = image_base64 + '=' * (-len(image_base64) % 4)
        
    # Decode base64-encoded image data to bytes
    image_bytes = base64.b64decode(padded_base64)


    # Check if the user already exists in the database
    existing_user = UserDetails.query.filter_by(email=email).first()
    if existing_user:
        # If the user exists, increment the cert field by 1
        existing_user.cert += 1
        db.session.commit()
    else:
        # If the user does not exist, save user details to database
        user_details = UserDetails(user_ip=user_ip, name=name, email=email, phn_no = phn_no, address=address, dob=dob, image=image_bytes, cert=1)
        db.session.add(user_details)
        db.session.commit()
        print('User details stored in database:', user_details)

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
    print("Received user IP:", user_ip)
    print("Received device data:", device_data)

    # Get IP details using third-party API
    ip_details=get_ip_details(user_ip)
    print('ip_details:', ip_details)

    # Save IP and device details to database
    geo_details = UserGeographicDetails(user_ip=user_ip, device_data_json=json.dumps(device_data),user_geo_details= ip_details)
    db.session.add(geo_details)
    db.session.commit()

    # Return saved data as JSON response
    return jsonify({
        'message': 'User geographic details saved successfully',
        'data': data
    }), 200



def get_ip_details(ip_address):
    try:
        # Make a request to the BigDataCloud API to get IP details
        response = requests.get(f'https://api.bigdatacloud.net/data/reverse-geocode-client?ip={ip_address}')

        # Check if the request was successful
        if response.status_code == 200:
            # Extract IP details from the response
            ip_details = response.json()
            print("API Response:", ip_details)  # Print API response for troubleshooting

            return json.dumps(ip_details)
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
    

@users_bp.route('/quiz_data', methods=['GET'])
def get_quiz_data():
    section = request.args.get('section')
    print('Received request for section:', section)

    # Validate section
    if section not in ['A', 'B', 'C']:
        return jsonify({'error': 'Invalid section'})

    quiz_data = []

    # Query the database to get questions for the specified section
    questions = Question.query.filter_by(section=section).all()
    print('Found questions:', questions)

    for idx, question in enumerate(questions, start=1):
        data = {
            'question': question.question_text,
            'options': {},
            'correct': None
        }
        # Fetch all answers for the current question
        answers = Answer.query.filter_by(question_id=question.id).all()
        if not answers:  # Check if there are no answers for the question
            continue

        # Map answers to letters based on the section
        start_ascii = 0
        if section == 'A':
            start_ascii = 97  # ASCII value for 'a'
        elif section == 'B':
            start_ascii = 101  # ASCII value for 'e'
        elif section == 'C':
            start_ascii = 105  # ASCII value for 'i'

        for i, answer in enumerate(answers, start=start_ascii):
            data['options'][chr(i)] = answer.answer_text
            if answer.correct:
                data['correct'] = chr(i)

        quiz_data.append(data)

    print('Returning quiz data:', quiz_data)
    return jsonify(quiz_data)
