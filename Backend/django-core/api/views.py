"""
DRF Views for Sensory AI internal API.
These endpoints are called by the Go Fiber gateway, not directly by the mobile app.
"""
import jwt
from datetime import datetime, timedelta
from django.conf import settings
from django.utils import timezone
from django.db.models import Avg, Count
from django.db.models.functions import TruncDate, TruncMonth
from rest_framework import generics, status, permissions, viewsets
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import User, SensoryProfile, EnvironmentScan, Recommendation, WorkspaceSettings
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
    permission_classes = [permissions.AllowAny]

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


# ── Dashboard Views ──

class DashboardStatsView(APIView):
    """GET /internal/dashboard/stats/ — Corporate dashboard stats."""
    permission_classes = [permissions.AllowAny]
    
    def get(self, request):
        from core.models import Office, Department, User
        total_offices = Office.objects.count()
        total_departments = Department.objects.count()
        total_employees = User.objects.filter(tier='corporate').count()
        
        avg_score = Office.objects.aggregate(avg=Avg('base_environmental_score'))['avg']
        
        return Response({
            'total_offices': total_offices,
            'total_departments': total_departments,
            'total_employees': total_employees,
            'average_environmental_score': round(avg_score, 1) if avg_score else 0,
        })

class DashboardOfficesView(generics.ListCreateAPIView):
    """GET /internal/dashboard/offices/ — List offices
       POST /internal/dashboard/offices/ — Create office"""
    from core.models import Office
    from .serializers import OfficeSerializer
    permission_classes = [permissions.AllowAny]
    queryset = Office.objects.all().order_by('name')
    serializer_class = OfficeSerializer

class DashboardAnalysesView(generics.ListAPIView):
    """GET /internal/dashboard/analyses/ — Recent corporate scans."""
    from core.models import EnvironmentScan
    from .serializers import EnvironmentScanSerializer
    permission_classes = [permissions.AllowAny]
    queryset = EnvironmentScan.objects.filter(user__tier='corporate').order_by('-created_at')[:10]
    serializer_class = EnvironmentScanSerializer

class DashboardChartView(APIView):
    """GET /internal/dashboard/chart/ — Time series data for chart."""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        
        # Get data for the last 90 days
        now = timezone.now()
        three_months_ago = now - timedelta(days=90)
        
        scans = EnvironmentScan.objects.filter(
            user__tier='corporate', 
            created_at__gte=three_months_ago,
            user__office__isnull=False
        ).annotate(month=TruncMonth('created_at')).values('month', 'user__office__name').annotate(avg_score=Avg('environment_score')).order_by('month')
        
        data_by_month = {}
        for scan in scans:
            month_str = scan['month'].strftime('%b')
            office_name = scan['user__office__name'].replace(' ', '_').replace('-', '_')
            
            if month_str not in data_by_month:
                data_by_month[month_str] = {"date": month_str}
            data_by_month[month_str][office_name] = round(scan['avg_score'])
            
        result = list(data_by_month.values())
        if not result:
            result = [{"date": now.strftime('%b')}]
        return Response(result)

class DashboardSensoryDistributionView(APIView):
    """GET /internal/dashboard/sensory-distribution/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        from core.models import SensoryProfile
        profiles = SensoryProfile.objects.filter(user__tier='corporate')
        
        avoidant = 0
        balanced = 0
        seeking = 0
        
        for p in profiles:
            avg_sens = (p.light_sensitivity + p.sound_sensitivity + p.texture_sensitivity) / 3
            if avg_sens > 66:
                seeking += 1
            elif avg_sens < 33:
                avoidant += 1
            else:
                balanced += 1
                
        total = max(avoidant + balanced + seeking, 1)
        
        return Response([
            {"name": "Sensory avoidant", "value": round((avoidant/total)*100), "fill": "#8FD14F"},
            {"name": "Balanced", "value": round((balanced/total)*100), "fill": "#18C081"},
            {"name": "Sensory seeking", "value": round((seeking/total)*100), "fill": "#F2A10B"},
        ])

class DashboardAnalyticsChartView(APIView):
    """GET /internal/dashboard/analytics/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        from core.models import EnvironmentScan
        from django.db.models.functions import TruncDay
        from django.db.models import Avg
        from django.utils import timezone
        from datetime import timedelta
        
        now = timezone.now()
        two_weeks_ago = now - timedelta(days=14)
        
        scans = EnvironmentScan.objects.filter(
            user__tier='corporate', 
            created_at__gte=two_weeks_ago
        ).annotate(day=TruncDay('created_at')).values('day').annotate(
            avg_lighting=Avg('environment_score'), 
            avg_noise=Avg('focus_score') 
        ).order_by('day')
        
        lighting = []
        noise = []
        for s in scans:
            day_str = s['day'].strftime('%a')
            lighting.append({"day": day_str, "value": round(s['avg_lighting'])})
            noise.append({"day": day_str, "value": round(s['avg_noise'])})
            
        return Response({"lighting": lighting, "noise": noise})

class DashboardHeatmapView(APIView):
    """GET /internal/dashboard/heatmap/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        from core.models import SensoryProfile
        profiles = SensoryProfile.objects.filter(user__tier='corporate')
        
        cells = []
        for p in profiles:
            avg_sens = (p.light_sensitivity + p.sound_sensitivity + p.texture_sensitivity) / 3
            if avg_sens > 75:
                color = "#F43F5E" # red
            elif avg_sens > 60:
                color = "#F68CA3" # pink
            elif avg_sens > 45:
                color = "#FACC4D" # yellow
            elif avg_sens > 30:
                color = "#67E393" # light green
            else:
                color = "#22C55E" # green
                
            cells.append({"id": str(p.id), "color": color})
            
        return Response(cells)

class DashboardUsersView(generics.ListAPIView):
    """GET /internal/dashboard/users/ — Corporate users."""
    from core.models import User
    from .serializers import UserSerializer
    permission_classes = [permissions.AllowAny]
    queryset = User.objects.filter(tier='corporate').order_by('first_name', 'username')
    serializer_class = UserSerializer

class DashboardAnalysisView(APIView):
    """GET /internal/dashboard/analysis/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "scores": {
                "environmental": {"value": 82, "trend": "+3.4", "color": "#8ED14B"},
                "lighting": {"value": 76, "trend": "+1.1", "color": "#F59E0B"},
                "acoustic": {"value": 68, "trend": "-2.2", "color": "#14B8A6"},
                "air": {"value": 89, "trend": "+0.6", "color": "#22C55E"}
            },
            "actions": [
                {"title": "Acoustic panels - Meeting 4A", "impact": "Impact +6 pts · $2.4k", "priority": "HIGH"},
                {"title": "Dimmable fixtures - Focus Pods", "impact": "Impact +4 pts · $6.1k", "priority": "MED"},
                {"title": "Add greenery - Lounge", "impact": "Impact +2 pts · $780", "priority": "LOW"}
            ]
        })

class DashboardConflictsView(APIView):
    """GET /internal/dashboard/conflicts/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "Noise": {
                "impact": "-12.4% productivity",
                "conflicts": [
                    {"title": "Quiet zone adjacent to collaboration hub", "zones": "Quiet Library ↔ Collab Hub", "severity": "HIGH"},
                    {"title": "Meeting room echo bleed into focus pods", "zones": "Meeting 4A ↔ Focus Pods A", "severity": "MED"},
                    {"title": "Glare from west windows on screens", "zones": "Focus Pods A", "severity": "MED"},
                    {"title": "Foot-traffic through relaxation lounge", "zones": "Relax Lounge", "severity": "LOW"}
                ]
            },
            "Lighting": {
                "impact": "-8.1% productivity",
                "conflicts": [
                    {"title": "Glare from west windows on screens", "zones": "Focus Pods A", "severity": "HIGH"},
                    {"title": "Overhead brightness inconsistency", "zones": "Open Workspace", "severity": "MED"}
                ]
            },
            "Traffic Flow": {
                "impact": "-10.2% productivity",
                "conflicts": [
                    {"title": "Cross-circulation near meeting rooms", "zones": "Main Corridor", "severity": "HIGH"},
                    {"title": "Crowding at lounge entrance", "zones": "Relax Lounge", "severity": "MED"}
                ]
            },
            "Privacy": {
                "impact": "-6.8% productivity",
                "conflicts": [
                    {"title": "Visual privacy exposure", "zones": "Focus Pods", "severity": "MED"}
                ]
            },
            "Accessibility": {
                "impact": "-5.4% productivity",
                "conflicts": [
                    {"title": "Wheelchair turning radius issue", "zones": "East Wing", "severity": "MED"}
                ]
            },
            "Temperature": {
                "impact": "-7.3% productivity",
                "conflicts": [
                    {"title": "Localized overheating", "zones": "South Zone", "severity": "HIGH"}
                ]
            },
            "Occupancy": {
                "impact": "-9.5% productivity",
                "conflicts": [
                    {"title": "High occupancy concentration", "zones": "Collaboration Hub", "severity": "HIGH"}
                ]
            }
        })

class DashboardProcurementView(APIView):
    """GET /internal/dashboard/procurement/
       POST /internal/dashboard/procurement/"""
    permission_classes = [permissions.AllowAny]
    
    _orders = [
        {"product": "FeltBloc Acoustic Panel 24×48", "qty": 42, "cost": 3738, "vendor": "FeltBloc Inc.", "priority": "HIGH", "status": "Approved"},
        {"product": "Dimmable LED 2700K (10-pk)", "qty": 18, "cost": 1620, "vendor": "LumenWorks", "priority": "HIGH", "status": "Pending"},
        {"product": "Wool Loop Rug 8×10", "qty": 6, "cost": 2394, "vendor": "Nordic Textile", "priority": "MED", "status": "Approved"},
        {"product": "Blackout Motorized Blinds", "qty": 12, "cost": 4680, "vendor": "Shade Systems", "priority": "MED", "status": "Draft"},
        {"product": "Biophilic Planters (set)", "qty": 24, "cost": 1152, "vendor": "Verdant Co.", "priority": "LOW", "status": "Approved"}
    ]

    def get(self, request):
        return Response({
            "orders": DashboardProcurementView._orders,
            "cost_breakdown": [
                {"label": "Acoustic", "color": "#3B82F6", "value": "26%"},
                {"label": "Lighting", "color": "#F59E0B", "value": "24%"},
                {"label": "Textiles", "color": "#EF4444", "value": "18%"},
                {"label": "Shading", "color": "#10B981", "value": "24%"},
                {"label": "Biophilic", "color": "#A855F7", "value": "8%"}
            ]
        })

    def post(self, request):
        order = request.data
        DashboardProcurementView._orders.append(order)
        return Response(order, status=status.HTTP_201_CREATED)

class DashboardReportsView(APIView):
    """GET /internal/dashboard/reports/"""
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "recent_reports": [
                {"title": "Q3 2026 • Portfolio wellness review", "date": "Oct 3, 2026"},
                {"title": "SF HQ • Floor 4 remodel projection", "date": "Sep 21, 2026"},
                {"title": "Acoustic remediation ROI", "date": "Sep 12, 2026"},
                {"title": "Berlin Loft opening baseline", "date": "Aug 30, 2026"}
            ],
            "environmental_improvements": [
                ["Jan", "72"], ["Feb", "74"], ["Mar", "77"], ["Apr", "79"],
                ["May", "81"], ["Jun", "86"], ["Jul", "88"], ["Aug", "90"],
                ["Sep", "94"], ["Oct", "97"], ["Nov", "100"], ["Dec", "104"]
            ]
        })

class DashboardSettingsView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        settings, _ = WorkspaceSettings.objects.get_or_create(
            # Using defaults for the initial object if none exists
            defaults={
                "organization_name": "Acme Corporation",
                "workspace_url": "sensa.app/acme",
                "industry": "Technology",
                "company_size": "500–1,000",
                "noise_standard": 55,
                "illuminance_standard": 450,
                "cct_standard": 4000
            }
        )
        return Response({
            "organization": { 
                "name": settings.organization_name, 
                "url": settings.workspace_url, 
                "industry": settings.industry, 
                "size": settings.company_size 
            },
            "standards": { 
                "noise": settings.noise_standard, 
                "illuminance": settings.illuminance_standard, 
                "cct": settings.cct_standard 
            }
        })

    def put(self, request):
        settings, _ = WorkspaceSettings.objects.get_or_create()
        data = request.data
        
        org_data = data.get('organization', {})
        std_data = data.get('standards', {})
        
        settings.organization_name = org_data.get('name', settings.organization_name)
        settings.workspace_url = org_data.get('url', settings.workspace_url)
        settings.industry = org_data.get('industry', settings.industry)
        settings.company_size = org_data.get('size', settings.company_size)
        
        settings.noise_standard = std_data.get('noise', settings.noise_standard)
        settings.illuminance_standard = std_data.get('illuminance', settings.illuminance_standard)
        settings.cct_standard = std_data.get('cct', settings.cct_standard)
        
        settings.save()
        
        return Response(request.data, status=status.HTTP_200_OK)

class DashboardHeaderView(APIView):
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "user": {
                "initials": "MK",
                "name": "Maya Kwan",
                "role": "Acme HQ • Admin"
            },
            "office": "Acme HQ"
        })

class DashboardFloorPlanView(APIView):
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "measurements": {
                "width": "260px",
                "height": "200px",
                "x": "560",
                "y": "100"
            },
            "capacity": "Optimal for 18–24 employees",
            "zone": "Collab Hub"
        })

class DashboardUsersMetaView(APIView):
    permission_classes = [permissions.AllowAny]
    def get(self, request):
        return Response({
            "stats": {
                "totalMembers": 141,
                "activeSeats": 132,
                "pendingInvites": 9,
                "admins": 7
            },
            "roles": [
                { "name": "Owner", "description": "Full billing, security, and workspace control", "count": 1 },
                { "name": "Admin", "description": "Manage offices, users, and floor plans", "count": 6 },
                { "name": "Facilities", "description": "Edit zones, procurement, and layouts", "count": 24 },
                { "name": "Analyst", "description": "Read analytics and export reports", "count": 41 },
                { "name": "Viewer", "description": "Read-only access to dashboards", "count": 76 }
            ],
            "invites": [
                { "email": "ava.chen@acme.co", "role": "Viewer", "sent": "2 days ago" },
                { "email": "kenji.tan@acme.co", "role": "Analyst", "sent": "5 days ago" },
                { "email": "olivia.brown@acme.co", "role": "Facilities", "sent": "11 days ago" }
            ]
        })
