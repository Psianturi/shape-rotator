#!/bin/bash
# Compile Solidity contracts and output ABI + BIN to contracts/config/
#
# Prerequisites:
#   npm install -g solc
#   OR: pip install py-solc-x && python -c "from solcx import install_solc; install_solc('0.8.24')"
#
# Run from repo root:
#   chmod +x contracts/scripts/compile_contracts.sh
#   ./contracts/scripts/compile_contracts.sh

set -e

CONTRACTS_DIR="contracts"
OUT_DIR="contracts/config"
SOLC_VERSION="0.8.24"

mkdir -p "$OUT_DIR"

echo "=== Compiling PerisAI Contracts (solc $SOLC_VERSION) ==="

# Try solc directly first, fallback to solcx via Python
if command -v solc &>/dev/null; then
  SOLC_CMD="solc"
  echo "Using system solc: $(solc --version | head -1)"
else
  echo "solc not found, using py-solc-x..."
  python3 - <<'PYEOF'
from solcx import compile_files, install_solc, set_solc_version
import json, pathlib

install_solc("0.8.24", show_progress=False)
set_solc_version("0.8.24")

contracts = [
    "contracts/PerisAIWallet.sol",
    "contracts/IdentityRegistry.sol",
    "contracts/AgentRegistry.sol",
]

result = compile_files(contracts, output_values=["abi", "bin"])

out = pathlib.Path("contracts/config")
out.mkdir(exist_ok=True)

for key, data in result.items():
    # key format: "contracts/Foo.sol:Foo"
    name = key.split(":")[-1]
    (out / f"{name}.abi").write_text(json.dumps(data["abi"], indent=2))
    (out / f"{name}.bin").write_text(data["bin"])
    print(f"  {name}.abi + {name}.bin written")

print("Compilation complete.")
PYEOF
  exit 0
fi

# solc path
for contract in PerisAIWallet IdentityRegistry AgentRegistry; do
  echo "  Compiling $contract.sol..."
  solc --bin --abi \
    --overwrite \
    --output-dir "$OUT_DIR" \
    "$CONTRACTS_DIR/$contract.sol"
  # Rename solc output to match expected names
  mv -f "$OUT_DIR/${contract}.bin" "$OUT_DIR/${contract}.bin" 2>/dev/null || true
  mv -f "$OUT_DIR/${contract}.abi" "$OUT_DIR/${contract}.abi" 2>/dev/null || true
done

echo ""
echo "=== Compilation Complete ==="
echo "Output: $OUT_DIR/"
ls -la "$OUT_DIR/"
