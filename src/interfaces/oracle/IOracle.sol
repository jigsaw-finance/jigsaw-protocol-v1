// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    // -- State variables --

    /**
     * @notice Returns the address of the token the oracle is for.
     */
    function underlying() external view returns (address);

    // -- Functions --

    /**
     * @notice Returns a human readable name of the underlying of the oracle.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns a human readable symbol of the underlying of the oracle.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Check the last exchange rate without any state changes.
     *
     * @param data Implementation specific data that contains information and arguments to & about the oracle.
     *
     * @return success If no valid (recent) rate is available, returns false else true.
     * @return rate The rate of the requested asset / pair / pool.
     */
    function peek(
        bytes calldata data
    ) external view returns (bool success, uint256 rate);
}
