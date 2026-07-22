"""
Data export models for anonymization and research data pipeline.

Models:
- AnonymizedScan: Scan data with PII stripped, for research datasets
- AnonymizationMapping: Secured mapping between real user and anonymized UUID
- RoyaltyLedger: Tracks royalty payouts to contributing users via Stripe Connect
"""
import uuid
from django.db import models
from core.models import User, EnvironmentScan


class AnonymizedScan(models.Model):
    """
    Anonymized version of EnvironmentScan for research datasets.
    No direct link to user — only the anonymized UUID.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    anonymized_user_id = models.UUIDField(
        db_index=True,
        help_text='One-way anonymized identifier (not reversible without mapping table)',
    )
    original_scan = models.OneToOneField(
        EnvironmentScan,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='anonymized_version',
    )

    # Stripped/anonymized scan data
    scan_data = models.JSONField(
        default=dict,
        help_text='LLM output and scores with PII removed',
    )

    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    exported_at = models.DateTimeField(blank=True, null=True)
    dataset_batch = models.CharField(
        max_length=100, blank=True,
        help_text='Identifier for the research dataset batch this was exported in',
    )

    class Meta:
        db_table = 'anonymized_scans'
        verbose_name = 'Anonymized Scan'
        verbose_name_plural = 'Anonymized Scans'

    def __str__(self):
        return f"AnonScan {self.id} (user: {self.anonymized_user_id})"


class AnonymizationMapping(models.Model):
    """
    Secured mapping between real user_id and anonymized UUID.
    This table must be encrypted at rest and access-audited.
    HIPAA-grade: only accessible by compliance officers.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='anonymization_mapping',
    )
    anonymized_id = models.UUIDField(
        unique=True,
        default=uuid.uuid4,
        help_text='The anonymized UUID used in research datasets',
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'anonymization_mappings'
        verbose_name = 'Anonymization Mapping'
        verbose_name_plural = 'Anonymization Mappings'
        # Only compliance-level access
        permissions = [
            ('view_mapping_data', 'Can view anonymization mapping data'),
        ]

    def __str__(self):
        return f"Mapping: {self.user} → {self.anonymized_id}"


class RoyaltyLedger(models.Model):
    """
    Tracks royalty payouts for data contributions.
    When research institutions purchase datasets, contributing users get royalties via Stripe Connect.
    """

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        PROCESSING = 'processing', 'Processing'
        PAID = 'paid', 'Paid'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='royalty_entries',
    )
    dataset_batch = models.CharField(max_length=100)
    scans_contributed = models.PositiveIntegerField(default=0)
    royalty_amount_cents = models.PositiveIntegerField(
        default=0,
        help_text='Royalty amount in cents (USD)',
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
    )
    stripe_transfer_id = models.CharField(max_length=255, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'royalty_ledger'
        verbose_name = 'Royalty Ledger Entry'
        verbose_name_plural = 'Royalty Ledger'
        ordering = ['-created_at']

    def __str__(self):
        return f"Royalty {self.id}: ${self.royalty_amount_cents / 100:.2f} → {self.user}"


class AccessLog(models.Model):
    """
    Audit log for all access to raw (non-anonymized) sensory data.
    HIPAA compliance requirement — log every read/write.
    """

    class Action(models.TextChoices):
        READ = 'read', 'Read'
        WRITE = 'write', 'Write'
        EXPORT = 'export', 'Export'
        DELETE = 'delete', 'Delete'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    accessed_by = models.CharField(
        max_length=255,
        help_text='Username or service identifier of the accessor',
    )
    action = models.CharField(max_length=20, choices=Action.choices)
    resource_type = models.CharField(
        max_length=100,
        help_text='e.g., EnvironmentScan, AnonymizationMapping',
    )
    resource_id = models.CharField(max_length=255)
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    details = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'access_logs'
        verbose_name = 'Access Log'
        verbose_name_plural = 'Access Logs'
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.action}] {self.resource_type} by {self.accessed_by}"
