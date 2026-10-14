{% macro reject_full_refresh() -%}
    {% if flags.FULL_REFRESH %}
        {{ exceptions.raise_compiler_error(
            "Full refresh is disabled for monthly partitioned models. "
            ~ "Rebuild the required year/month partitions sequentially instead."
        ) }}
    {% endif %}
{%- endmacro %}
