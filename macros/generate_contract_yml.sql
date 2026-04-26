{% macro generate_contract_yml(model_name) %}

    {% set relation = ref(model_name) %}

    {% set columns = adapter.get_columns_in_relation(relation) %}

    {% set yaml_output %}
models:
  - name: {{ model_name }}
    config:
      contract:
        enforced: true
    columns:
{% for col in columns %}
      - name: {{ col.name | lower }}
        data_type: {{ col.dtype | lower }}
{% endfor %}
    {% endset %}

    {{ log(yaml_output, info=true) }}

{% endmacro %}