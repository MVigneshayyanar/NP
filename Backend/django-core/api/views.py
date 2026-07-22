"""
DRF Views for Sensory AI internal API.
These endpoints are called by the Go Fiber gateway, not directly by the mobile app.
"""
import jwt
from datetime import datetime, timedelta
from django.conf import settings
from django.utils import timezone
from django.db.models import Avg, Count
from django.db.models.functions import TruncDate
from rest_framework import generics, status, permissions, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import User, SensoryProfile, EnvironmentScan, Recommendation
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer, UserUpdateSerializer,
    SensoryProfileSerializer, EnvironmentScanSerializer, EnvironmentScanCreateSerializer,
    RecommendationSerializer, RecommendationCreateSerializer, ProgressSerializer,
)


def generate_jwt(user):
    """Generate a JWT token for the given user."""
    payload = {
        'user_id': str(user.id),
        'username': user.username,
        'email': user.email,
        'exp': datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRATION_HOURS),
        'iat': datetime.utcnow(),
    }
    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    return token


# ── Auth Views ──

class RegisterView(generics.CreateAPIView):
    """POST /internal/auth/register/ — Create user + issue JWT."""
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token = generate_jwt(user)
        return Response({
            'token': token,
            'user': UserSerializer(user).data,
        }, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    """POST /internal/auth/login/ — Authenticate + issue JWT."""
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        token = generate_jwt(user)
        return Response({
            'token': token,
            'user': UserSerializer(user).data,
        })


class MeView(APIView):
    """GET /internal/auth/me/ — Current user from JWT."""

    def get(self, request):
        return Response(UserSerializer(request.user).data)


class UserUpdateView(generics.UpdateAPIView):
    """PUT/PATCH /internal/auth/user/{user_id}/ — Update user profile."""
    serializer_class = UserUpdateSerializer
    queryset = User.objects.all()
    lookup_field = 'pk'


# ── Sensory Profile Views ──

class SensoryProfileDetailView(generics.RetrieveUpdateAPIView):
    """
    GET /internal/profile/{user_id}/ — Fetch sensory profile by user ID.
    PUT/PATCH — Update sensory profile.
    """
    serializer_class = SensoryProfileSerializer

    def get_object(self):
        user_id = self.kwargs.get('user_id')
        profile, _ = SensoryProfile.objects.get_or_create(user_id=user_id)
        return profile



# ── Environment Scan Views ──

class EnvironmentScanListCreateView(generics.ListCreateAPIView):
    """
    GET /internal/scans/?user_id=X — List scans for a user.
    POST /internal/scans/ — Create a new scan record (called by Go gateway after LLM processing).
    """

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return EnvironmentScanCreateSerializer
        return EnvironmentScanSerializer

    def get_queryset(self):
        queryset = EnvironmentScan.objects.prefetch_related('recommendations')
        user_id = self.request.query_params.get('user_id')
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        scan = serializer.save()
        # Return the full scan with nested recommendations
        return Response(
            EnvironmentScanSerializer(scan).data,
            status=status.HTTP_201_CREATED,
        )


class EnvironmentScanDetailView(generics.RetrieveAPIView):
    """GET /internal/scans/{scan_id}/ — Retrieve a single scan."""
    serializer_class = EnvironmentScanSerializer
    queryset = EnvironmentScan.objects.prefetch_related('recommendations')
    lookup_field = 'pk'


# ── Recommendation Views ──

class RecommendationListCreateView(generics.ListCreateAPIView):
    """
    GET /internal/recommendations/?scan_id=X — List recommendations by scan.
    POST /internal/recommendations/ — Create recommendations (supports bulk via list).
    """

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return RecommendationCreateSerializer
        return RecommendationSerializer

    def get_queryset(self):
        queryset = Recommendation.objects.all()
        scan_id = self.request.query_params.get('scan_id')
        user_id = self.request.query_params.get('user_id')
        if scan_id:
            queryset = queryset.filter(scan_id=scan_id)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        return queryset

    def create(self, request, *args, **kwargs):
        # Support bulk creation (list of recommendations)
        many = isinstance(request.data, list)
        serializer = self.get_serializer(data=request.data, many=many)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class RecommendationUpdateView(generics.UpdateAPIView):
    """PATCH /internal/recommendations/{pk}/ — Update applied/dismissed status."""
    serializer_class = RecommendationSerializer
    queryset = Recommendation.objects.all()
    lookup_field = 'pk'


# ── Progress View ──

class ProgressView(APIView):
    """
    GET /internal/progress/{user_id}/ — Aggregated progress data.
    Returns current scores, deltas vs. last week, weekly chart data, and stats.
    """

    def get(self, request, user_id):
        now = timezone.now()
        week_ago = now - timedelta(days=7)
        two_weeks_ago = now - timedelta(days=14)

        # Current week scans
        current_scans = EnvironmentScan.objects.filter(
            user_id=user_id,
            created_at__gte=week_ago,
        )

        # Previous week scans (for delta calculation)
        previous_scans = EnvironmentScan.objects.filter(
            user_id=user_id,
            created_at__gte=two_weeks_ago,
            created_at__lt=week_ago,
        )

        # Calculate current averages
        current_avg = current_scans.aggregate(
            env=Avg('environment_score'),
            focus=Avg('focus_score'),
            sleep=Avg('sleep_score'),
            mood=Avg('mood_score'),
        )

        # Calculate previous averages for deltas
        prev_avg = previous_scans.aggregate(
            env=Avg('environment_score'),
            focus=Avg('focus_score'),
            sleep=Avg('sleep_score'),
            mood=Avg('mood_score'),
        )

        def safe_avg(val, default=0):
            return round(val) if val is not None else default

        def calc_delta(current, previous):
            if current is None or previous is None:
                return 0.0
            return round(current - previous, 1)

        # Latest scan for current scores (fallback to averages)
        latest_scan = EnvironmentScan.objects.filter(user_id=user_id).first()

        env_score = latest_scan.environment_score if latest_scan else safe_avg(current_avg['env'])
        focus_score = latest_scan.focus_score if latest_scan else safe_avg(current_avg['focus'])
        sleep_score = latest_scan.sleep_score if latest_scan else safe_avg(current_avg['sleep'])
        mood_score = latest_scan.mood_score if latest_scan else safe_avg(current_avg['mood'])

        # Weekly scores (daily averages for chart)
        weekly_data = (
            EnvironmentScan.objects.filter(
                user_id=user_id,
                created_at__gte=week_ago,
            )
            .annotate(date=TruncDate('created_at'))
            .values('date')
            .annotate(
                environment=Avg('environment_score'),
                focus=Avg('focus_score'),
                sleep=Avg('sleep_score'),
                mood=Avg('mood_score'),
            )
            .order_by('date')
        )

        weekly_scores = [
            {
                'date': entry['date'].isoformat(),
                'environment': round(entry['environment'] or 0),
                'focus': round(entry['focus'] or 0),
                'sleep': round(entry['sleep'] or 0),
                'mood': round(entry['mood'] or 0),
            }
            for entry in weekly_data
        ]

        # Stats
        all_scans = EnvironmentScan.objects.filter(user_id=user_id)
        total_scans = all_scans.count()
        rooms_scanned = all_scans.values('room_name').distinct().count()

        # Calculate streak (consecutive days with scans)
        scan_dates = (
            all_scans
            .annotate(date=TruncDate('created_at'))
            .values_list('date', flat=True)
            .distinct()
            .order_by('-date')
        )

        current_streak = 0
        expected_date = now.date()
        for scan_date in scan_dates:
            if scan_date == expected_date:
                current_streak += 1
                expected_date -= timedelta(days=1)
            elif scan_date < expected_date:
                break

        data = {
            'environment_score': env_score,
            'focus_score': focus_score,
            'sleep_score': sleep_score,
            'mood_score': mood_score,
            'environment_delta': calc_delta(current_avg['env'], prev_avg['env']),
            'focus_delta': calc_delta(current_avg['focus'], prev_avg['focus']),
            'sleep_delta': calc_delta(current_avg['sleep'], prev_avg['sleep']),
            'mood_delta': calc_delta(current_avg['mood'], prev_avg['mood']),
            'weekly_scores': weekly_scores,
            'total_scans': total_scans,
            'current_streak': current_streak,
            'rooms_scanned': rooms_scanned,
        }

        serializer = ProgressSerializer(data)
        return Response(serializer.data)
