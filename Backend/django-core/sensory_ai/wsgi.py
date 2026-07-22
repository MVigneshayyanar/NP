"""
WSGI config for Sensory AI project.
"""
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sensory_ai.settings')
application = get_wsgi_application()
