from django.core.management.base import BaseCommand
from core.models import EnvironmentScan, Office, User
from django.utils import timezone
import random
from datetime import timedelta

class Command(BaseCommand):
    help = 'Backdates environment scans to generate realistic chart data'

    def handle(self, *args, **kwargs):
        scans = EnvironmentScan.objects.all()
        now = timezone.now()
        
        updated_count = 0
        for scan in scans:
            # Random date within the last 90 days
            days_ago = random.randint(0, 90)
            random_time = timedelta(days=days_ago, hours=random.randint(-12, 12))
            
            # Since auto_now_add is on created_at, we have to use update() to bypass it,
            # or modify the object and save with update_fields.
            scan.created_at = now - random_time
            # EnvironmentScan.objects.filter(id=scan.id).update(created_at=scan.created_at) is safer
            EnvironmentScan.objects.filter(id=scan.id).update(created_at=scan.created_at)
            updated_count += 1
            
        self.stdout.write(self.style.SUCCESS(f'Successfully backdated {updated_count} scans.'))
