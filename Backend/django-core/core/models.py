"""
Core models for Sensory AI.

Models:
- User: Extended Django user with tier, living situation, property status
- SensoryProfile: Per-user sensory sensitivity assessment + goals
- EnvironmentScan: Room scan record with AI-generated scores
- Recommendation: Generated tip from a scan, trackable by user
"""
import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator


class User(AbstractUser):
    """
    Extended user model for Sensory AI.
    Keeps the field for future corporate expansion (tier).
    """

    class Tier(models.TextChoices):
        RESIDENTIAL = 'residential', 'Residential'
        CORPORATE = 'corporate', 'Corporate'

    class LivingSituation(models.TextChoices):
        APARTMENT = 'apartment', 'Apartment'
        HOUSE = 'house', 'House'
        SHARED_HOME = 'shared_home', 'Shared Home'

    class PropertyStatus(models.TextChoices):
        HOME_OWNER = 'home_owner', 'Home Owner'
        RENTER = 'renter', 'Renter'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tier = models.CharField(
        max_length=20,
        choices=Tier.choices,
        default=Tier.RESIDENTIAL,
    )
    profile_picture = models.ImageField(
        upload_to='profile_pictures/',
        blank=True,
        null=True,
    )
    full_name = models.CharField(max_length=255, blank=True)
    age = models.PositiveIntegerField(blank=True, null=True)
    country = models.CharField(max_length=100, blank=True)
    occupation = models.CharField(max_length=200, blank=True)
    living_situation = models.CharField(
        max_length=20,
        choices=LivingSituation.choices,
        blank=True,
    )
    property_status = models.CharField(
        max_length=20,
        choices=PropertyStatus.choices,
        blank=True,
    )
    onboarding_completed = models.BooleanField(default=False)
    notifications_enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Stripe Connect
    stripe_connect_account_id = models.CharField(max_length=255, blank=True)
    stripe_connect_onboarded = models.BooleanField(default=False)

    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return f"{self.full_name or self.username} ({self.email})"


class SensoryProfile(models.Model):
    """
    Per-user sensory sensitivity assessment.
    Each sensitivity is a 0-100 slider value (low = low sensitivity, high = high sensitivity).
    Goals are stored as a JSON list of strings.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='sensory_profile',
    )

    # Sensory sensitivities (0-100)
    light_sensitivity = models.IntegerField(
        default=50,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Light & Brightness sensitivity (0=low, 100=high)',
    )
    sound_sensitivity = models.IntegerField(
        default=50,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Sound sensitivity (0=low, 100=high)',
    )
    texture_sensitivity = models.IntegerField(
        default=50,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Touch & Texture sensitivity (0=low, 100=high)',
    )
    color_sensitivity = models.IntegerField(
        default=50,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text='Color sensitivity (0=low, 100=high)',
    )

    # Goals — stored as JSON list, e.g. ["better_sleep", "improve_focus"]
    goals = models.JSONField(
        default=list,
        blank=True,
        help_text='List of goal identifiers',
    )

    # Daily routine
    daily_routine_start = models.TimeField(
        blank=True,
        null=True,
        help_text='When the user typically starts their day',
    )
    daily_routine_end = models.TimeField(
        blank=True,
        null=True,
        help_text='When the user typically ends their day',
    )

    # Sleep schedule
    bedtime = models.TimeField(blank=True, null=True)
    sleep_duration_hours = models.FloatField(
        blank=True,
        null=True,
        validators=[MinValueValidator(0), MaxValueValidator(24)],
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sensory_profiles'
        verbose_name = 'Sensory Profile'
        verbose_name_plural = 'Sensory Profiles'

    def __str__(self):
        return f"SensoryProfile for {self.user}"


class EnvironmentScan(models.Model):
    """
    A single room scan record.
    Stores the image/audio references, raw LLM output, and computed scores.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='scans',
    )

    # Media references (stored as file paths or URLs)
    image_ref = models.CharField(
        max_length=500,
        help_text='Path or URL to the room image',
    )
    audio_ref = models.CharField(
        max_length=500,
        blank=True,
        help_text='Path or URL to the ambient audio clip',
    )

    # Raw LLM output — the full JSON response from the AI
    llm_output = models.JSONField(
        default=dict,
        help_text='Full structured JSON response from the multimodal LLM',
    )

    # Computed scores (0-100)
    environment_score = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    focus_score = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    sleep_score = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )
    mood_score = models.IntegerField(
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
    )

    # Color matching results (from paint DB lookup)
    color_matches = models.JSONField(
        default=list,
        blank=True,
        help_text='List of matched paint colors with codes and LRV values',
    )

    # Room metadata
    room_name = models.CharField(max_length=100, blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'environment_scans'
        verbose_name = 'Environment Scan'
        verbose_name_plural = 'Environment Scans'
        ordering = ['-created_at']

    def __str__(self):
        return f"Scan {self.id} — {self.user} — {self.environment_score}%"


class Recommendation(models.Model):
    """
    A generated recommendation/tip from an environment scan.
    """

    class Category(models.TextChoices):
        LIGHTING = 'lighting', 'Lighting'
        NOISE = 'noise', 'Noise'
        TEXTURE = 'texture', 'Texture'
        LAYOUT = 'layout', 'Layout'

    class Priority(models.TextChoices):
        HIGH = 'high', 'High'
        MEDIUM = 'medium', 'Medium'
        LOW = 'low', 'Low'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    scan = models.ForeignKey(
        EnvironmentScan,
        on_delete=models.CASCADE,
        related_name='recommendations',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='recommendations',
    )

    category = models.CharField(
        max_length=20,
        choices=Category.choices,
    )
    priority = models.CharField(
        max_length=10,
        choices=Priority.choices,
        default=Priority.MEDIUM,
    )
    title = models.CharField(max_length=200)
    action_text = models.TextField(help_text='The actionable recommendation text')

    # User interaction tracking
    is_applied = models.BooleanField(default=False)
    is_dismissed = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'recommendations'
        verbose_name = 'Recommendation'
        verbose_name_plural = 'Recommendations'
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.priority}] {self.title} ({self.category})"
