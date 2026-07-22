"""
URL routing for Sensory AI internal API.
All paths are prefixed with /internal/ (from root urls.py).
"""
from django.urls import path
from . import views

urlpatterns = [
    # ── Auth ──
    path('auth/register/', views.RegisterView.as_view(), name='register'),
    path('auth/login/', views.LoginView.as_view(), name='login'),
    path('auth/me/', views.MeView.as_view(), name='me'),
    path('auth/user/<uuid:pk>/', views.UserUpdateView.as_view(), name='user-update'),

    # ── Sensory Profile ──
    path('profile/<uuid:user_id>/', views.SensoryProfileDetailView.as_view(), name='sensory-profile'),

    # ── Environment Scans ──
    path('scans/', views.EnvironmentScanListCreateView.as_view(), name='scan-list-create'),
    path('scans/<uuid:pk>/', views.EnvironmentScanDetailView.as_view(), name='scan-detail'),

    # ── Recommendations ──
    path('recommendations/', views.RecommendationListCreateView.as_view(), name='recommendation-list-create'),
    path('recommendations/<uuid:pk>/', views.RecommendationUpdateView.as_view(), name='recommendation-update'),

    # ── Progress ──
    path('progress/<uuid:user_id>/', views.ProgressView.as_view(), name='progress'),
]
