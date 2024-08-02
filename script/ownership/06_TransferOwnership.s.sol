// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console2 as console } from "forge-std/Script.sol";

import { Base } from "../Base.s.sol";

interface ITransferOwnership {
    function transferOwnership(address newOwner) external;
}

/**
 * @notice Transfers ownership for the provided in the constructor contracts.
 */
contract TransferOwnership is Script, Base {
    function run(address[] calldata _transferOwnershipFrom, address _newOwner) external broadcast {
        for (uint256 i = 0; i < _transferOwnershipFrom.length; i += 1) {
            ITransferOwnership(_transferOwnershipFrom[i]).transferOwnership({ newOwner: _newOwner });
        }
    }
}
