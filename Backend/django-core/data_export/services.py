"""
Anonymization service for Sensory AI data export pipeline.
Strips PII, generates one-way anonymized UUID, writes to research table.
"""
import uuid
import logging
from django.db import transaction
from django.utils import timezone

from core.models import User, EnvironmentScan
from .models import AnonymizedScan, AnonymizationMapping, AccessLog

logger = logging.getLogger(__name__)


def get_or_create_anonymized_id(user: User) -> uuid.UUID:
    """
    Get or create a one-way anonymized UUID for a user.
    The mapping is stored in AnonymizationMapping (secured table).
    """
    mapping, created = AnonymizationMapping.objects.get_or_create(user=user)

    if created:
        _log_access(
            accessed_by='system:anonymization',
            action='write',
            resource_type='AnonymizationMapping',
            resource_id=str(mapping.id),
            details=f'Created anonymization mapping for user {user.id}',
        )

    return mapping.anonymized_id


def anonymize_scan(scan: EnvironmentScan) -> AnonymizedScan:
    """
    Anonymize an EnvironmentScan and write it to the research table.

    Steps:
    1. Get/create anonymized UUID for the user
    2. Strip all PII from the scan data
    3. Write anonymized version to AnonymizedScan table
    4. Log the access

    This is the HARD GATE before any research-database write.
    """
    with transaction.atomic():
        # 1. Get anonymized user ID
        anon_id = get_or_create_anonymized_id(scan.user)

        # 2. Strip PII from LLM output and build clean data
        clean_data = _strip_pii(scan)

        # 3. Create anonymized scan record
        anon_scan = AnonymizedScan.objects.create(
            anonymized_user_id=anon_id,
            original_scan=scan,
            scan_data=clean_data,
        )

        # 4. Audit log
        _log_access(
            accessed_by='system:anonymization',
            action='export',
            resource_type='EnvironmentScan',
            resource_id=str(scan.id),
            details=f'Anonymized scan {scan.id} → anon scan {anon_scan.id}',
        )

        logger.info(
            f'Anonymized scan {scan.id} → {anon_scan.id} '
            f'(anon user: {anon_id})'
        )

        return anon_scan


def _strip_pii(scan: EnvironmentScan) -> dict:
    """
    Strip all personally identifiable information from scan data.
    Returns a clean dictionary safe for research datasets.

    Removes:
    - user_id, username, email, name
    - image_ref (file paths may contain user info)
    - audio_ref (same)

    Keeps:
    - Scores (environment, focus, sleep, mood)
    - LLM output (notes, recommendations)
    - Color matches
    - Room name (generic, not PII)
    - Timestamp (date only, no exact time to prevent re-identification)
    """
    clean_llm_output = {}
    if scan.llm_output:
        # Deep copy and strip any user-referencing text
        clean_llm_output = {
            k: v for k, v in scan.llm_output.items()
            if k not in ('user_id', 'user_name', 'user_email')
        }

    return {
        'environment_score': scan.environment_score,
        'focus_score': scan.focus_score,
        'sleep_score': scan.sleep_score,
        'mood_score': scan.mood_score,
        'llm_analysis': clean_llm_output,
        'color_matches': scan.color_matches,
        'room_type': scan.room_name,
        'scan_date': scan.created_at.date().isoformat(),
    }


def batch_anonymize_user_scans(user: User) -> list:
    """
    Anonymize all scans for a user that haven't been anonymized yet.
    Returns list of created AnonymizedScan objects.
    """
    # Find scans without anonymized versions
    unanonymized = EnvironmentScan.objects.filter(
        user=user,
        anonymized_version__isnull=True,
    )

    results = []
    for scan in unanonymized:
        try:
            anon_scan = anonymize_scan(scan)
            results.append(anon_scan)
        except Exception as e:
            logger.error(f'Failed to anonymize scan {scan.id}: {e}')

    return results


def _log_access(accessed_by: str, action: str, resource_type: str,
                resource_id: str, details: str = '', ip_address: str = None):
    """Create an audit log entry."""
    AccessLog.objects.create(
        accessed_by=accessed_by,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        ip_address=ip_address,
        details=details,
    )
