#!/usr/bin/env just --justfile

# load .env file
set dotenv-load

# pass recipe args as positional arguments to commands
set positional-arguments

set export

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
	forge test -v

test-gas: && _timer
    forge test --gas-report

coverage-all: && _timer
	forge coverage --report lcov --allow-failure --no-match-coverage "(script|test)"
	genhtml -o coverage --branch-coverage lcov.info --ignore-errors category --rc derive_function_end_line=0

docs: && _timer
	forge doc --build

mt test: && _timer
	forge test -vvvvvv --match-test {{test}}

mp verbosity path: && _timer
	forge test -{{verbosity}} --match-path test/{{path}}

verify-blockScout: && _timer
	#!/usr/bin/env bash
	echo "Verifying on Blockscout..."
	forge verify-contract --rpc-url https://rpc.ankr.com/swell 0x4DFdF3F4dFaa93747a08D344c2f12cDcDa25c2e0 GenesisOracle --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/


# Deploy jUSD EverRevertingOracle
deploy-revertingOracle:  && _timer
	#!/usr/bin/env bash
	echo "Deploying jUSD Genesis Oracle to $CHAIN..."
	forge script DeployEverRevertingOracle --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy jUSD Genesis oracle
deploy-genesisOracle:  && _timer
	#!/usr/bin/env bash
	echo "Deploying jUSD Genesis Oracle to $CHAIN..."
	forge script DeployGenesisOracle --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy Manager Contract
deploy-manager:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Manager to $CHAIN..."
	forge script DeployManager --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy jUSD Contract
deploy-jUSD:  && _timer
	#!/usr/bin/env bash
	echo "Deploying jUSD to $CHAIN..."
	forge script DeployJUSD --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy HoldingManager, LiquidationManager, StablesManager, StrategyManager & SwapManager Contracts
deploy-managers:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Managers to $CHAIN..."
	forge script DeployManagers --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy ReceiptTokenFactory & ReceiptToken Contracts
deploy-receipt:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Receipt Token to $CHAIN..."
	forge script DeployReceiptToken --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/
	
# Deploy PythOracleFactory & PythOracleImpl
deploy-chronicleOracle:  && _timer
	#!/usr/bin/env bash
	echo "Deploying ChronicleOracleFactory to $CHAIN..."
	forge script DeployChronicleOracleFactory --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy SharesRegistry Contracts for each configured token (a.k.a. collateral)
deploy-registries:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Registries to $CHAIN..."
	forge script DeployRegistries --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/

# Deploy UniswapV3Oracle
deploy-uniswapV3Oracle: && _timer
	#!/usr/bin/env bash
	echo "Deploying UniswapV3Oracle to $CHAIN..."
	forge script DeployUniswapV3Oracle --rpc-url ${CHAIN} --slow -vvvv --etherscan-api-key ${ETHERSCAN_API_KEY} --broadcast --verify --verifier blockscout --verifier-url https://explorer.swellnetwork.io/api/
