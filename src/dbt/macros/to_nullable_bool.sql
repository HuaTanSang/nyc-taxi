{% macro to_nullable_bool(column_name) -%}
    multiIf(
        upperUTF8(trim(ifNull(toString({{ column_name }}), ''))) in ('Y', 'YES', 'TRUE', '1'),
        true,
        upperUTF8(trim(ifNull(toString({{ column_name }}), ''))) in ('N', 'NO', 'FALSE', '0'),
        false,
        cast(null as Nullable(Bool))
    )
{%- endmacro %}
