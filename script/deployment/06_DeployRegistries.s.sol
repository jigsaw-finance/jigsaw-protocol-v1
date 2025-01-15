// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IOracle } from "../../src/interfaces/oracle/IOracle.sol";

import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";

/**
 * @notice Deploys SharesRegistry Contracts for each configured token (a.k.a. collateral)
 */
contract DeployRegistries is Script, Base {
    using StdJson for string;

    struct RegistryConfig {
        address token;
        address oracle;
        bytes oracleData;
        uint256 collateralizationRate;
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
    address internal MANAGER_CONTAINER = deployments.readAddress(".MANAGER_CONTAINER");
    address internal STABLES_MANAGER = deployments.readAddress(".STABLES_MANAGER");

    // Store configuration for each SharesRegistry
    address internal USDC = 0x616b359d40Cc645D76F084d048Bf2709f8B3A290;
    address internal USDC_Oracle = 0xEB8B6f572Fd08851D9ca4C46bfeE80bB2Fc5B5f0;
    bytes internal USDC_OracleData = bytes("");
    uint256 internal USDC_CR = 50_000;

    constructor() {
        // Add configs for USDC registry
        registryConfigs.push(
            RegistryConfig({
                token: USDC,
                oracle: USDC_Oracle,
                oracleData: USDC_OracleData,
                collateralizationRate: USDC_CR
            })
        );
    }

    function run() external broadcast returns (address[] memory deployedRegistries) {
        // Validate interfaces
        _validateInterface(ManagerContainer(MANAGER_CONTAINER));
        _validateInterface(StablesManager(STABLES_MANAGER));

        for (uint256 i = 0; i < registryConfigs.length; i += 1) {
            // Validate interfaces
            _validateInterface(IERC20(registryConfigs[i].token));
            _validateInterface(IOracle(registryConfigs[i].oracle));

            // Deploy SharesRegistry contract
            SharesRegistry registry = new SharesRegistry({
                _initialOwner: INITIAL_OWNER,
                _managerContainer: MANAGER_CONTAINER,
                _token: registryConfigs[i].token,
                _oracle: registryConfigs[i].oracle,
                _oracleData: registryConfigs[i].oracleData,
                _collateralizationRate: registryConfigs[i].collateralizationRate
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
}
