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

    // USDC
    address internal USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal USDC_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal USDC_OracleData = bytes("");
    uint256 internal USDC_CR = 50_000;

    // pufETH
    address internal pufETH = 0xD9A442856C234a39a81a089C06451EBAa4306a72;
    address internal pufETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal pufETH_OracleData = bytes("");
    uint256 internal pufETH_CR = 50_000;

    // USDT
    address internal USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal USDT_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal USDT_OracleData = bytes("");
    uint256 internal USDT_CR = 50_000;

    // DAI
    address internal DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal DAI_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal DAI_OracleData = bytes("");
    uint256 internal DAI_CR = 50_000;

    // USD0++
    address internal USD0 = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address internal USD0_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal USD0_OracleData = bytes("");
    uint256 internal USD0_CR = 50_000;

    // WBTC
    address internal WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal WBTC_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal WBTC_OracleData = bytes("");
    uint256 internal WBTC_CR = 40_000;

    // WETH
    address internal WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal WETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal WETH_OracleData = bytes("");
    uint256 internal WETH_CR = 60_000;

    // wstETH
    address internal wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal wstETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal wstETH_OracleData = bytes("");
    uint256 internal wstETH_CR = 50_000;

    // rswETH
    address internal rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    address internal rswETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal rswETH_OracleData = bytes("");
    uint256 internal rswETH_CR = 30_000;

    // pxETH
    address internal pxETH = 0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6;
    address internal pxETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal pxETH_OracleData = bytes("");
    uint256 internal pxETH_CR = 30_000;

    // weETH
    address internal weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal weETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal weETH_OracleData = bytes("");
    uint256 internal weETH_CR = 50_000;

    // ezETH
    address internal ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal ezETH_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal ezETH_OracleData = bytes("");
    uint256 internal ezETH_CR = 50_000;

    // LBTC
    address internal LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal LBTC_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal LBTC_OracleData = bytes("");
    uint256 internal LBTC_CR = 50_000;

    // eBTC
    address internal eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal eBTC_Oracle = 0xfD3e0cEe740271f070607aEddd0Bf4Cf99C92204;
    bytes internal eBTC_OracleData = bytes("");
    uint256 internal eBTC_CR = 50_000;

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

        // Add configs for USDT registry
        registryConfigs.push(
            RegistryConfig({
                token: USDT,
                oracle: USDT_Oracle,
                oracleData: USDT_OracleData,
                collateralizationRate: USDT_CR
            })
        );

        // Add configs for DAI registry
        registryConfigs.push(
            RegistryConfig({
                token: DAI,
                oracle: DAI_Oracle,
                oracleData: DAI_OracleData,
                collateralizationRate: DAI_CR
            })
        );

        // Add configs for USD0 registry
        registryConfigs.push(
            RegistryConfig({
                token: USD0,
                oracle: USD0_Oracle,
                oracleData: USD0_OracleData,
                collateralizationRate: USD0_CR
            })
        );

        // Add configs for WBTC registry
        registryConfigs.push(
            RegistryConfig({
                token: WBTC,
                oracle: WBTC_Oracle,
                oracleData: WBTC_OracleData,
                collateralizationRate: WBTC_CR
            })
        );

        // Add configs for WETH registry
        registryConfigs.push(
            RegistryConfig({
                token: WETH,
                oracle: WETH_Oracle,
                oracleData: WETH_OracleData,
                collateralizationRate: WETH_CR
            })
        );

        // Add configs for wstETH registry
        registryConfigs.push(
            RegistryConfig({
                token: wstETH,
                oracle: wstETH_Oracle,
                oracleData: wstETH_OracleData,
                collateralizationRate: wstETH_CR
            })
        );

        // Add configs for rswETH registry
        registryConfigs.push(
            RegistryConfig({
                token: rswETH,
                oracle: rswETH_Oracle,
                oracleData: rswETH_OracleData,
                collateralizationRate: rswETH_CR
            })
        );

        // Add configs for pxETH registry
        registryConfigs.push(
            RegistryConfig({
                token: pxETH,
                oracle: pxETH_Oracle,
                oracleData: pxETH_OracleData,
                collateralizationRate: pxETH_CR
            })
        );

        // Add configs for weETH registry
        registryConfigs.push(
            RegistryConfig({
                token: weETH,
                oracle: weETH_Oracle,
                oracleData: weETH_OracleData,
                collateralizationRate: weETH_CR
            })
        );

        // Add configs for ezETH registry
        registryConfigs.push(
            RegistryConfig({
                token: ezETH,
                oracle: ezETH_Oracle,
                oracleData: ezETH_OracleData,
                collateralizationRate: ezETH_CR
            })
        );

        // Add configs for LBTC registry
        registryConfigs.push(
            RegistryConfig({
                token: LBTC,
                oracle: LBTC_Oracle,
                oracleData: LBTC_OracleData,
                collateralizationRate: LBTC_CR
            })
        );

        // Add configs for eBTC registry
        registryConfigs.push(
            RegistryConfig({
                token: eBTC,
                oracle: eBTC_Oracle,
                oracleData: eBTC_OracleData,
                collateralizationRate: eBTC_CR
            })
        );

        registryConfigs.push(
            RegistryConfig({
                token: pufETH,
                oracle: pufETH_Oracle,
                oracleData: pufETH_OracleData,
                collateralizationRate: pufETH_CR
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
