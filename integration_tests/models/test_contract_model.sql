select
    id,
    name,
    amount,
    is_active,
    event_date
from {{ ref('test_table') }}
