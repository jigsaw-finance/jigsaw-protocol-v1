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
        address chainlinkOracleAddress;
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
    address internal CHAINLINK_ORACLE_FACTORY = deployments.readAddress(".CHAINLINK_ORACLE_FACTORY");

    // Array to store deployed registries' addresses
    address[] internal registries;

    // Array to store registry configurations
    RegistryConfig[] internal registryConfigs;

    // Common liquidation config
    uint256 internal defaultLiquidationBuffer = 5e3;
    uint256 internal defaultLiquidationBonus = 8e3;

    uint256 internal CR85 = 85e3;
    uint256 internal CR80 = 80e3;
    uint256 internal CR75 = 75e3;
    uint256 internal CR65 = 65e3;

    // Common configs for oracle
    bytes internal COMMON_ORACLE_DATA = bytes("");
    uint256 internal COMMON_ORACLE_AGE = 24 hours;

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
                _oracle: ChainlinkOracleFactory(CHAINLINK_ORACLE_FACTORY).createChainlinkOracle({
                    _initialOwner: INITIAL_OWNER,
                    _underlying: registryConfigs[i].token,
                    _chainlinkOracle: registryConfigs[i].chainlinkOracleAddress,
                    _ageValidityPeriod: registryConfigs[i].age
                }),
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
        registryConfigs.push(
            RegistryConfig({
                symbol: "aSonUSDC",
                token: 0x578Ee1ca3a8E1b54554Da1Bf7C583506C4CD11c6,
                collateralizationRate: CR80,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chainlinkOracleAddress: 0x55bCa887199d5520B3Ce285D41e6dC10C08716C9,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "WETH",
                token: 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b,
                collateralizationRate: CR80,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chainlinkOracleAddress: 0x824364077993847f71293B24ccA8567c00c2de11,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wS",
                token: 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38,
                collateralizationRate: CR65,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chainlinkOracleAddress: 0xc76dFb89fF298145b417d221B2c747d84952e01d,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );
    }
}
