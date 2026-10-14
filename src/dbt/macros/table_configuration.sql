{% macro table_configuration(materialized, schema, alias, tags) %}
    {{ config(
        materialized=materialized,
        schema=schema,
        alias=alias,
        tags=tags
    ) }}
{% endmacro %}