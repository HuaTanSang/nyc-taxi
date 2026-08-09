{% macro s3_source(s3_path, file_format='Parquet', structure=none) %}

    s3(
        '{{ env_var("MINIO_ENDPOINT", "http://minio:9000") }}/{{ s3_path }}',
        '{{ env_var("MINIO_ACCESS_KEY", "minioadmin") }}',
        '{{ env_var("MINIO_SECRET_KEY", "minioadmin") }}',
        '{{ file_format }}'
        {% if structure is not none %}
            , '{{ structure }}'
        {% endif %}
    )

{% endmacro %}