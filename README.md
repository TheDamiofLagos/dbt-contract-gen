# dbt-contract-gen

This package generates dbt contract YAML for a model by introspecting its columns directly from the warehouse. Run one command, copy the printed YAML from your terminal, and paste it into your model's `.yml` file. No manual column listing required.

---

## Requirements

- dbt >= 1.5.0 (contracts were introduced in dbt 1.5)
- Snowflake adapter only — type normalization is calibrated for Snowflake data types. Running against Postgres, BigQuery, Redshift, or other adapters will produce incorrect or unmapped types.

---

## Installation

Add the following to your project's `packages.yml`, then run `dbt deps`.

```yaml
packages:
  - git: "https://github.com/TheDamiofLagos/dbt-contract-gen.git"
    revision: v0.1.0
```

---

## Usage

### Macro signature

```
generate_contract_yml(model_name, schema=none, enforced=false)
```

### Arguments

| Argument | Required | Default | Description |
|---|---|---|---|
| `model_name` | Yes | — | The name of the dbt model to introspect. |
| `schema` | No | `target.schema` | The warehouse schema where the model is materialized. If your project uses a custom `generate_schema_name` macro, the resolved schema may differ from `target.schema` — pass this argument explicitly when in doubt. |
| `enforced` | No | `false` | Whether to set `contract.enforced: true` in the output. Leave as `false` until you have verified all type mappings are correct. |

### Commands

```bash
# Minimal — schema inferred from target.schema (a warning is printed if omitted)
dbt run-operation generate_contract_yml --args '{model_name: fct_order_items}'

# Explicit schema
dbt run-operation generate_contract_yml --args '{model_name: fct_order_items, schema: dev_damilare}'

# Ready to enforce
dbt run-operation generate_contract_yml --args '{model_name: fct_order_items, schema: dev_damilare, enforced: true}'
```

The macro prints a diagnostic line for each column (raw name and Snowflake dtype) before the YAML block, so you can verify the type mapping before pasting the output.

---

## Example output

The following output was generated against `fct_order_items` on Snowflake.

```yaml
models:
  - name: "fct_order_items"
    config:
      contract:
        enforced: false
    columns:
      - name: "order_date"
        data_type: date
      - name: "orderitem_id"
        data_type: number
      - name: "order_id"
        data_type: number
      - name: "customer_id"
        data_type: number
      - name: "product_id"
        data_type: number
      - name: "supplier_id"
        data_type: number
      - name: "payment_method_id"
        data_type: number
      - name: "campaign_id"
        data_type: number
      - name: "is_campaign_order"
        data_type: boolean
      - name: "quantity"
        data_type: number
      - name: "subtotal"
        data_type: number
      - name: "discount"
        data_type: number
      - name: "discounted_subtotal"
        data_type: number
```

---

## Type mapping

Precision and scale are stripped before mapping (e.g. `NUMBER(38,0)` is treated as `NUMBER`). For unknown types, the macro passes the raw type through in lowercase rather than raising an error, so the YAML remains usable.

| Snowflake type | `data_type` |
|---|---|
| VARCHAR, TEXT, STRING, CHAR, NCHAR, NVARCHAR | `string` |
| NUMBER, NUMERIC, DECIMAL | `number` |
| INT, INTEGER, BIGINT, SMALLINT, TINYINT, BYTEINT | `integer` |
| FLOAT, FLOAT4, FLOAT8, DOUBLE, DOUBLE PRECISION, REAL | `float` |
| BOOLEAN | `boolean` |
| DATE | `date` |
| TIME | `time` |
| TIMESTAMP_NTZ, TIMESTAMP_LTZ, TIMESTAMP_TZ, TIMESTAMP | `timestamp` |
| VARIANT, OBJECT | `variant` |
| ARRAY | `array` |
| BINARY, VARBINARY | `binary` |

---

## Limitations

**Snowflake only.** Type normalization is calibrated for Snowflake dtypes. Other adapters will produce incorrect or unmapped types.

**The model must be materialized before running the macro.** The macro introspects the live warehouse relation using `adapter.get_relation()`. If the model has never been run, or has been dropped, the macro raises a compiler error.

**NUMBER precision is not preserved.** Snowflake columns defined as `NUMBER(10,2)` introspect as plain `NUMBER`, so the macro outputs `data_type: number` without scale. If your model contains decimal columns that require specific precision or scale in the contract, update the `data_type` value manually before enabling enforcement.

**Schema must match the resolved warehouse schema.** If your project uses a custom `generate_schema_name` macro, `target.schema` may not be where the model lives. Pass the `schema` argument explicitly when in doubt. The macro prints a warning when `schema` is omitted.

**Column names are always lowercased.** The macro applies `| lower` to every column name unconditionally. Snowflake returns column names in uppercase (e.g. `ORDER_DATE`), which become `order_date` in the output. If your model uses quoted mixed-case identifiers, verify the cased output matches your model's actual column names before enabling enforcement.

**Column-level constraints are not generated.** Constraints such as `not_null`, `primary_key`, `foreign_key`, and `unique` are not included in the output. Only column names and data types are introspected.

---

## Development and testing

Integration tests live in `integration_tests/`. They require a live Snowflake connection.

Set the following environment variables before running:

```bash
export SNOWFLAKE_ACCOUNT=<your_account>
export SNOWFLAKE_USER=<your_user>
export SNOWFLAKE_PASSWORD=<your_password>
export SNOWFLAKE_ROLE=<your_role>
export SNOWFLAKE_DATABASE=<your_database>
export SNOWFLAKE_WAREHOUSE=<your_warehouse>
export SNOWFLAKE_SCHEMA=<your_schema>
```

Then run:

```bash
cd integration_tests
dbt deps
dbt seed
dbt run
dbt run-operation generate_contract_yml --args '{model_name: test_contract_model, schema: <your_schema>}'
```

The seed creates a table with columns covering the key Snowflake types: `INTEGER`, `VARCHAR`, `FLOAT`, `BOOLEAN`, and `DATE`. The macro output should show each mapped to its dbt contract equivalent.

---

## Roadmap

- Constraint inference (`not_null`) via `INFORMATION_SCHEMA`
- Precision and scale preservation option for numeric types
- Multi-adapter support (Postgres, BigQuery, Redshift)
