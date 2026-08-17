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

    # ── Dashboard ──
    path('dashboard/stats/', views.DashboardStatsView.as_view(), name='dashboard-stats'),
    path('dashboard/offices/', views.DashboardOfficesView.as_view(), name='dashboard-offices'),
    path('dashboard/analyses/', views.DashboardAnalysesView.as_view(), name='dashboard-analyses'),
    path('dashboard/chart/', views.DashboardChartView.as_view(), name='dashboard-chart'),
    path('dashboard/users/', views.DashboardUsersView.as_view(), name='dashboard-users'),
    path('dashboard/sensory-distribution/', views.DashboardSensoryDistributionView.as_view(), name='dashboard-sensory-distribution'),
    path('dashboard/analytics/', views.DashboardAnalyticsChartView.as_view(), name='dashboard-analytics'),
    path('dashboard/heatmap/', views.DashboardHeatmapView.as_view(), name='dashboard-heatmap'),
    path('dashboard/analysis/', views.DashboardAnalysisView.as_view(), name='dashboard-analysis'),
    path('dashboard/conflicts/', views.DashboardConflictsView.as_view(), name='dashboard-conflicts'),
    path('dashboard/procurement/', views.DashboardProcurementView.as_view(), name='dashboard-procurement'),
    path('dashboard/reports/', views.DashboardReportsView.as_view(), name='dashboard-reports'),
    path('dashboard/settings/', views.DashboardSettingsView.as_view(), name='dashboard-settings'),
    path('dashboard/header/', views.DashboardHeaderView.as_view(), name='dashboard-header'),
    path('dashboard/floor-plans/', views.DashboardFloorPlanView.as_view(), name='dashboard-floor-plans'),
    path('dashboard/users-meta/', views.DashboardUsersMetaView.as_view(), name='dashboard-users-meta'),
]
