// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IManager } from "../../src/interfaces/core/IManager.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "../../src/interfaces/core/IStablesManager.sol";
import { IOracle } from "../../src/interfaces/oracle/IOracle.sol";
import { PythOracleFactory } from "../../src/oracles/pyth/PythOracleFactory.sol";

import { SharesRegistry } from "../../src/SharesRegistry.sol";

/**
 * @notice Deploys SharesRegistry Contracts for each configured token (a.k.a. collateral)
 */
contract DeployRegistries is Script, Base {
    using StdJson for string;

    struct RegistryConfig {
        address token;
        uint256 collateralizationRate;
        uint256 liquidationBuffer;
        uint256 liquidatorBonus;
        bytes oracleData;
        bytes32 pythId;
        uint256 age;
    }

    // Array to store registry configurations
    RegistryConfig[] internal registryConfigs;

    // Array to store deployed registries' addresses
    address[] internal registries;

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER = deployments.readAddress(".MANAGER");
    address internal STABLES_MANAGER = deployments.readAddress(".STABLES_MANAGER");
    address internal PYTH_ORACLE_FACTORY = deployments.readAddress(".PYTH_ORACLE_FACTORY");

    // Store configuration for each SharesRegistry
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 internal USDC_CR = 50_000;
    uint256 internal USDC_LiquidationBuffer = 5e3;
    uint256 internal USDC_LiquidationBonus = 8e3;
    bytes32 internal USDC_PYTH_ID = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;

    // Common configs for oracle
    bytes internal COMMON_ORACLE_DATA = bytes("");
    uint256 internal COMMON_ORACLE_AGE = 1 hours;

    function run() external broadcast returns (address[] memory deployedRegistries) {
        // Validate interfaces
        _validateInterface(IManager(MANAGER));
        _validateInterface(IStablesManager(STABLES_MANAGER));

        _populateRegistriesArray();

        for (uint256 i = 0; i < registryConfigs.length; i += 1) {
            // Validate interfaces
            _validateInterface(IERC20(registryConfigs[i].token));

            address oracle = PythOracleFactory(PYTH_ORACLE_FACTORY).createPythOracle({
                _initialOwner: INITIAL_OWNER,
                _underlying: registryConfigs[i].token,
                _priceId: registryConfigs[i].pythId,
                _age: registryConfigs[i].age
            });

            // Deploy SharesRegistry contract
            SharesRegistry registry = new SharesRegistry({
                _initialOwner: INITIAL_OWNER,
                _manager: MANAGER,
                _token: registryConfigs[i].token,
                _oracle: oracle,
                _oracleData: registryConfigs[i].oracleData,
                _config: ISharesRegistry.RegistryConfig({
                    collateralizationRate: registryConfigs[i].collateralizationRate,
                    liquidationBuffer: registryConfigs[i].liquidationBuffer,
                    liquidatorBonus: registryConfigs[i].liquidatorBonus
                })
            });

            // @note save the deployed SharesRegistry contract to the StablesManager contract
            // @note whitelistToken on Manager Contract for all the tokens

            // Save the registry deployment address locally
            registries.push(address(registry));

            string memory jsonKey = string.concat(".REGISTRY_", IERC20Metadata(registryConfigs[i].token).symbol());

            // Save addresses of all the deployed contracts to the deployments.json
            Strings.toHexString(uint160(address(registry)), 20).write("./deployments.json", jsonKey);
        }

        return registries;
    }

    function _populateRegistriesArray() internal {
        // Add configs for desired collaterals' registries
        registryConfigs.push(
            RegistryConfig({
                token: USDC,
                collateralizationRate: USDC_CR,
                liquidationBuffer: USDC_LiquidationBuffer,
                liquidatorBonus: USDC_LiquidationBonus,
                pythId: USDC_PYTH_ID,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );
    }
}
