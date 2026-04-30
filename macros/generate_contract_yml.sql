{% macro generate_contract_yml(model_name, schema=none, enforced=false) %}

    {#-
      SNOWFLAKE ONLY: This macro introspects column types using Snowflake's information schema.
      Type normalization is calibrated for Snowflake dtypes. Running against Postgres,
      Redshift, BigQuery, or other adapters will produce incorrect or unmapped types.
    -#}

    {#- Resolve schema: use the caller-supplied value or fall back to target.schema with a warning -#}
    {%- if schema is none -%}
        {%- set schema = target.schema -%}
        {{ log("Warning: no schema argument provided. Defaulting to target.schema = '" ~ schema ~ "'. If your project uses a custom generate_schema_name macro and the model lives in a different schema, pass schema explicitly.", info=true) }}
    {%- endif -%}

    {#- Resolve the relation object from the adapter -#}
    {%- set relation = adapter.get_relation(
        database   = target.database,
        schema     = schema,
        identifier = model_name
    ) -%}

    {#- Null guard — get_relation() returns none when the model is not materialized -#}
    {%- if relation is none -%}
        {{ exceptions.raise_compiler_error(
            "generate_contract_yml: relation not found for model '" ~ model_name ~
            "' in schema '" ~ schema ~ "'. Verify the model has been materialized " ~
            "and that the schema argument matches the actual warehouse schema."
        ) }}
    {%- endif -%}

    {#- Introspect columns from the live relation -#}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}

    {#- Empty-column guard — a dangling `columns:` key is invalid YAML -#}
    {%- if columns | length == 0 -%}
        {{ exceptions.raise_compiler_error(
            "generate_contract_yml: no columns returned for relation '" ~ model_name ~
            "'. The relation exists but has no introspectable columns. " ~
            "Check that the model is not an empty view pointing at a dropped source."
        ) }}
    {%- endif -%}

    {#- Diagnostic: one line per column showing raw name and dtype before the YAML block -#}
    {{ log("Columns found in '" ~ model_name ~ "' (" ~ columns | length ~ " total):", info=true) }}
    {%- for col in columns -%}
        {{ log("  - " ~ col.name ~ " (raw dtype: " ~ col.dtype ~ ")", info=true) }}
    {%- endfor -%}

    {#- Build the YAML string; whitespace-stripping tags (Defect 5) keep the output clean -#}
    {%- set yaml_lines = [] -%}
    {%- do yaml_lines.append("models:") -%}
    {%- do yaml_lines.append('  - name: "' ~ model_name | replace('"', '\\"') ~ '"') -%}
    {%- do yaml_lines.append("    config:") -%}
    {%- do yaml_lines.append("      contract:") -%}
    {#- enforced defaults to false — flip to true only after verifying all type mappings are correct -#}
    {%- if enforced -%}
        {%- do yaml_lines.append("        enforced: true") -%}
    {%- else -%}
        {%- do yaml_lines.append("        enforced: false") -%}
    {%- endif -%}
    {%- do yaml_lines.append("    columns:") -%}

    {%- for col in columns -%}

        {#- Defect 3: type normalization — strip precision/scale then map to a canonical type -#}
        {%- set base_type = col.dtype.split('(')[0].strip().upper() -%}

        {%- if base_type in ('TEXT', 'VARCHAR', 'STRING', 'CHAR', 'NCHAR', 'NVARCHAR') -%}
            {%- set mapped_type = 'string' -%}
        {%- elif base_type in ('NUMBER', 'NUMERIC', 'DECIMAL') -%}
            {%- set mapped_type = 'number' -%}
        {%- elif base_type in ('INT', 'INTEGER', 'BIGINT', 'SMALLINT', 'TINYINT', 'BYTEINT') -%}
            {%- set mapped_type = 'integer' -%}
        {%- elif base_type in ('FLOAT', 'FLOAT4', 'FLOAT8', 'DOUBLE', 'DOUBLE PRECISION', 'REAL') -%}
            {%- set mapped_type = 'float' -%}
        {%- elif base_type == 'BOOLEAN' -%}
            {%- set mapped_type = 'boolean' -%}
        {%- elif base_type == 'DATE' -%}
            {%- set mapped_type = 'date' -%}
        {%- elif base_type == 'TIME' -%}
            {%- set mapped_type = 'time' -%}
        {%- elif base_type in ('TIMESTAMP_NTZ', 'TIMESTAMP_LTZ', 'TIMESTAMP_TZ', 'TIMESTAMP') -%}
            {%- set mapped_type = 'timestamp' -%}
        {%- elif base_type in ('VARIANT', 'OBJECT') -%}
            {%- set mapped_type = 'variant' -%}
        {%- elif base_type == 'ARRAY' -%}
            {%- set mapped_type = 'array' -%}
        {%- elif base_type in ('BINARY', 'VARBINARY') -%}
            {%- set mapped_type = 'binary' -%}
        {%- else -%}
            {#- Unknown type: pass through in lowercase so the YAML is still usable -#}
            {%- set mapped_type = base_type | lower -%}
        {%- endif -%}

        {%- do yaml_lines.append('      - name: "' ~ col.name | lower | replace('"', '\\"') ~ '"') -%}
        {%- do yaml_lines.append("        data_type: " ~ mapped_type) -%}

    {%- endfor -%}

    {#- Join all lines with newlines to produce the final YAML string -#}
    {%- set yaml_output = yaml_lines | join('\n') -%}

    {{ log(yaml_output, info=true) }}

{% endmacro %}
