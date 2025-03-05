// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IManagerContainer
 * @dev Interface for the ManagerContainer Contract.
 */
interface IManagerContainer {
    // -- Events --

    /**
     * @notice Emitted when when the Manager Contract's address is updated.
     * @param oldAddress The old Manager Contract's address.
     * @param newAddress The new Manager Contract's address.
     */
    event ManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Returns the address of the Manager Contract.
     */
    function manager() external view returns (address);

    // -- Administration --
    /**
     * @notice Updates the Manager Contract's address.
     *
     * @notice Requirements:
     * - `_newManager` should be non zero address.
     * - `_newManager` should be different from old Manager address.
     *
     * @notice Effects:
     * - Updates the `manager` state variable.
     *
     * @notice Emits:
     * - `ManagerUpdated` event indicating successful Manager update operation.
     *
     * @param _newManager The new address of the Manager contract.
     */
    function updateManager(
        address _newManager
    ) external;
}
