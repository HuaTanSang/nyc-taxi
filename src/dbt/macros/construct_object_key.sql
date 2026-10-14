{% macro construct_object_key(taxi_type, year, month, file_type) %}
    {% set month_str = "%02d" | format(month | int) %}

    {{ return(
        'nyc-taxi-raw/'
        ~ taxi_type
        ~ '/year=' ~ (year | string)
        ~ '/month=' ~ month_str
        ~ '/' ~ taxi_type
        ~ '_tripdata_' ~ (year | string)
        ~ '-' ~ month_str
        ~ '.' ~ file_type
    ) }}
{% endmacro %}
