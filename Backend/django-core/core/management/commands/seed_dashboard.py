from django.core.management.base import BaseCommand
from core.models import Office, Department, User, EnvironmentScan
from django.utils import timezone
import random

class Command(BaseCommand):
    help = 'Seeds the database with mock data for the enterprise dashboard.'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding offices...')
        
        # Clear existing
        Office.objects.all().delete()
        Department.objects.all().delete()
        # Keep users and scans, but we might want to clear corporate ones
        User.objects.filter(tier='corporate').delete()

        offices_data = [
            {'name': 'SF HQ', 'region': 'US-West', 'score': 88, 'trend': 3.1, 'status': 'healthy', 'emps': 842},
            {'name': 'NY East', 'region': 'US-East', 'score': 79, 'trend': -0.4, 'status': 'watch', 'emps': 612},
            {'name': 'Austin', 'region': 'US-South', 'score': 72, 'trend': -2.1, 'status': 'action', 'emps': 334},
            {'name': 'Berlin', 'region': 'EU-Central', 'score': 84, 'trend': 1.8, 'status': 'healthy', 'emps': 220},
            {'name': 'Tokyo', 'region': 'APAC', 'score': 81, 'trend': 0.6, 'status': 'healthy', 'emps': 189},
        ]

        offices = []
        for d in offices_data:
            o = Office.objects.create(
                name=d['name'],
                region=d['region'],
                base_environmental_score=d['score'],
                trend=d['trend'],
                status=d['status']
            )
            offices.append((o, d['emps']))
            
            # Create a few departments per office
            for dept_name in ['Engineering', 'Sales', 'Marketing', 'HR', 'Product']:
                Department.objects.create(name=dept_name, office=o)

        self.stdout.write('Seeding corporate users and employees...')
        
        # Create a user per office employee (in bulk)
        users_to_create = []
        for office, num_emps in offices:
            departments = list(office.departments.all())
            # For speed in development we might not want to create 4000 users, but bulk_create is fast enough for ~2000.
            for i in range(num_emps):
                dept = random.choice(departments)
                u = User(
                    username=f"corp_{office.id}_{i}",
                    email=f"u_{office.id}_{i}@corp.local",
                    tier='corporate',
                    office=office,
                    department=dept,
                )
                users_to_create.append(u)
        
        User.objects.bulk_create(users_to_create)

        self.stdout.write('Seeding recent AI analyses (scans)...')
        # Create some recent scans
        corp_users = list(User.objects.filter(tier='corporate')[:100])
        if corp_users:
            for i in range(15):
                u = random.choice(corp_users)
                EnvironmentScan.objects.create(
                    user=u,
                    image_ref='mock.jpg',
                    environment_score=random.randint(60, 95),
                    focus_score=random.randint(60, 95),
                    sleep_score=random.randint(60, 95),
                    mood_score=random.randint(60, 95),
                    room_name=f"Room {random.randint(1, 100)}",
                    llm_output={"message": "Mock analysis"}
                )

        self.stdout.write(self.style.SUCCESS('Successfully seeded dashboard data!'))
