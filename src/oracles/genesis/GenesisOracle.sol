// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GenesisOracle
 *
 * @notice A mock oracle contract for the jUSD token.
 *
 * @dev This contract provides a fixed exchange rate of 1:1 for jUSD and includes basic metadata functions.
 * @dev It serves as a temporary solution during the initial phase of the protocol and must be replaced by a real
 * on-chain oracle as soon as one becomes available.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract GenesisOracle {
    /**
     * @notice Always returns a fixed exchange rate of 1e18 (1:1).
     * @return success Boolean indicating whether a valid rate is available.
     * @return rate The exchange rate of the underlying asset.
     */
    function peek(
        bytes calldata
    ) external pure returns (bool success, uint256 rate) {
        rate = 1e18; // Fixed rate of 1 jUSD = 1 USD
        success = true;
    }

    /**
     * @notice Retrieves the name of the underlying token.
     * @return The human-readable name of the jUSD token.
     */
    function name() external pure returns (string memory) {
        return "Jigsaw USD";
    }

    /**
     * @notice Retrieves the symbol of the underlying token.
     * @return The human-readable symbol of the jUSD token.
     */
    function symbol() external pure returns (string memory) {
        return "jUSD";
    }
}
