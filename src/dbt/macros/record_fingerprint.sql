{% macro record_fingerprint(columns) -%}
    SHA256(
        toString(
            tuple(
                {{ columns | join(',\n                ') }}
            )
        )
    )
{%- endmacro %}
