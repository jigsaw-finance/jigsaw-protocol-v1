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
    uint256 internal COMMON_ORACLE_AGE = 12 hours;

    address internal GENESIS_ORACLE = 0x4DFdF3F4dFaa93747a08D344c2f12cDcDa25c2e0;

    function run() external broadcast returns (address[] memory deployedRegistries) {
        // Validate interfaces
        _validateInterface(IManager(MANAGER));
        _validateInterface(IStablesManager(STABLES_MANAGER));

        _populateCollateralizationRates();
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
                symbol: "lvlUSD",
                token: 0x7C1156E515aA1A2E851674120074968C905aAF37,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: GENESIS_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "USDO",
                token: 0x8238884Ec9668Ef77B90C6dfF4D1a9F4F4823BFe,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: GENESIS_ORACLE,
                oracleData: COMMON_ORACLE_DATA,
                age: COMMON_ORACLE_AGE
            })
        );

        registryConfigs.push(
            RegistryConfig({
                symbol: "cUSDO",
                token: 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0,
                collateralizationRate: collateralizationRates[CollateralType.Stable],
                liquidationBuffer: defaultLiquidationBuffer,
                liquidatorBonus: defaultLiquidationBonus,
                oracleAddress: GENESIS_ORACLE,
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
