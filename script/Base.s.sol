pragma solidity >=0.8.19 <=0.9.0;

import { Script } from "forge-std/Script.sol";

import { ValidateInterface } from "./ValidateInterface.s.sol";

abstract contract Base is Script, ValidateInterface {
    modifier broadcast() {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        _;
        vm.stopBroadcast();
    }

    modifier broadcastFrom(
        uint256 from
    ) {
        vm.startBroadcast(from);
        _;
        vm.stopBroadcast();
    }
}
