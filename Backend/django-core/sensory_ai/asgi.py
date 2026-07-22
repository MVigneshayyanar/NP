"""
ASGI config for Sensory AI project.
"""
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sensory_ai.settings')
application = get_asgi_application()
