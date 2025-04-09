// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { IManager } from "../src/interfaces/core/IManager.sol";
import { IStablesManager } from "../src/interfaces/core/IStablesManager.sol";
import { IOracle } from "../src/interfaces/oracle/IOracle.sol";

/**
 * @notice Validates that an address implements the expected interface by checking there is code at the provided address
 * and calling a few functions.
 */
abstract contract ValidateInterface {
    function _validateInterface(
        IManager manager
    ) internal view {
        require(address(manager).code.length > 0, "Manager must have code");
        manager.feeAddress();
        manager.oracleData();
        manager.allowedInvokers(address(this));
    }

    function _validateInterface(
        IStablesManager stablesManager
    ) internal view {
        require(address(stablesManager).code.length > 0, "StablesManager must have code");
        stablesManager.shareRegistryInfo(address(1));
        stablesManager.totalBorrowed(address(1));
        stablesManager.jUSD();
    }

    function _validateInterface(
        IERC20 token
    ) internal view {
        require(address(token).code.length > 0, "Token must have code");
        token.balanceOf(address(this));
        token.totalSupply();
        token.allowance(address(this), address(this));
    }

    function _validateInterface(
        IOracle oracle
    ) internal view {
        require(address(oracle).code.length > 0, "Oracle must have code");
        oracle.peek(abi.encode(""));
        oracle.symbol();
    }

    function _validateInterface(
        ISwapRouter router
    ) internal view {
        require(address(router).code.length > 0, "SwapRouter must have code");
    }

    function _validateInterface(
        IUniswapV3Factory factory
    ) internal view {
        require(address(factory).code.length > 0, "SwapRouter must have code");
        factory.getPool(address(1), address(2), uint24(10));
        factory.owner();
    }
}
