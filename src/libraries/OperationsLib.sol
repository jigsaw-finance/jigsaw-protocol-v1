// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Operations Library
 * @notice A library containing common mathematical operations used throughout the protocol
 */
library OperationsLib {
    /**
     * @notice The denominator used for fee calculations (10,000 = 100%)
     * @dev Fees are expressed in basis points, where 1 basis point = 0.01%
     *      For example, 100 = 1%, 500 = 5%, 1000 = 10%
     */
    uint256 internal constant FEE_FACTOR = 10_000;

    /**
     * @notice Calculates the absolute fee amount based on the input amount and fee rate
     * @dev The calculation rounds up to ensure the protocol always collects the full fee
     * @param amount The base amount on which the fee is calculated
     * @param fee The fee rate in basis points (e.g., 100 = 1%)
     * @return The absolute fee amount, rounded up if there's any remainder
     */
    function getFeeAbsolute(uint256 amount, uint256 fee) internal pure returns (uint256) {
        // Calculate fee amount with rounding up to avoid precision loss
        return (amount * fee) / FEE_FACTOR + (amount * fee % FEE_FACTOR == 0 ? 0 : 1);
    }
}
