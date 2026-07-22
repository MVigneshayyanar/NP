"""
JWT Authentication backend for Django REST Framework.
Verifies JWTs using the shared secret (same key Go gateway uses).
"""
import jwt
from django.conf import settings
from rest_framework import authentication, exceptions
from core.models import User


class JWTAuthentication(authentication.BaseAuthentication):
    """
    Custom JWT authentication.
    Expects: Authorization: Bearer <token>
    """
    keyword = 'Bearer'

    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION', '')

        if not auth_header.startswith(f'{self.keyword} '):
            return None

        token = auth_header[len(self.keyword) + 1:]

        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET,
                algorithms=[settings.JWT_ALGORITHM],
            )
        except jwt.ExpiredSignatureError:
            raise exceptions.AuthenticationFailed('Token has expired.')
        except jwt.InvalidTokenError:
            raise exceptions.AuthenticationFailed('Invalid token.')

        user_id = payload.get('user_id')
        if not user_id:
            raise exceptions.AuthenticationFailed('Token payload missing user_id.')

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            raise exceptions.AuthenticationFailed('User not found.')

        if not user.is_active:
            raise exceptions.AuthenticationFailed('User account is disabled.')

        return (user, token)

    def authenticate_header(self, request):
        return self.keyword
