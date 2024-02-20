from decouple import config

# # For local
class Config:
  SQLALCHEMY_DATABASE_URI = config("DB_CONN_STRING")
# SQLALCHEMY_DATABASE_URI = 'mysql://root:root@localhost:3306/eci'
  SQLALCHEMY_TRACK_MODIFICATIONS = False 
