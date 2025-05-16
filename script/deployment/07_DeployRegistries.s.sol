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
import { ChronicleOracleFactory } from "../../src/oracles/chronicle/ChronicleOracleFactory.sol";

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
        address oracleAddress;
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

    // Common collateralization rates
    uint256 internal CR85 = 85e3;
    uint256 internal CR80 = 80e3;
    uint256 internal CR75 = 75e3;
    uint256 internal CR65 = 65e3;

    // Common configs for oracle
    bytes internal COMMON_ORACLE_DATA = bytes("");
    uint256 internal COMMON_ORACLE_AGE = 1 hours;

    // Default chronicle oracle address used for testing only
    // @todo DELETE ME
    address internal DEFAULT_ORACLE_ADDRESS = address(0);

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
                _oracle: registryConfigs[i].oracleAddress,
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
                symbol: "scUSD",
                token: 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE,
                collateralizationRate: CR80,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "USDC",
                token: 0x29219dd400f2Bf60E5a23d13Be72B486D4038894,
                collateralizationRate: CR85,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wstkscUSD",
                token: 0x9fb76f7ce5FCeAA2C42887ff441D46095E494206,
                collateralizationRate: CR80,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
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
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
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
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "stS",
                token: 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955,
                collateralizationRate: CR65,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "woS",
                token: 0x9F0dF7799f6FDAd409300080cfF680f5A23df4b1,
                collateralizationRate: CR65,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wstkscETH",
                token: 0xE8a41c62BB4d5863C6eadC96792cFE90A1f37C47,
                collateralizationRate: CR75,
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: DEFAULT_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );
    }

    function setDefaultOracleInTests(
        address _oracle
    ) external {
        DEFAULT_ORACLE_ADDRESS = _oracle;
    }
}
