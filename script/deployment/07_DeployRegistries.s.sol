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
     * @dev enum of collateral types
     */
    enum CollateralType {
        Stable,
        Major,
        LRT
    }

    /**
     * @dev struct of registry configurations
     */
    struct RegistryConfig {
        string symbol;
        address token;
        uint256 collateralizationRate;
        uint256 liquidationBuffer;
        uint256 liquidatorBonus;
        address chronicleOracleAddress;
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
    address internal CHRONICLE_ORACLE_FACTORY = deployments.readAddress(".CHRONICLE_ORACLE_FACTORY");

    // Array to store deployed registries' addresses
    address[] internal registries;

    // Array to store registry configurations
    RegistryConfig[] internal registryConfigs;

    // Mapping of collateral type to collateralization rate
    mapping(CollateralType collateralType => uint256 collateralizationRate) internal collateralizationRates;

    // Common liquidation config
    uint256 internal defaultLiquidationBuffer = 5e3;
    uint256 internal defaultLiquidationBonus = 8e3;

    // Common collateralization rates
    uint256 internal STABLECOIN_CR = 85e3;
    uint256 internal MAJOR_CR = 75e3;
    uint256 internal LRT_CR = 70e3;

    // Common configs for oracle
    bytes internal COMMON_ORACLE_DATA = bytes("");
    uint256 internal COMMON_ORACLE_AGE = 1 hours;

    // Default chronicle oracle address used for testing only
    // @todo DELETE ME
    address internal DEFAULT_CHRONICLE_ORACLE_ADDRESS = 0x46ef0071b1E2fF6B42d36e5A177EA43Ae5917f4E;

    function run() external broadcast returns (address[] memory deployedRegistries) {
        // Validate interfaces
        _validateInterface(IManager(MANAGER));
        _validateInterface(IStablesManager(STABLES_MANAGER));

        _populateCollateralizationRates();
        _populateRegistriesArray();

        for (uint256 i = 0; i < registryConfigs.length; i += 1) {
            // Validate interfaces
            _validateInterface(IERC20(registryConfigs[i].token));

            address oracle = ChronicleOracleFactory(CHRONICLE_ORACLE_FACTORY).createChronicleOracle({
                _initialOwner: INITIAL_OWNER,
                _underlying: registryConfigs[i].token,
                _chronicle: registryConfigs[i].chronicleOracleAddress,
                _ageValidityPeriod: registryConfigs[i].age
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
                symbol: "USDC",
                token: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "USDT",
                token: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "rUSD",
                token: 0x09D4214C03D01F49544C0448DBE3A27f768F2b34,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "USD0++",
                token: 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wBTC",
                token: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
                collateralizationRate: collateralizationRates[CollateralType.Major],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wETH",
                token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                collateralizationRate: collateralizationRates[CollateralType.Major],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "wstETH",
                token: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
                collateralizationRate: collateralizationRates[CollateralType.Major],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "weETH",
                token: 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee,
                collateralizationRate: collateralizationRates[CollateralType.LRT],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "pxETH",
                token: 0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6,
                collateralizationRate: collateralizationRates[CollateralType.LRT],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                chronicleOracleAddress: DEFAULT_CHRONICLE_ORACLE_ADDRESS,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );
    }

    function _populateCollateralizationRates() internal {
        collateralizationRates[CollateralType.Stable] = STABLECOIN_CR;
        collateralizationRates[CollateralType.Major] = MAJOR_CR;
        collateralizationRates[CollateralType.LRT] = LRT_CR;
    }
}
