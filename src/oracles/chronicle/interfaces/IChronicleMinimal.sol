// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title IChronicle
 *
 * @notice Minimal interface for Chronicle Protocol's oracle products
 */
interface IChronicleMinimal {
    /**
     * @notice Returns the oracle's current value and its age.
     * @dev Reverts if no value set.
     * @return value The oracle's current value.
     * @return age The value's age.
     */
    function readWithAge() external view returns (uint256 value, uint256 age);
}
