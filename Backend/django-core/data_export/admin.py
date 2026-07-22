from django.contrib import admin
from .models import AnonymizedScan, AnonymizationMapping, RoyaltyLedger, AccessLog


@admin.register(AnonymizedScan)
class AnonymizedScanAdmin(admin.ModelAdmin):
    list_display = ['id', 'anonymized_user_id', 'dataset_batch', 'created_at', 'exported_at']
    list_filter = ['dataset_batch', 'exported_at']
    readonly_fields = ['id', 'anonymized_user_id', 'scan_data', 'created_at']


@admin.register(AnonymizationMapping)
class AnonymizationMappingAdmin(admin.ModelAdmin):
    list_display = ['user', 'anonymized_id', 'created_at']
    readonly_fields = ['id', 'anonymized_id', 'created_at']
    search_fields = ['user__username', 'user__email']


@admin.register(RoyaltyLedger)
class RoyaltyLedgerAdmin(admin.ModelAdmin):
    list_display = ['user', 'dataset_batch', 'scans_contributed', 'royalty_amount_cents', 'status', 'created_at']
    list_filter = ['status', 'dataset_batch']
    search_fields = ['user__username']


@admin.register(AccessLog)
class AccessLogAdmin(admin.ModelAdmin):
    list_display = ['action', 'resource_type', 'accessed_by', 'ip_address', 'created_at']
    list_filter = ['action', 'resource_type']
    search_fields = ['accessed_by', 'resource_id']
    readonly_fields = ['id', 'accessed_by', 'action', 'resource_type', 'resource_id', 'ip_address', 'details', 'created_at']
