#!/usr/bin/env just --justfile
# load .env file

set dotenv-load := true

# pass recipe args as positional arguments to commands

set positional-arguments := true
set export := true

_default:
    just --list

# utility functions

start_time := `date +%s`

_timer:
    @echo "Task executed in $(($(date +%s) - {{ start_time }})) seconds"

clean-all: && _timer
    forge clean
    rm -rf coverage_report
    rm -rf lcov.info
    rm -rf typechain-types
    rm -rf artifacts
    rm -rf out

remove-modules: && _timer
    rm -rf .gitmodules
    rm -rf .git/modules/*
    rm -rf lib/forge-std
    touch .gitmodules
    git add .
    git commit -m "modules"

# Install the Vyper venv
install-vyper: && _timer
    pip install virtualenv
    virtualenv -p python3 venv
    source venv/bin/activate
    pip install vyper==0.2.16
    vyper --version

# Install the Modules
install: && _timer
    forge install foundry-rs/forge-std

# Update Dependencies
update: && _timer
    forge update

remap: && _timer
    forge remappings > remappings.txt

# Builds
build: && _timer
    forge clean
    forge build --names --sizes

format: && _timer
    forge fmt

test-all: && _timer
    forge test -vvvvv

test-gas: && _timer
    forge test --gas-report

coverage-all: && _timer
    forge coverage --report lcov
    genhtml -o coverage --branch-coverage lcov.info --ignore-errors category

docs: && _timer
    forge doc --build

mt test: && _timer
    forge test -vvvvvv --match-test {{ test }}

mp verbosity path: && _timer
    forge test -{{ verbosity }} --match-path test/{{ path }}

# Deploy Manager Contract
deploy-manager: && _timer
    #!/usr/bin/env bash
    echo "Deploying Manager to $CHAIN..."
    eval "forge script DeployManager --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"

# Deploy ManagerContainer Contract
deploy-managerContainer: && _timer
    #!/usr/bin/env bash
    echo "Deploying ManagerContainer to $CHAIN..."
    eval "forge script DeployManagerContainer --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"

# Deploy jUSD Contract
deploy-jUSD: && _timer
    #!/usr/bin/env bash
    echo "Deploying jUSD to $CHAIN..."
    eval "forge script DeployJUSD --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"

# Deploy HoldingManager, LiquidationManager, StablesManager, StrategyManager & SwapManager Contracts
deploy-managers: && _timer
    #!/usr/bin/env bash
    echo "Deploying Managers to $CHAIN..."
    eval "forge script DeployManagers --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"

# Deploy ReceiptTokenFactory & ReceiptToken Contracts
deploy-receipt: && _timer
    #!/usr/bin/env bash
    echo "Deploying Receipt Token to $CHAIN..."
    eval "forge script DeployReceiptToken --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"

# Deploy SharesRegistry Contracts for each configured token (a.k.a. collateral)
deploy-registries: && _timer
    #!/usr/bin/env bash
    echo "Deploying Registries to $CHAIN..."
    eval "forge script DeployRegistries --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key ${TENDERLY_ETHERSCAN_API_KEY} --verify --verifier-url ${TENDERLY_VERIFIER_URL} --broadcast"
