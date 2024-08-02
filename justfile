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
	forge test -vvvvvv --match-test {{test}}

mp verbosity path: && _timer
	forge test -{{verbosity}} --match-path test/{{path}}

# Deploy ReceiptTokenFactory & ReceiptToken Contracts
deploy-mocks:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Mocks to $CHAIN..."
	eval "forge script DeployMocks --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

# Deploy Manager Contract
deploy-manager:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Manager to $CHAIN..."
	eval "forge script DeployManager --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

# Deploy jUSD Contract
deploy-jUSD:  && _timer
	#!/usr/bin/env bash
	echo "Deploying jUSD to $CHAIN..."
	eval "forge script DeployJUSD --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

# Deploy HoldingManager, LiquidationManager, StablesManager, StrategyManager & SwapManager Contracts
deploy-managers:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Managers to $CHAIN..."
	eval "forge script DeployManagers --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

# Deploy SharesRegistry Contracts for each configured token (a.k.a. collateral)
deploy-registries:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Registries to $CHAIN..."
	eval "forge script DeployRegistries --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

# Deploy ReceiptTokenFactory & ReceiptToken Contracts
deploy-receipt:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Receipt Token to $CHAIN..."
	eval "forge script DeployReceiptToken --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify  --broadcast"

verify-Manager: && _timer
	forge verify-contract 0x4779f89f32074c5c9dab38731299233cfce064a5 Manager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch  --constructor-args $(cast abi-encode "constructor(address,address,address,address,bytes)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0x616b359d40Cc645D76F084d048Bf2709f8B3A290 0x2c643C612E2f24613058dD2c2dba452cb547AEbF 0xEB8B6f572Fd08851D9ca4C46bfeE80bB2Fc5B5f0 0x)

verify-ManagerContainer: && _timer
	forge verify-contract 0xed8bb769f45cf08eee025631164c52463da4e60f ManagerContainer --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0x4779f89f32074c5c9dab38731299233cfce064a5)

verify-jUSD: && _timer
	forge verify-contract 0xe3Fb325eF36664D859e41482227f2b81da948DFC JigsawUSD --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f)

verify-HoldingManager: && _timer
	forge verify-contract 0xa3f5928239d805865f8f57a10e236a92a680b84c HoldingManager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f)


verify-LiquidationManager: && _timer
	forge verify-contract 0x5fD86640a05978Db06EC899B91f8E29F11eFC21b LiquidationManager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f)

verify-StablesManager: && _timer
	forge verify-contract 0x8940e77edeb182827dc007701dd8820e64eebbc3 StablesManager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f 0xe3fb325ef36664d859e41482227f2b81da948dfc)

verify-StrategyManager: && _timer
	forge verify-contract  0x497145fe795b32f7804b920887e8c9039602d665 StrategyManager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f)

verify-SwapManager: && _timer
	forge verify-contract  0xc68079680da83cd2e0ac085c3d23c913c319f7a7 SwapManager --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0x0227628f3F023bb0B980b67D528571c95c6DaC1c 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E 0xed8bb769f45cf08eee025631164c52463da4e60f)

verify-managers: && _timer
	just verify-HoldingManager
	just verify-LiquidationManager
	just verify-StablesManager
	just verify-StrategyManager
	just verify-SwapManager

verify-receiptTokenFactory:  && _timer 
		forge verify-contract  0xa54B6B1463a6D8d3F00BD7aaD8014a38d27640A8 ReceiptTokenFactory --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8)

verify-receiptToken:  && _timer 
		forge verify-contract  0x670d23af28d6d7f40dabe3535b68c295114f5d34 ReceiptToken --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch

verify-REGISTRY_USDC: && _timer 
		forge verify-contract  0x0291De1E90e15e615a0637797De182AaBD516Aad SharesRegistry --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address,bytes,uint256)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f 0x616b359d40Cc645D76F084d048Bf2709f8B3A290 0xafc699010d19f4820A1BC87C226B638A4EBbfb18 0x 50000)

verify-REGISTRY_WETH: && _timer 
		forge verify-contract  0x8daa43ca44b186b047d0a0f5978593f843fe866f SharesRegistry --etherscan-api-key JP2JMKVIZX189T45R1HUPVBJX3ZVVZBU52  --chain sepolia --watch --constructor-args $(cast abi-encode "constructor(address,address,address,address,bytes,uint256)" 0xf5a1Dc8f36ce7cf89a82BBd817F74EC56e7fDCd8 0xed8bb769f45cf08eee025631164c52463da4e60f 0x2c643C612E2f24613058dD2c2dba452cb547AEbF 0xaD9F1d83aA1cec62be05C825291Fa393B1178b59 0x 50000)