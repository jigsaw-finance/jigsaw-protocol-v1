// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console } from "forge-std/Script.sol";

import { SampleOracle } from "../../test/utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../../test/utils/mocks/SampleTokenERC20.sol";
import { StrategyWithoutRewardsMock } from "../../test/utils/mocks/StrategyWithoutRewardsMock.sol";
import { wETHMock } from "../../test/utils/mocks/wETHMock.sol";

contract DeployMocks is Script {
    function run()
        external
        returns (
            SampleTokenERC20 USDC,
            wETHMock WETH,
            SampleOracle USDC_Oracle,
            SampleOracle WETH_Oracle,
            SampleOracle JUSD_Oracle
        )
    {
        // Deploy collateral mocks
        USDC = new SampleTokenERC20("USDC", "USDC", 0);
        WETH = new wETHMock();

        // Deploy collateral oracles mocks
        USDC_Oracle = new SampleOracle();
        WETH_Oracle = new SampleOracle();

        // Deploy jUSD oracle mock
        JUSD_Oracle = new SampleOracle();
    }
}
