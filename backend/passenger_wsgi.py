from a2wsgi import ASGIMiddleware

from app.main import app

# cPanel Passenger expects a WSGI callable named "application".
application = ASGIMiddleware(app)
