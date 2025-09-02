// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Reverting Oracle to block borrowing for initial deployment
 */
contract EverRevertingOracle {
    /**
     * @notice Always reverts.
     */
    function peek(
        bytes calldata
    ) external pure returns (bool success, uint256 rate) {
        success = false;
        rate = 0;
    }
}
