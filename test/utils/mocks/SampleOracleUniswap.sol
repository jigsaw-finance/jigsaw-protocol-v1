// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TickMath } from "../TickMath.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

import { IOracle } from "../../../src/interfaces/oracle/IOracle.sol";

contract SampleOracleUniswap is IOracle {
    IUniswapV3Pool public pool;

    //address of the token this oracle is for
    address public underlying;
    bool public updated = true;

    constructor(address _pool, address _underlying) {
        pool = IUniswapV3Pool(_pool);
        underlying = _underlying;
    }

    event Log(string name, uint256 value);
    event LogInt(string name, int24 value);

    function peek(
        bytes calldata
    ) external view override returns (bool success, uint256 ratio) {
        // Get sqrt price from 0 slot of unsiwap pool
        // (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // (uint160 sqrtPriceX96,) = getSqrtTwapX96(3600);

        // this needs to be deleted and used one with 3600
        // i used 0 here only because jUsd pool is crested from scratch each time
        (uint160 sqrtPriceX96,) = getSqrtTwapX96(0);
        // Get real price
        uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        // Get token 0 decimals to get precise ratio
        uint256 numerator2 = 10 ** IERC20Metadata(pool.token0()).decimals();

        // Compute the precise ratio using mulDiv
        ratio = Math.mulDiv(numerator1, numerator2, 1 << 192);

        // Format ratio to match 18 decimals requirement
        // @notice Uniswap returns price with decimals 6, that's why we use decimals 12 (18-6)
        ratio = ratio * (10 ** 12);

        ratio = pool.token0() == underlying ? ratio : 1e18 * 1e18 / ratio;
        return (updated, ratio);
    }

    function getSqrtTwapX96(
        uint32 twapInterval
    ) public view returns (uint160 sqrtPriceX96, uint256 priceX96) {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96,,,,,,) = pool.slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval; // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int32(twapInterval)))
            );

            priceX96 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
        }
    }

    function symbol() external view override returns (string memory) 
    // solhint-disable-next-line no-empty-blocks
    { }

    function name() external view override returns (string memory) 
    // solhint-disable-next-line no-empty-blocks
    { }
}
