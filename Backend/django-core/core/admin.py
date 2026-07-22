"""
Django Admin configuration for Sensory AI core models.
"""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, SensoryProfile, EnvironmentScan, Recommendation


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    """Extended User admin with Sensory AI fields."""
    list_display = [
        'username', 'email', 'full_name', 'tier',
        'living_situation', 'property_status',
        'onboarding_completed', 'created_at',
    ]
    list_filter = [
        'tier', 'living_situation', 'property_status',
        'onboarding_completed', 'is_active',
    ]
    search_fields = ['username', 'email', 'full_name']
    ordering = ['-created_at']

    fieldsets = BaseUserAdmin.fieldsets + (
        ('Sensory AI Profile', {
            'fields': (
                'tier', 'full_name', 'age', 'country', 'occupation',
                'profile_picture', 'living_situation', 'property_status',
                'onboarding_completed', 'notifications_enabled',
            ),
        }),
        ('Stripe Connect', {
            'fields': ('stripe_connect_account_id', 'stripe_connect_onboarded'),
            'classes': ('collapse',),
        }),
    )


class RecommendationInline(admin.TabularInline):
    model = Recommendation
    extra = 0
    readonly_fields = ['id', 'category', 'priority', 'title', 'action_text', 'created_at']
    fields = ['category', 'priority', 'title', 'is_applied', 'is_dismissed']


@admin.register(EnvironmentScan)
class EnvironmentScanAdmin(admin.ModelAdmin):
    """Environment Scan admin with inline recommendations."""
    list_display = [
        'id', 'user', 'environment_score', 'focus_score',
        'sleep_score', 'mood_score', 'room_name', 'created_at',
    ]
    list_filter = ['created_at']
    search_fields = ['user__username', 'user__email', 'room_name']
    readonly_fields = ['id', 'llm_output', 'color_matches', 'created_at']
    ordering = ['-created_at']
    inlines = [RecommendationInline]

    fieldsets = (
        ('Scan Info', {
            'fields': ('id', 'user', 'room_name', 'image_ref', 'audio_ref', 'created_at'),
        }),
        ('Scores', {
            'fields': ('environment_score', 'focus_score', 'sleep_score', 'mood_score'),
        }),
        ('AI Output', {
            'fields': ('llm_output', 'color_matches'),
            'classes': ('collapse',),
        }),
    )


@admin.register(SensoryProfile)
class SensoryProfileAdmin(admin.ModelAdmin):
    """Sensory Profile admin."""
    list_display = [
        'user', 'light_sensitivity', 'sound_sensitivity',
        'texture_sensitivity', 'color_sensitivity', 'updated_at',
    ]
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Recommendation)
class RecommendationAdmin(admin.ModelAdmin):
    """Recommendation admin."""
    list_display = [
        'title', 'category', 'priority', 'user',
        'is_applied', 'is_dismissed', 'created_at',
    ]
    list_filter = ['category', 'priority', 'is_applied', 'is_dismissed']
    search_fields = ['title', 'action_text', 'user__username']
    ordering = ['-created_at']
