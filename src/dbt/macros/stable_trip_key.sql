{% macro stable_trip_key(service_type, source_file_id, source_row_number) -%}
    lower(
        hex(
            SHA256(
                concatWithSeparator(
                    '||',
                    '{{ service_type }}',
                    ifNull(toString({{ source_file_id }}), '__null_source_file__'),
                    toString({{ source_row_number }})
                )
            )
        )
    )
{%- endmacro %}
