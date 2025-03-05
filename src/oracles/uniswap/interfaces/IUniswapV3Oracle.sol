// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IOracle } from "../../../interfaces/oracle/IOracle.sol";

interface IUniswapV3Oracle is IOracle {
    // -- Events --

    /**
     * @notice Emitted when the list of UniswapV3 pools is updated.
     * @param oldPoolsHash The hash of the old list of pools before the update.
     * @param newPoolsHash The hash of the new list of pools after the update.
     */
    event PoolsUpdated(bytes32 oldPoolsHash, bytes32 newPoolsHash);

    // -- Errors --

    /**
     * @notice Thrown when an invalid address is provided.
     * @dev This error is thrown when any of the provided contract addresses (such as jUSD, quoteToken, or UniswapV3
     * pool) are the zero address (address(0)), which is not a valid address for contract interactions.
     */
    error InvalidAddress();

    /**
     * @notice Thrown when the provided list of UniswapV3 pools has zero length.
     */
    error InvalidPoolsLength();

    /**
     * @notice Thrown when the provided list of UniswapV3 pools is identical to the existing list.
     */
    error InvalidPools();

    /**
     * @notice Error thrown when there are no defined UniswapV3 pools for price calculation.
     */
    error NoDefinedPools();

    /**
     * @notice Error thrown when attempting to query an offsetted spot quote with invalid parameters.
     * @dev This error is triggered when an attempt is made to query a spot price with an offset but no valid period is
     * specified.
     */
    error OffsettedSpotQuote();

    // -- State variables --

    /**
     * @notice Amount of tokens used to determine jUSD's price.
     * @return The base amount used for price calculations.
     */
    function baseAmount() external view returns (uint128);

    /**
     * @notice Address of the ERC20 token used as the quote currency.
     * @return The address of the quote token.
     */
    function quoteToken() external view returns (address);

    /**
     * @notice Decimals of the ERC20 token used as the quote currency.
     * @return The decimals of the quote token.
     */
    function quoteTokenDecimals() external view returns (uint256);

    /**
     * @notice Returns the list of UniswapV3 pool addresses used for price calculations.
     * @return An array of UniswapV3 pool addresses stored in the contract.
     */
    function getPools() external view returns (address[] memory);

    // -- Administration --

    /**
     * @notice Updates the UniswapV3 pools used for price calculations.
     * @dev Only callable by the contract owner.
     * @param _newPools The new list of UniswapV3 pool addresses.
     */
    function updatePools(
        address[] memory _newPools
    ) external;
}
