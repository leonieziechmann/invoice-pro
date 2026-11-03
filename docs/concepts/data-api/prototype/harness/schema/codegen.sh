#!/bin/bash
# P5 codegen: pydantic v2 (datamodel-codegen), TypeScript
# (json-schema-to-typescript) and Rust (typify) from both committed schemas.
# Tools: $CODEGEN_TOOLS/py/.venv (datamodel-codegen), $CODEGEN_TOOLS/ts (npm:
# json-schema-to-typescript) and $CODEGEN_TOOLS/rs/tools (cargo-typify); the
# exploration installed them under <session>/exp/prior-art/codegen.
CG="${CODEGEN_TOOLS:?set CODEGEN_TOOLS to the directory of the code generators}"
D=$(cd "$(dirname "$0")" && pwd); R=$(cd $D/../../repo && pwd); O=$D/out; mkdir -p $O
for k in invoice result; do
  $CG/py/.venv/bin/datamodel-codegen --input $R/src/contract/$k.schema.json --input-file-type jsonschema --output-model-type pydantic_v2.BaseModel --output $O/${k}_model.py 2>$O/$k-py.err && echo "pydantic $k: $(wc -l < $O/${k}_model.py) lines" || { echo "pydantic $k FAILED"; tail -3 $O/$k-py.err; }
  (cd $CG/ts && npx --no-install json2ts -i $R/src/contract/$k.schema.json -o $O/$k.d.ts 2>$O/$k-ts.err) && echo "typescript $k: $(wc -l < $O/$k.d.ts) lines" || { echo "typescript $k FAILED"; tail -3 $O/$k-ts.err; }
  $CG/rs/tools/bin/cargo-typify typify $R/src/contract/$k.schema.json -o $O/$k.rs 2>$O/$k-rs.err && echo "rust $k: $(wc -l < $O/$k.rs) lines" || { echo "rust $k FAILED"; tail -3 $O/$k-rs.err; }
done
cp $O/invoice_model.py $O/model.py
