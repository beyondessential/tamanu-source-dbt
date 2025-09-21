select
    id,
    code,
    name,
    survey_type,
    is_sensitive,
    notifiable as is_notifiable,
    notify_email_addresses,
    program_id,
    visibility_status
from {{ resolve_input_model('surveys', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null
