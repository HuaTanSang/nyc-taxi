{% macro raw_layer_config(tags) -%}
{{
    config (
        materialized='view',
        tags=tags
    )
}}
{%- endmacro %}
