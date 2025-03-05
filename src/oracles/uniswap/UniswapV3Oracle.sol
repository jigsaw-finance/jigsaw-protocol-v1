// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { OracleLibrary } from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import { IUniswapV3Oracle } from "./interfaces/IUniswapV3Oracle.sol";

/**
 * @title UniswapV3Oracle
 *
 * @notice Fetches and processes Uniswap V3 TWAP (Time-Weighted Average Price) data for a given token.
 * @notice This contract is designed to provide jUSD price data quoted in USDC from Uniswap V3 pools.
 *
 * @dev Implements IUniswapV3Oracle interface and uses UniswapV3 pools as price feed source.
 * @dev This contract inherits functionalities from `Ownable2Step`.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract UniswapV3Oracle is IUniswapV3Oracle, Ownable2Step {
    // -- State variables --

    /**
     * @notice Returns the address of the token the oracle is for.
     * @dev Is used as a `baseToken` for UnsiwapV3 TWAP.
     */
    address public override underlying;

    /**
     * @notice Amount of tokens used to determine jUSD's price.
     * @dev Should be equal to 1 * 10^(jUSD decimals) to always get the price for one jUSD token.
     */
    uint128 public override baseAmount;

    /**
     * @notice Address of the ERC20 token used as the quote currency.
     */
    address public override quoteToken;

    /**
     * @notice Decimals of the ERC20 token used as the quote currency.
     */
    uint256 public override quoteTokenDecimals;

    /**
     * @notice The standard decimal precision (18) used for price normalization across the protocol.
     */
    uint256 private constant ALLOWED_DECIMALS = 18;

    /**
     * @notice List of UniswapV3 pool addresses used for price calculations.
     */
    address[] private pools;

    // -- Constructor --

    /**
     * @notice Initializes key parameters.
     * @param _initialOwner Address of the contract owner.
     * @param _jUSD Address of the jUSD token contract.
     * @param _quoteToken Address of the quote token (USDC) contract.
     * @param _uniswapV3Pool Address of the initial UniswapV3 pool used for pricing.
     */
    constructor(
        address _initialOwner,
        address _jUSD,
        address _quoteToken,
        address _uniswapV3Pool
    ) Ownable(_initialOwner) {
        if (_jUSD == address(0)) revert InvalidAddress();
        if (_quoteToken == address(0)) revert InvalidAddress();
        if (_uniswapV3Pool == address(0)) revert InvalidAddress();

        // Initialize oracle configuration parameters
        baseAmount = uint128(10 ** IERC20Metadata(_jUSD).decimals());
        underlying = _jUSD;
        quoteToken = _quoteToken;
        quoteTokenDecimals = IERC20Metadata(_quoteToken).decimals();
        pools.push(_uniswapV3Pool);
    }

    // -- Getters --

    /**
     * @notice Check the last exchange rate without any state changes.
     * @return success If no valid (recent) rate is available, returns false else true.
     * @return rate The rate of the requested asset.
     */
    function peek(
        bytes calldata
    ) external view returns (bool success, uint256 rate) {
        // Query three different TWAPs (Time-Weighted Average Prices) from different time periods and take the median of
        // these prices to reduce the impact of sudden price fluctuations or manipulation.
        uint256 median = getMedian(
            _quote({ _period: 1800, _offset: 3600 }), // Query the TWAP from the last 90-60 minutes (oldest time period)
            _quote({ _period: 1800, _offset: 1800 }), // Query the TWAP from the last 60-30 minutes (middle time period)
            _quote({ _period: 1800, _offset: 0 }) // Query the TWAP from the last 30-0 minutes (most recent time period)
        );

        // Normalize the price to ALLOWED_DECIMALS (e.g., 18 decimals)
        rate = quoteTokenDecimals == ALLOWED_DECIMALS
            ? median
            : quoteTokenDecimals < ALLOWED_DECIMALS
                ? median * 10 ** (ALLOWED_DECIMALS - quoteTokenDecimals)
                : median / 10 ** (quoteTokenDecimals - ALLOWED_DECIMALS);

        // If a valid price has been retrieved from the queries, return success as true
        success = true;
    }

    /**
     * @notice Returns a human readable name of the underlying of the oracle.
     */
    function name() external view override returns (string memory) {
        return IERC20Metadata(underlying).name();
    }

    /**
     * @notice Returns a human readable symbol of the underlying of the oracle.
     */
    function symbol() external view override returns (string memory) {
        return IERC20Metadata(underlying).symbol();
    }

    /**
     * @notice Returns the list of UniswapV3 pool addresses used for price calculations.
     * @return An array of UniswapV3 pool addresses stored in the contract.
     */
    function getPools() external view override returns (address[] memory) {
        return pools;
    }

    // -- Administration --

    /**
     * @notice Updates the UniswapV3 pools used for price calculations.
     * @dev Only callable by the contract owner.
     * @param _newPools The new list of UniswapV3 pool addresses.
     */
    function updatePools(
        address[] memory _newPools
    ) public onlyOwner {
        uint256 length = _newPools.length;

        // Ensure that the provided pool list is not empty
        if (length == 0) revert InvalidPoolsLength();

        // Compute hashes of the old and new pools to compare if they are identical
        bytes32 oldPoolsHash = keccak256(abi.encode(pools));
        bytes32 newPoolsHash = keccak256(abi.encode(_newPools));

        // Revert if the new pool list is the same as the existing one
        if (oldPoolsHash == newPoolsHash) revert InvalidPools();

        // Iterate through the new pool list to check for invalid addresses
        for (uint256 i = 0; i < length; i++) {
            if (_newPools[i] == address(0)) revert InvalidPools(); // Ensure no zero-address pools
        }

        // Emit an event to log the update of pools
        emit PoolsUpdated(oldPoolsHash, newPoolsHash);

        // Update the pools storage variable with the new pool list
        pools = _newPools;
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Utility functions --

    /**
     * @notice Fetches a time-weighted average price (TWAP) from Uniswap V3.
     * @param _period The length of the TWAP period in seconds.
     * @param _offset The offset (delay) for the TWAP calculation.
     */
    function _quote(uint32 _period, uint32 _offset) internal view returns (uint256) {
        uint256 length = pools.length;

        if (length == 0) revert NoDefinedPools();
        if (_offset > 0 && _period == 0) revert OffsettedSpotQuote();

        OracleLibrary.WeightedTickData[] memory _tickData = new OracleLibrary.WeightedTickData[](length);

        for (uint256 i; i < length; i++) {
            (_tickData[i].tick, _tickData[i].weight) = _period > 0
                ? consultOffsetted(pools[i], _period, _offset)
                : OracleLibrary.getBlockStartingTickAndLiquidity(pools[i]);
        }

        int24 _weightedTick =
            _tickData.length == 1 ? _tickData[0].tick : OracleLibrary.getWeightedArithmeticMeanTick(_tickData);

        return OracleLibrary.getQuoteAtTick(_weightedTick, baseAmount, underlying, quoteToken);
    }

    /**
     * @notice Calculates time-weighted means of tick and liquidity for a given Uniswap V3 pool.
     *
     * @param _pool Address of the pool that to observe.
     * @param _twapLength Length in seconds of the TWAP calculation length.
     * @param _offset Number of seconds ago to start the TWAP calculation.
     *
     * @return _arithmeticMeanTick The arithmetic mean tick from _secondsAgos[0] to _secondsAgos[1].
     * @return _harmonicMeanLiquidity The harmonic mean liquidity from _secondsAgos[0] to _secondsAgos[1].
     */
    function consultOffsetted(
        address _pool,
        uint32 _twapLength,
        uint32 _offset
    ) internal view returns (int24 _arithmeticMeanTick, uint128 _harmonicMeanLiquidity) {
        uint32[] memory _secondsAgos = new uint32[](2);
        _secondsAgos[0] = _twapLength + _offset;
        _secondsAgos[1] = _offset;

        (int56[] memory _tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(_pool).observe(_secondsAgos);

        int56 _tickCumulativesDelta = _tickCumulatives[1] - _tickCumulatives[0];
        uint160 _secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        _arithmeticMeanTick = int24(_tickCumulativesDelta / int56(int32(_twapLength)));

        // Always round to negative infinity
        if (_tickCumulativesDelta < 0 && (_tickCumulativesDelta % int56(int32((_twapLength))) != 0)) {
            _arithmeticMeanTick--;
        }

        // We are multiplying here instead of shifting to ensure that _harmonicMeanLiquidity doesn't overflow uint128
        uint192 _secondsAgoX160 = uint192(_twapLength) * type(uint160).max;
        _harmonicMeanLiquidity = uint128(_secondsAgoX160 / (uint192(_secondsPerLiquidityCumulativesDelta) << 32));
    }

    /**
     * @notice Computes a median value from three numbers.
     */
    function getMedian(uint256 _a, uint256 _b, uint256 _c) internal pure returns (uint256) {
        if ((_a >= _b && _a <= _c) || (_a >= _c && _a <= _b)) return _a;
        if ((_b >= _a && _b <= _c) || (_b >= _c && _b <= _a)) return _b;
        return _c;
    }
}
