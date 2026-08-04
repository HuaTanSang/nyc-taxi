{% macro s3_source(s3_path) %}
    s3(
        '{{ env_var("MINIO_ENDPOINT", "http://minio:9000") }}/{{ s3_path }}', 
        '{{ env_var("MINIO_ACCESS_KEY", "minioadmin") }}', 
        '{{ env_var("MINIO_SECRET_KEY", "minioadmin") }}', 
        'Parquet',
    )
{% endmacro %}