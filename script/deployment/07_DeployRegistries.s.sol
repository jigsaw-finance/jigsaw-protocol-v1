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
import { ChainlinkOracleFactory } from "../../src/oracles/chainlink/ChainlinkOracleFactory.sol";

import { SharesRegistry } from "../../src/SharesRegistry.sol";

/**
 * @notice Deploys SharesRegistry Contracts for each configured token (a.k.a. collateral)
 */
contract DeployRegistries is Script, Base {
    using StdJson for string;

    /**
     * @dev struct of registry configurations
     */
    struct RegistryConfig {
        string symbol;
        address token;
        uint256 collateralizationRate;
        uint256 liquidationBuffer;
        uint256 liquidatorBonus;
        address oracle;
        bytes oracleData;
        uint256 age;
    }

    // Read config files
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from configs
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal MANAGER = deployments.readAddress(".MANAGER");
    address internal STABLES_MANAGER = deployments.readAddress(".STABLES_MANAGER");

    // Array to store deployed registries' addresses
    address[] internal registries;

    // Array to store registry configurations
    RegistryConfig[] internal registryConfigs;

    // Common liquidation config
    uint256 internal defaultLiquidationBuffer = 5e3;
    uint256 internal defaultLiquidationBonus = 8e3;

    uint256 internal CR20 = 20e3;

    // Common configs for oracle
    bytes internal COMMON_ORACLE_DATA = bytes("");
    uint256 internal COMMON_ORACLE_AGE = 24 hours;

    address internal EVER_REVERTING_ORACLE = 0x5B3af3630F37EfC7b8DF88EED6F3651c056dBA11;

    function run() external broadcast returns (address[] memory deployedRegistries) {
        // Validate interfaces
        _validateInterface(IManager(MANAGER));
        _validateInterface(IStablesManager(STABLES_MANAGER));

        _populateRegistriesArray();

        for (uint256 i = 0; i < registryConfigs.length; i += 1) {
            // Validate interfaces
            _validateInterface(IERC20(registryConfigs[i].token));

            // Deploy SharesRegistry contract
            SharesRegistry registry = new SharesRegistry({
                _initialOwner: INITIAL_OWNER,
                _manager: MANAGER,
                _token: registryConfigs[i].token,
                _oracle: registryConfigs[i].oracle,
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
                symbol: "wETH",
                token: 0x4200000000000000000000000000000000000006,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wstETH",
                token: 0x7c98E0779EB5924b3ba8cE3B17648539ed5b0Ecc,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "rswETH",
                token: 0x18d33689AE5d02649a859A1CF16c9f0563975258,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "weETH",
                token: 0xA6cB988942610f6731e664379D15fFcfBf282b44,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "sUSDE",
                token: 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "ezETH",
                token: 0x2416092f143378750bb29b79eD961ab195CcEea5,
                collateralizationRate: CR20,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracle: EVER_REVERTING_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );
    }
}
