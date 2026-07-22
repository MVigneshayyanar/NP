"""
DRF Serializers for Sensory AI internal API.
"""
from rest_framework import serializers
from django.contrib.auth import authenticate
from core.models import User, SensoryProfile, EnvironmentScan, Recommendation


# ── Auth Serializers ──

class RegisterSerializer(serializers.ModelSerializer):
    """User registration serializer."""
    username = serializers.CharField(required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, required=False)


    class Meta:
        model = User
        fields = ['email', 'username', 'password', 'password_confirm']

    def validate(self, data):
        if 'password_confirm' in data and data['password'] != data['password_confirm']:
            raise serializers.ValidationError({'password_confirm': 'Passwords do not match.'})
        
        email = data.get('email', '').strip().lower()
        data['email'] = email
        
        # If user with email exists, append unique suffix or let login handle it
        if not data.get('username'):
            email_prefix = email.split('@')[0]
            data['username'] = f"{email_prefix}_{User.objects.count() + 1}"
            
        return data



    def create(self, validated_data):
        validated_data.pop('password_confirm', None)
        username = validated_data.get('username') or validated_data.get('email', '').split('@')[0]
        base_username = username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}_{counter}"
            counter += 1

        user = User.objects.create_user(
            username=username,
            email=validated_data['email'],
            password=validated_data['password'],
        )
        SensoryProfile.objects.get_or_create(user=user)
        return user




class LoginSerializer(serializers.Serializer):
    """Login serializer — accepts email or username."""
    email = serializers.EmailField(required=False)
    username = serializers.CharField(required=False)
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        email = data.get('email')
        username = data.get('username')
        password = data.get('password')

        if not email and not username:
            raise serializers.ValidationError('Email or username is required.')

        # Look up user by email if provided
        if email:
            try:
                user_obj = User.objects.get(email=email)
                username = user_obj.username
            except User.DoesNotExist:
                raise serializers.ValidationError('Invalid credentials.')

        user = authenticate(username=username, password=password)
        if not user:
            raise serializers.ValidationError('Invalid credentials.')

        if not user.is_active:
            raise serializers.ValidationError('User account is disabled.')

        data['user'] = user
        return data


class UserSerializer(serializers.ModelSerializer):
    """Full user serializer for profile display."""

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'full_name', 'age',
            'country', 'occupation', 'profile_picture',
            'living_situation', 'property_status', 'tier',
            'onboarding_completed', 'notifications_enabled',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class UserUpdateSerializer(serializers.ModelSerializer):
    """User profile update serializer (onboarding step 1)."""
    full_name = serializers.CharField(required=False, allow_blank=True)
    age = serializers.IntegerField(required=False, allow_null=True)
    country = serializers.CharField(required=False, allow_blank=True)
    occupation = serializers.CharField(required=False, allow_blank=True)
    living_situation = serializers.CharField(required=False, allow_blank=True)
    property_status = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = [
            'full_name', 'age', 'country', 'occupation',
            'profile_picture', 'living_situation', 'property_status',
            'notifications_enabled', 'onboarding_completed',
        ]

    def validate_living_situation(self, value):
        if not value or value not in ['apartment', 'house', 'shared_home']:
            return 'apartment'
        return value

    def validate_property_status(self, value):
        if not value or value not in ['home_owner', 'renter']:
            return 'home_owner'
        return value


# ── Sensory Profile Serializers ──

class SensoryProfileSerializer(serializers.ModelSerializer):
    """Sensory Profile CRUD serializer."""
    goals = serializers.JSONField(required=False)
    daily_routine_start = serializers.TimeField(required=False, allow_null=True)
    daily_routine_end = serializers.TimeField(required=False, allow_null=True)
    bedtime = serializers.TimeField(required=False, allow_null=True)

    class Meta:
        model = SensoryProfile
        fields = [
            'id', 'user', 'light_sensitivity', 'sound_sensitivity',
            'texture_sensitivity', 'color_sensitivity', 'goals',
            'daily_routine_start', 'daily_routine_end',
            'bedtime', 'sleep_duration_hours',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']



# ── Environment Scan Serializers ──

class RecommendationSerializer(serializers.ModelSerializer):
    """Recommendation serializer."""

    class Meta:
        model = Recommendation
        fields = [
            'id', 'scan', 'user', 'category', 'priority',
            'title', 'action_text', 'is_applied', 'is_dismissed',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class RecommendationCreateSerializer(serializers.ModelSerializer):
    """Serializer for bulk-creating recommendations from Go gateway."""

    class Meta:
        model = Recommendation
        fields = [
            'scan', 'user', 'category', 'priority',
            'title', 'action_text',
        ]


class EnvironmentScanSerializer(serializers.ModelSerializer):
    """Environment Scan serializer with nested recommendations."""
    recommendations = RecommendationSerializer(many=True, read_only=True)

    class Meta:
        model = EnvironmentScan
        fields = [
            'id', 'user', 'image_ref', 'audio_ref', 'llm_output',
            'environment_score', 'focus_score', 'sleep_score', 'mood_score',
            'color_matches', 'room_name', 'created_at', 'recommendations',
        ]
        read_only_fields = ['id', 'created_at']


class EnvironmentScanCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating scans from Go gateway."""

    class Meta:
        model = EnvironmentScan
        fields = [
            'user', 'image_ref', 'audio_ref', 'llm_output',
            'environment_score', 'focus_score', 'sleep_score', 'mood_score',
            'color_matches', 'room_name',
        ]


# ── Progress Serializer ──

class ProgressSerializer(serializers.Serializer):
    """Aggregated progress data for the Progress screen."""
    environment_score = serializers.IntegerField()
    focus_score = serializers.IntegerField()
    sleep_score = serializers.IntegerField()
    mood_score = serializers.IntegerField()
    environment_delta = serializers.FloatField()
    focus_delta = serializers.FloatField()
    sleep_delta = serializers.FloatField()
    mood_delta = serializers.FloatField()
    weekly_scores = serializers.ListField(child=serializers.DictField())
    total_scans = serializers.IntegerField()
    current_streak = serializers.IntegerField()
    rooms_scanned = serializers.IntegerField()
