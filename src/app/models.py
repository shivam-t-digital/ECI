from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import ForeignKey, DateTime, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

db = SQLAlchemy()

class Question(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_text = db.Column(db.String(255), nullable=False)
    answers = db.relationship('Answer', backref='question', uselist=False)
    is_active = db.Column(db.Boolean, nullable=False, default=True)

class Answer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    answer_text = db.Column(db.String(255), nullable=False)
    question_id = db.Column(db.Integer, db.ForeignKey('question.id'), nullable=False)
    correct_explanation = db.relationship('CorrectExplanation', backref='answer', uselist=False)
    correct = db.Column(db.Boolean, default=False) 

class CorrectExplanation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    explanation_text = db.Column(db.String(255), nullable=False)
    answer_id = db.Column(db.Integer, db.ForeignKey('answer.id'), nullable=False)

class UserGeographicDetails(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_ip = db.Column(db.String(45), nullable=False)
    device_data_json = db.Column(db.Text, nullable=False)
    user_geo_details = db.Column(db.Text, nullable=True)

class UserDetails(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    email = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)

class UserProgress(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    question_id = db.Column(db.Integer, db.ForeignKey('question.id'), nullable=False)
    answer_id = db.Column(db.Integer, db.ForeignKey('answer.id'), nullable=False)
    is_correct = db.Column(db.Boolean, default=False)

    # Define relationship with Question and Answer models
    question = db.relationship('Question', backref='user_progress')
    answer = db.relationship('Answer', backref='user_progress')


