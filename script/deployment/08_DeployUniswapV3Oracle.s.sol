// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console, stdJson as StdJson } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { UniswapV3Oracle } from "src/oracles/uniswap/UniswapV3Oracle.sol";
import { IUniswapV3Oracle } from "src/oracles/uniswap/interfaces/IUniswapV3Oracle.sol";

/**
 * @notice Deploys UniswapV3Oracle
 */
contract DeployUniswapV3Oracle is Script, Base {
    using StdJson for string;

    // Read config file
    string internal commonConfig = vm.readFile("./deployment-config/00_CommonConfig.json");
    string internal managerConfig = vm.readFile("./deployment-config/01_ManagerConfig.json");
    string internal uniswapConfig = vm.readFile("./deployment-config/05_UniswapV3OracleConfig.json");
    string internal deployments = vm.readFile("./deployments.json");

    // Get values from config
    address internal INITIAL_OWNER = commonConfig.readAddress(".INITIAL_OWNER");
    address internal JUSD = deployments.readAddress(".jUSD");
    address internal USDC = managerConfig.readAddress(".USDC");
    address internal JUSD_USDC_UNISWAP_POOL = uniswapConfig.readAddress(".JUSD_USDC_UNISWAP_POOL");

    function run() external broadcast returns (UniswapV3Oracle uniswapV3Oracle) {
        // Deploy UniswapV3Oracle Contract
        uniswapV3Oracle = new UniswapV3Oracle({
            _initialOwner: INITIAL_OWNER,
            _jUSD: JUSD,
            _quoteToken: USDC,
            _uniswapV3Pool: JUSD_USDC_UNISWAP_POOL
        });

        // Save the address of the uniswapV3Oracle to the deployments.json
        Strings.toHexString(uint160(address(uniswapV3Oracle)), 20).write("./deployments.json", ".JUSD_uniswapV3Oracle");

        // @note requestNewJUsdOracle and setJUsdOracle in Manager Contract using multisig
    }
}
